//! `dojo_model` attribute macro.
//!
//!

use cairo_lang_macro::{
    attribute_macro, AuxData, Diagnostic, Diagnostics, ProcMacroResult, TokenStream,
};
use cairo_lang_parser::utils::SimpleParserDatabase;
use cairo_lang_syntax::node::db::SyntaxGroup;
use cairo_lang_syntax::node::helpers::QueryAttrs;
use cairo_lang_syntax::node::kind::SyntaxKind::ItemStruct;
use cairo_lang_syntax::node::{ast, TypedSyntaxNode};
use convert_case::{Case, Casing};
use starknet::core::utils::get_selector_from_name;

use std::collections::HashMap;

use dojo_types::naming;

use crate::attributes::struct_parser::remove_derives;
use crate::aux_data::{Member, ModelAuxData};
use crate::derives::{extract_derive_attr_names, DOJO_INTROSPECT_DERIVE, DOJO_PACKED_DERIVE};
use crate::diagnostic_ext::DiagnosticsExt;
use crate::syntax::utils::parse_arguments_kv;
use crate::token_stream_ext::{TokenStreamExt, TokenStreamsExt};

use super::patches::MODEL_PATCH;
use super::struct_parser::{
    deserialize_keys_and_values, parse_members, serialize_keys_and_values, serialize_member_ty,
    validate_namings_diagnostics,
};

const DOJO_MODEL_ATTR: &str = "dojo_model";
const MODEL_NAMESPACE: &str = "namespace";
const DEFAULT_VERSION: u64 = 0;

/// `#[dojo_model(...)]` attribute macro.
///
/// This macro removes the original node passed as a [`TokenStream`] and replaces it with a new
/// generated node. The generated node must then contain the original struct to ensure other
/// plugins work correctly.
///
/// A tricky thing too keep in mind is that, if the original struct has derives applied,
/// those derives must be removed if they don't belong to this plugin. Otherwise, Cairo will throw a compilation error as derived code will be duplicated.
///
/// # Arguments of the macro
///
/// * `namespace` - the namespace of the model.
/// * `version` - the version of the model.
#[attribute_macro]
pub fn dojo_model(args: TokenStream, token_stream: TokenStream) -> ProcMacroResult {
    // Arguments of the macro are already parsed. Hence, we can't use the query_attr since the
    // attribute that triggered the macro execution is not available in the syntax node.
    let parsed_args = parse_arguments_kv(&args.to_string());

    let model_namespace = if let Some(model_namespace) = parsed_args.get(MODEL_NAMESPACE) {
        model_namespace.to_string()
    } else {
        return ProcMacroResult::new(TokenStream::empty())
            .with_diagnostics(Diagnostics::new(vec![Diagnostic::error(
                format!("{DOJO_MODEL_ATTR} attribute requires a '{MODEL_NAMESPACE}' argument. Use `#[{DOJO_MODEL_ATTR} ({MODEL_NAMESPACE}: \"<namespace>\")]` to specify the namespace.",
                ))]));
    };

    let model_version = if let Some(model_version) = parsed_args.get("version") {
        if let Ok(version) = model_version.parse::<u64>() {
            version
        } else {
            return ProcMacroResult::new(TokenStream::empty()).with_diagnostics(Diagnostics::new(
                vec![Diagnostic::error(format!(
                    "Invalid model version: {model_version}. Expected a number (u64)."
                ))],
            ));
        }
    } else {
        DEFAULT_VERSION
    };

    let db = SimpleParserDatabase::default();
    let (syn_file, _diagnostics) = db.parse_virtual_with_diagnostics(token_stream);

    for n in syn_file.descendants(&db) {
        if n.kind(&db) == ItemStruct {
            let struct_ast = ast::ItemStruct::from_syntax_node(&db, n);

            match DojoModel::from_struct(&model_namespace, model_version, &db, &struct_ast) {
                Some(c) => {
                    return ProcMacroResult::new(c.token_stream)
                        .with_diagnostics(Diagnostics::new(c.diagnostics))
                        .with_aux_data(AuxData::new(
                            serde_json::to_vec(&ModelAuxData {
                                name: c.name.to_string(),
                                namespace: c.namespace.to_string(),
                                members: c.members,
                            })
                            .expect("Failed to serialize contract aux data to bytes"),
                        ));
                }
                None => return ProcMacroResult::new(TokenStream::empty()),
            };
        }
    }

    ProcMacroResult::new(TokenStream::empty())
}

