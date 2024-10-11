//! Handle the `dojo::model` attribute macro.

use cairo_lang_defs::patcher::{PatchBuilder, RewriteNode};
use cairo_lang_defs::plugin::{
    DynGeneratedFileAuxData, PluginDiagnostic, PluginGeneratedFile, PluginResult,
};
use cairo_lang_diagnostics::Severity;
use cairo_lang_syntax::node::ast::{ItemStruct, ModuleItem};
use cairo_lang_syntax::node::db::SyntaxGroup;
use cairo_lang_syntax::node::helpers::QueryAttrs;
use cairo_lang_syntax::node::{TypedStablePtr, TypedSyntaxNode};
use cairo_lang_utils::unordered_hash_map::UnorderedHashMap;
use convert_case::{Case, Casing};
use dojo_types::naming;
use starknet::core::utils::get_selector_from_name;

use crate::aux_data::ModelAuxData;
use crate::compiler::annotation::Member;
use crate::namespace_config::NamespaceConfig;
use crate::plugin::derive_macros::{
    extract_derive_attr_names, handle_derive_attrs, DOJO_INTROSPECT_DERIVE, DOJO_PACKED_DERIVE,
};

use super::element::{
    compute_namespace, deserialize_keys_and_values, parse_members, serialize_keys_and_values,
    serialize_member_ty, CommonStructParameters, StructParameterParser, DEFAULT_VERSION,
};
use super::patches::MODEL_PATCH;
use super::DOJO_MODEL_ATTR;

type ModelParameters = CommonStructParameters;

#[derive(Debug, Clone, Default)]
pub struct DojoModel {}

