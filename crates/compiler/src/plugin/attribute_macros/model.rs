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
    compute_namespace, parse_members, serialize_member_ty, CommonStructParameters,
    StructParameterParser, DEFAULT_VERSION,
};
use super::DOJO_MODEL_ATTR;

const MODEL_CODE_PATCH: &str = include_str!("./patches/model_store.patch.cairo");
const MODEL_FIELD_CODE_PATCH: &str = include_str!("./patches/model_field_store.patch.cairo");
type ModelParameters = CommonStructParameters;
const ENTITY_DERIVE_IGNORE: [&str; 2] = [DOJO_INTROSPECT_DERIVE, DOJO_PACKED_DERIVE];

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

        let model_type = struct_ast
            .name(db)
            .as_syntax_node()
            .get_text(db)
            .trim()
            .to_string();
        let model_type_snake = model_type.to_case(Case::Snake);

        let model_namespace = compute_namespace(&model_type, &parameters, namespace_config);

        for (id, value) in [("name", &model_type), ("namespace", &model_namespace)] {
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

        let model_tag = naming::get_tag(&model_namespace, &model_type);
        let model_name_hash = naming::compute_bytearray_hash(&model_type);
        let model_namespace_hash = naming::compute_bytearray_hash(&model_namespace);

        let (model_version, model_selector) = match parameters.version {
            0 => (
                RewriteNode::Text("0".to_string()),
                RewriteNode::Text(format!("\"{model_type}\"")),
            ),
            _ => (
                RewriteNode::Text(DEFAULT_VERSION.to_string()),
                RewriteNode::Text(
                    naming::compute_selector_from_hashes(model_namespace_hash, model_name_hash)
                        .to_string(),
                ),
            ),
        };

        let mut values: Vec<Member> = vec![];
        let mut keys: Vec<Member> = vec![];
        let mut members_values: Vec<RewriteNode> = vec![];
        let mut key_types: Vec<String> = vec![];
        let mut key_attrs: Vec<String> = vec![];

        let mut serialized_keys: Vec<RewriteNode> = vec![];
        let mut serialized_values: Vec<RewriteNode> = vec![];
        let mut field_accessors: Vec<RewriteNode> = vec![];

        let members = parse_members(db, &struct_ast.members(db).elements(db), &mut diagnostics);

        members.iter().for_each(|member| {
            if member.key {
                keys.push(member.clone());
                key_types.push(member.ty.clone());
                key_attrs.push(format!("*self.{}", member.name.clone()));
                serialized_keys.push(serialize_member_ty(member, true));
            } else {
                values.push(member.clone());
                serialized_values.push(serialize_member_ty(member, true));
                members_values.push(RewriteNode::Text(format!(
                    "pub {}: {},\n",
                    member.name, member.ty
                )));
                field_accessors.push(generate_field_accessors(model_type.clone(), member));
            }
        });
        if keys.is_empty() {
            diagnostics.push(PluginDiagnostic {
                message: "Model must define at least one #[key] attribute".into(),
                stable_ptr: struct_ast.name(db).stable_ptr().untyped(),
                severity: Severity::Error,
            });
        }

        if values.is_empty() {
            diagnostics.push(PluginDiagnostic {
                message: "Model must define at least one member that is not a key".into(),
                stable_ptr: struct_ast.name(db).stable_ptr().untyped(),
                severity: Severity::Error,
            });
        }
        if !diagnostics.is_empty() {
            return PluginResult {
                code: None,
                diagnostics,
                remove_original_item: false,
            };
        }
        let (keys_to_tuple, key_type) = if keys.len() > 1 {
            (
                format!("({})", key_attrs.join(", ")),
                format!("({})", key_types.join(", ")),
            )
        } else {
            (
                key_attrs.first().unwrap().to_string(),
                key_types.first().unwrap().to_string(),
            )
        };

        let mut derive_attr_names = extract_derive_attr_names(
            db,
            &mut diagnostics,
            struct_ast.attributes(db).query_attr(db, "derive"),
        );

        // Ensures models always derive Introspect if not already derived.
        let entity_derive_attr_names = derive_attr_names
            .iter()
            .map(|tag| tag.as_str())
            .filter(|&tag| !ENTITY_DERIVE_IGNORE.contains(&tag))
            .collect::<Vec<&str>>()
            .join(", ");

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
            MODEL_CODE_PATCH,
            &UnorderedHashMap::from([
                (
                    "model_type".to_string(),
                    RewriteNode::Text(model_type.clone()),
                ),
                (
                    "model_type_snake".to_string(),
                    RewriteNode::Text(model_type_snake.clone()),
                ),
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
                ("model_version".to_string(), model_version),
                ("model_selector".to_string(), model_selector),
                (
                    "serialized_keys".to_string(),
                    RewriteNode::new_modified(serialized_keys),
                ),
                (
                    "serialized_values".to_string(),
                    RewriteNode::new_modified(serialized_values),
                ),
                (
                    "keys_to_tuple".to_string(),
                    RewriteNode::Text(keys_to_tuple),
                ),
                ("key_type".to_string(), RewriteNode::Text(key_type)),
                (
                    "members_values".to_string(),
                    RewriteNode::new_modified(members_values),
                ),
                (
                    "field_accessors".to_string(),
                    RewriteNode::new_modified(field_accessors),
                ),
                (
                    "entity_derive_attr_names".to_string(),
                    RewriteNode::Text(entity_derive_attr_names),
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
            &format!("MODEL PATCH: {model_namespace}-{model_type}"),
            &code,
        );

        let aux_data = ModelAuxData {
            name: model_type.clone(),
            namespace: model_namespace.clone(),
            members,
        };

        PluginResult {
            code: Some(PluginGeneratedFile {
                name: model_type.into(),
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
fn generate_field_accessors(model_type: String, member: &Member) -> RewriteNode {
    RewriteNode::interpolate_patched(
        MODEL_FIELD_CODE_PATCH,
        &UnorderedHashMap::from([
            ("model_type".to_string(), RewriteNode::Text(model_type)),
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