#[derive(Debug, Clone, Default)]
pub struct DojoModel {
    pub name: String,
    pub namespace: String,
    pub diagnostics: Vec<Diagnostic>,
    pub token_stream: TokenStream,
    pub members: Vec<Member>,
}

impl DojoModel {
    pub fn from_struct(
        model_namespace: &str,
        model_version: u64,
        db: &dyn SyntaxGroup,
        struct_ast: &ast::ItemStruct,
    ) -> Option<DojoModel> {
        let mut model = DojoModel {
            diagnostics: vec![],
            members: vec![],
            token_stream: TokenStream::empty(),
            name: String::new(),
            namespace: String::new(),
        };

        let model_name = struct_ast
            .name(db)
            .as_syntax_node()
            .get_text(db)
            .trim()
            .to_string();

        model.diagnostics.extend(validate_namings_diagnostics(&[
            ("model namespace", model_namespace),
            ("model name", &model_name),
        ]));

        let model_tag = naming::get_tag(model_namespace, &model_name);
        let model_name_hash = naming::compute_bytearray_hash(&model_name);
        let model_namespace_hash = naming::compute_bytearray_hash(model_namespace);
        let model_selector =
            naming::compute_selector_from_hashes(model_namespace_hash, model_name_hash);

        let members = parse_members(
            db,
            &struct_ast.members(db).elements(db),
            &mut model.diagnostics,
        );

        let mut serialized_keys: Vec<TokenStream> = vec![];
        let mut serialized_values: Vec<TokenStream> = vec![];

        serialize_keys_and_values(&members, &mut serialized_keys, &mut serialized_values);

        if serialized_keys.is_empty() {
            model
                .diagnostics
                .push_error("Model must define at least one #[key] attribute".to_string());
        }

        if serialized_values.is_empty() {
            model
                .diagnostics
                .push_error("Model must define at least one member that is not a key".to_string());
        }

        let mut deserialized_keys: Vec<TokenStream> = vec![];
        let mut deserialized_values: Vec<TokenStream> = vec![];

        deserialize_keys_and_values(
            &members,
            "keys",
            &mut deserialized_keys,
            "values",
            &mut deserialized_values,
        );

        let mut member_key_names: Vec<TokenStream> = vec![];
        let mut member_value_names: Vec<TokenStream> = vec![];
        let mut members_values: Vec<TokenStream> = vec![];
        let mut param_keys: Vec<String> = vec![];
        let mut serialized_param_keys: Vec<TokenStream> = vec![];

        members.iter().for_each(|member| {
            if member.key {
                param_keys.push(format!("{}: {}", member.name, member.ty));
                serialized_param_keys.push(serialize_member_ty(member, false));
                member_key_names.push(TokenStream::new(format!("{},\n", member.name.clone())));
            } else {
                members_values.push(TokenStream::new(format!(
                    "pub {}: {},\n",
                    member.name, member.ty
                )));
                member_value_names.push(TokenStream::new(format!("{},\n", member.name.clone())));
            }
        });

        let param_keys = param_keys.join(", ");

        let mut field_accessors: Vec<TokenStream> = vec![];
        let mut entity_field_accessors: Vec<TokenStream> = vec![];

        members.iter().filter(|m| !m.key).for_each(|member| {
            field_accessors.push(generate_field_accessors(
                model_name.clone(),
                param_keys.clone(),
                serialized_param_keys.clone(),
                member,
            ));
            entity_field_accessors
                .push(generate_entity_field_accessors(model_name.clone(), member));
        });

        let derive_attr_names = extract_derive_attr_names(
            db,
            &mut model.diagnostics,
            struct_ast.attributes(db).query_attr(db, "derive"),
        );

        let has_introspect = derive_attr_names.contains(&DOJO_INTROSPECT_DERIVE.to_string());
        let has_introspect_packed = derive_attr_names.contains(&DOJO_PACKED_DERIVE.to_string());
        let has_drop = derive_attr_names.contains(&"Drop".to_string());
        let has_serde = derive_attr_names.contains(&"Serde".to_string());

        if has_introspect && has_introspect_packed {
            model.diagnostics.push_error(
                "Model cannot derive from both Introspect and IntrospectPacked.".to_string(),
            );
        }

        #[allow(clippy::nonminimal_bool)]
        if !(has_introspect || has_introspect_packed) && !has_drop && !has_serde {
            model.diagnostics.push_error(
                "Model must derive from Introspect or IntrospectPacked, Drop and Serde."
                    .to_string(),
            );
        }

        let derive_node = if has_introspect {
            TokenStream::new(format!("#[derive({})]", DOJO_INTROSPECT_DERIVE))
        } else if has_introspect_packed {
            TokenStream::new(format!("#[derive({})]", DOJO_PACKED_DERIVE))
        } else {
            TokenStream::empty()
        };

        // Must remove the derives from the original struct since they would create duplicates
        // with the derives of other plugins.
        let original_struct = remove_derives(db, struct_ast);

        let node = TokenStream::interpolate_patched(
            MODEL_PATCH,
            &HashMap::from([
                ("contract_name".to_string(), model_name.to_case(Case::Snake)),
                ("type_name".to_string(), model_name.clone()),
                (
                    "member_key_names".to_string(),
                    member_key_names.join_to_token_stream("").to_string(),
                ),
                (
                    "member_value_names".to_string(),
                    member_value_names.join_to_token_stream("").to_string(),
                ),
                (
                    "serialized_keys".to_string(),
                    serialized_keys.join_to_token_stream("").to_string(),
                ),
                (
                    "serialized_values".to_string(),
                    serialized_values.join_to_token_stream("").to_string(),
                ),
                (
                    "deserialized_keys".to_string(),
                    deserialized_keys.join_to_token_stream("").to_string(),
                ),
                (
                    "deserialized_values".to_string(),
                    deserialized_values.join_to_token_stream("").to_string(),
                ),
                ("model_version".to_string(), model_version.to_string()),
                ("model_selector".to_string(), model_selector.to_string()),
                ("model_namespace".to_string(), model_namespace.to_string()),
                ("model_name_hash".to_string(), model_name_hash.to_string()),
                (
                    "model_namespace_hash".to_string(),
                    model_namespace_hash.to_string(),
                ),
                ("model_tag".to_string(), model_tag.clone()),
                (
                    "members_values".to_string(),
                    members_values.join_to_token_stream("").to_string(),
                ),
                ("param_keys".to_string(), param_keys),
                (
                    "serialized_param_keys".to_string(),
                    serialized_param_keys.join_to_token_stream("").to_string(),
                ),
                (
                    "field_accessors".to_string(),
                    field_accessors.join_to_token_stream("").to_string(),
                ),
                (
                    "entity_field_accessors".to_string(),
                    entity_field_accessors.join_to_token_stream("").to_string(),
                ),
            ]),
        );

        model.namespace = model_namespace.to_string();
        model.name = model_name.to_string();
        model.members = members;
        model.token_stream = vec![derive_node, original_struct, node].join_to_token_stream("");

        crate::debug_expand(
            &format!("MODEL PATCH: {model_namespace}-{model_name}"),
            &model.token_stream.to_string(),
        );

        Some(model)
    }
}