impl DojoModel {
    /// A handler for Dojo code that modifies a model struct.
    /// Parameters:
    /// * db: The semantic database.
    /// * struct_ast: The AST of the model struct.
    ///
    /// Returns:
    /// * A RewriteNode containing the generated code.
    pub fn from_struct(
        db: &dyn SyntaxGroup,
        struct_ast: ItemStruct,
        namespace_config: &NamespaceConfig,
    ) -> PluginResult {
        let mut diagnostics = vec![];
        let mut parameters = ModelParameters::default();

        parameters.load_from_struct(
            db,
            &DOJO_MODEL_ATTR.to_string(),
            struct_ast.clone(),
            &mut diagnostics,
        );

        let model_name = struct_ast
            .name(db)
            .as_syntax_node()
            .get_text(db)
            .trim()
            .to_string();

        let model_namespace = compute_namespace(&model_name, &parameters, namespace_config);

        for (id, value) in [("name", &model_name), ("namespace", &model_namespace)] {
            if !NamespaceConfig::is_name_valid(value) {
                return PluginResult {
                    code: None,
                    diagnostics: vec![PluginDiagnostic {
                        stable_ptr: struct_ast.stable_ptr().0,
                        message: format!(
                            "The model {id} '{value}' can only contain characters (a-z/A-Z), \
                             digits (0-9) and underscore (_)."
                        ),
                        severity: Severity::Error,
                    }],
                    remove_original_item: false,
                };
            }
        }

        let model_tag = naming::get_tag(&model_namespace, &model_name);
        let model_name_hash = naming::compute_bytearray_hash(&model_name);
        let model_namespace_hash = naming::compute_bytearray_hash(&model_namespace);

        let (model_version, model_selector) = match parameters.version {
            0 => (
                RewriteNode::Text("0".to_string()),
                RewriteNode::Text(format!("\"{model_name}\"")),
            ),
            _ => (
                RewriteNode::Text(DEFAULT_VERSION.to_string()),
                RewriteNode::Text(
                    naming::compute_selector_from_hashes(model_namespace_hash, model_name_hash)
                        .to_string(),
                ),
            ),
        };

        let members = parse_members(db, &struct_ast.members(db).elements(db), &mut diagnostics);
        let mut serialized_keys: Vec<RewriteNode> = vec![];
        let mut serialized_values: Vec<RewriteNode> = vec![];

        serialize_keys_and_values(&members, &mut serialized_keys, &mut serialized_values);

        if serialized_keys.is_empty() {
            diagnostics.push(PluginDiagnostic {
                message: "Model must define at least one #[key] attribute".into(),
                stable_ptr: struct_ast.name(db).stable_ptr().untyped(),
                severity: Severity::Error,
            });
        }

        if serialized_values.is_empty() {
            diagnostics.push(PluginDiagnostic {
                message: "Model must define at least one member that is not a key".into(),
                stable_ptr: struct_ast.name(db).stable_ptr().untyped(),
                severity: Severity::Error,
            });
        }

        let mut deserialized_keys: Vec<RewriteNode> = vec![];
        let mut deserialized_values: Vec<RewriteNode> = vec![];

        deserialize_keys_and_values(
            &members,
            "keys",
            &mut deserialized_keys,
            "values",
            &mut deserialized_values,
        );

        let mut member_key_names: Vec<RewriteNode> = vec![];
        let mut member_value_names: Vec<RewriteNode> = vec![];
        let mut members_values: Vec<RewriteNode> = vec![];
        let mut param_keys: Vec<String> = vec![];
        let mut serialized_param_keys: Vec<RewriteNode> = vec![];

        members.iter().for_each(|member| {
            if member.key {
                param_keys.push(format!("{}: {}", member.name, member.ty));
                serialized_param_keys.push(serialize_member_ty(member, false));
                member_key_names.push(RewriteNode::Text(format!("{},\n", member.name.clone())));
            } else {
                members_values.push(RewriteNode::Text(format!(
                    "pub {}: {},\n",
                    member.name, member.ty
                )));
                member_value_names.push(RewriteNode::Text(format!("{},\n", member.name.clone())));
            }
        });

        let param_keys = param_keys.join(", ");

        let mut field_accessors: Vec<RewriteNode> = vec![];
        let mut entity_field_accessors: Vec<RewriteNode> = vec![];

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

        let mut derive_attr_names = extract_derive_attr_names(
            db,
            &mut diagnostics,
            struct_ast.attributes(db).query_attr(db, "derive"),
        );

        // Ensures models always derive Introspect if not already derived.
        if !derive_attr_names.contains(&DOJO_INTROSPECT_DERIVE.to_string())
            && !derive_attr_names.contains(&DOJO_PACKED_DERIVE.to_string())
        {
            // Default to Introspect, and not packed.
            derive_attr_names.push(DOJO_INTROSPECT_DERIVE.to_string());
        }

        let (derive_nodes, derive_diagnostics) = handle_derive_attrs(
            db,
            &derive_attr_names,
            &ModuleItem::Struct(struct_ast.clone()),
        );

        diagnostics.extend(derive_diagnostics);

        let node = RewriteNode::interpolate_patched(
            MODEL_PATCH,
            &UnorderedHashMap::from([
                (
                    "contract_name".to_string(),
                    RewriteNode::Text(model_name.to_case(Case::Snake)),
                ),
                (
                    "type_name".to_string(),
                    RewriteNode::Text(model_name.clone()),
                ),
                (
                    "member_key_names".to_string(),
                    RewriteNode::new_modified(member_key_names),
                ),
                (
                    "member_value_names".to_string(),
                    RewriteNode::new_modified(member_value_names),
                ),
                (
                    "serialized_keys".to_string(),
                    RewriteNode::new_modified(serialized_keys),
                ),
                (
                    "serialized_values".to_string(),
                    RewriteNode::new_modified(serialized_values),
                ),
                (
                    "deserialized_keys".to_string(),
                    RewriteNode::new_modified(deserialized_keys),
                ),
                (
                    "deserialized_values".to_string(),
                    RewriteNode::new_modified(deserialized_values),
                ),
                ("model_version".to_string(), model_version),
                ("model_selector".to_string(), model_selector),
                (
                    "model_namespace".to_string(),
                    RewriteNode::Text(model_namespace.clone()),
                ),
                (
                    "model_name_hash".to_string(),
                    RewriteNode::Text(model_name_hash.to_string()),
                ),
                (
                    "model_namespace_hash".to_string(),
                    RewriteNode::Text(model_namespace_hash.to_string()),
                ),
                (
                    "model_tag".to_string(),
                    RewriteNode::Text(model_tag.clone()),
                ),
                (
                    "members_values".to_string(),
                    RewriteNode::new_modified(members_values),
                ),
                ("param_keys".to_string(), RewriteNode::Text(param_keys)),
                (
                    "serialized_param_keys".to_string(),
                    RewriteNode::new_modified(serialized_param_keys),
                ),
                (
                    "field_accessors".to_string(),
                    RewriteNode::new_modified(field_accessors),
                ),
                (
                    "entity_field_accessors".to_string(),
                    RewriteNode::new_modified(entity_field_accessors),
                ),
            ]),
        );

        let mut builder = PatchBuilder::new(db, &struct_ast);

        for node in derive_nodes {
            builder.add_modified(node);
        }

        builder.add_modified(node);

        let (code, code_mappings) = builder.build();

        crate::debug_expand(
            &format!("MODEL PATCH: {model_namespace}-{model_name}"),
            &code,
        );

        let aux_data = ModelAuxData {
            name: model_name.clone(),
            namespace: model_namespace.clone(),
            members,
        };

        PluginResult {
            code: Some(PluginGeneratedFile {
                name: model_name.into(),
                content: code,
                aux_data: Some(DynGeneratedFileAuxData::new(aux_data)),
                code_mappings,
            }),
            diagnostics,
            remove_original_item: false,
        }
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
    serialized_param_keys: Vec<RewriteNode>,
    member: &Member,
) -> RewriteNode {
    RewriteNode::interpolate_patched(
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

        self.set_member(
            world,
            $field_selector$,
            serialized.span()
        );
    }
            ",
        &UnorderedHashMap::from([
            ("model_name".to_string(), RewriteNode::Text(model_name)),
            (
                "field_selector".to_string(),
                RewriteNode::Text(
                    get_selector_from_name(&member.name)
                        .expect("invalid member name")
                        .to_string(),
                ),
            ),
            (
                "field_name".to_string(),
                RewriteNode::Text(member.name.clone()),
            ),
            (
                "field_type".to_string(),
                RewriteNode::Text(member.ty.clone()),
            ),
            ("param_keys".to_string(), RewriteNode::Text(param_keys)),
            (
                "serialized_param_keys".to_string(),
                RewriteNode::new_modified(serialized_param_keys),
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
fn generate_entity_field_accessors(model_name: String, member: &Member) -> RewriteNode {
    RewriteNode::interpolate_patched(
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

        self.set_member(
            world,
            $field_selector$,
            serialized.span()
        );
    }
",
        &UnorderedHashMap::from([
            ("model_name".to_string(), RewriteNode::Text(model_name)),
            (
                "field_selector".to_string(),
                RewriteNode::Text(
                    get_selector_from_name(&member.name)
                        .expect("invalid member name")
                        .to_string(),
                ),
            ),
            (
                "field_name".to_string(),
                RewriteNode::Text(member.name.clone()),
            ),
            (
                "field_type".to_string(),
                RewriteNode::Text(member.ty.clone()),
            ),
        ]),
    )
}