/// Generates field accessors (`get_[field_name]` and `set_[field_name]`) for every
/// fields of a model.
///
/// # Arguments
///
/// * `model_name` - the model name.
/// * `param_keys` - coma separated model keys with the format `KEY_NAME: KEY_TYPE`.
/// * `serialized_param_keys` - code to serialize model keys in a `serialized` felt252 array.
/// * `member` - information about the field for which to generate accessors.
///
/// # Returns
/// A [`RewriteNode`] containing accessors code.
fn generate_field_accessors(
    model_name: String,
    param_keys: String,
    serialized_param_keys: Vec<TokenStream>,
    member: &Member,
) -> TokenStream {
    TokenStream::interpolate_patched(
        "
    fn get_$field_name$(world: dojo::world::IWorldDispatcher, $param_keys$) -> $field_type$ {
        let mut serialized = core::array::ArrayTrait::new();
        $serialized_param_keys$

        let mut values = dojo::model::Model::<$model_name$>::get_member(
            world,
            serialized.span(),
            $field_selector$
        );

        let field_value = core::serde::Serde::<$field_type$>::deserialize(ref values);

        if core::option::OptionTrait::<$field_type$>::is_none(@field_value) {
            panic!(
                \"Field `$model_name$::$field_name$`: deserialization failed.\"
            );
        }

        core::option::OptionTrait::<$field_type$>::unwrap(field_value)
    }

    fn set_$field_name$(self: @$model_name$, world: dojo::world::IWorldDispatcher, value: \
         $field_type$) {
        let mut serialized = core::array::ArrayTrait::new();
        core::serde::Serde::serialize(@value, ref serialized);

        dojo::model::Model::<$model_name$>::set_member(
            self,
            world,
            $field_selector$,
            serialized.span()
        );
    }
            ",
        &HashMap::from([
            ("model_name".to_string(), model_name),
            (
                "field_selector".to_string(),
                get_selector_from_name(&member.name)
                    .expect("invalid member name")
                    .to_string(),
            ),
            ("field_name".to_string(), member.name.clone()),
            ("field_type".to_string(), member.ty.clone()),
            ("param_keys".to_string(), param_keys),
            (
                "serialized_param_keys".to_string(),
                serialized_param_keys.join_to_token_stream("").to_string(),
            ),
        ]),
    )
}

/// Generates field accessors (`get_[field_name]` and `set_[field_name]`) for every
/// fields of a model entity.
///
/// # Arguments
///
/// * `model_name` - the model name.
/// * `member` - information about the field for which to generate accessors.
///
/// # Returns
/// A [`RewriteNode`] containing accessors code.
fn generate_entity_field_accessors(model_name: String, member: &Member) -> TokenStream {
    TokenStream::interpolate_patched(
        "
    fn get_$field_name$(world: dojo::world::IWorldDispatcher, entity_id: felt252) -> $field_type$ \
         {
        let mut values = dojo::model::ModelEntity::<$model_name$Entity>::get_member(
            world,
            entity_id,
            $field_selector$
        );
        let field_value = core::serde::Serde::<$field_type$>::deserialize(ref values);

        if core::option::OptionTrait::<$field_type$>::is_none(@field_value) {
            panic!(
                \"Field `$model_name$::$field_name$`: deserialization failed.\"
            );
        }

        core::option::OptionTrait::<$field_type$>::unwrap(field_value)
    }

    fn set_$field_name$(self: @$model_name$Entity, world: dojo::world::IWorldDispatcher, value: \
         $field_type$) {
        let mut serialized = core::array::ArrayTrait::new();
        core::serde::Serde::serialize(@value, ref serialized);

        dojo::model::ModelEntity::<$model_name$Entity>::set_member(
            self,
            world,
            $field_selector$,
            serialized.span()
        );
    }
",
        &HashMap::from([
            ("model_name".to_string(), model_name),
            (
                "field_selector".to_string(),
                get_selector_from_name(&member.name)
                    .expect("invalid member name")
                    .to_string(),
            ),
            ("field_name".to_string(), member.name.clone()),
            ("field_type".to_string(), member.ty.clone()),
        ]),
    )
}
