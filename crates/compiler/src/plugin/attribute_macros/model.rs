//! Handle the `dojo::model` attribute macro.

use std::collections::HashMap;

use cairo_lang_defs::patcher::{PatchBuilder, RewriteNode};
use cairo_lang_defs::plugin::{
    DynGeneratedFileAuxData, PluginDiagnostic, PluginGeneratedFile, PluginResult,
};
use cairo_lang_diagnostics::Severity;
use cairo_lang_syntax::node::ast::{
    ArgClause, Expr, ItemStruct, Member as MemberAst, ModuleItem, OptionArgListParenthesized,
};
use cairo_lang_syntax::node::db::SyntaxGroup;
use cairo_lang_syntax::node::helpers::QueryAttrs;
use cairo_lang_syntax::node::{Terminal, TypedStablePtr, TypedSyntaxNode};
use cairo_lang_utils::unordered_hash_map::UnorderedHashMap;
use convert_case::{Case, Casing};
use dojo_types::naming;
use starknet::core::utils::get_selector_from_name;

use crate::aux_data::ModelAuxData;
use crate::compiler::manifest::Member;
use crate::namespace_config::NamespaceConfig;
use crate::plugin::derive_macros::{
    extract_derive_attr_names, handle_derive_attrs, DOJO_INTROSPECT_DERIVE, DOJO_PACKED_DERIVE,
};

const MODEL_CODE_STRING: &str = include_str!("./templates/model_store.generate.cairo");
const MODEL_FIELD_CODE_STRING: &str = include_str!("./templates/model_field_store.generate.cairo");
const ENTITY_FIELD_CODE_STRING: &str =
    include_str!("./templates/entity_field_store.generate.cairo");

use super::DOJO_MODEL_ATTR;

const DEFAULT_MODEL_VERSION: u8 = 1;

const MODEL_VERSION_NAME: &str = "version";
const MODEL_NAMESPACE: &str = "namespace";
const MODEL_NOMAPPING: &str = "nomapping";

#[derive(Debug, Clone, Default)]
pub struct DojoModel {}

struct ModelParameters {
    version: u8,
    namespace: Option<String>,
    nomapping: bool,
}

impl Default for ModelParameters {
    fn default() -> ModelParameters {
        ModelParameters {
            version: DEFAULT_MODEL_VERSION,
            namespace: Option::None,
            nomapping: false,
        }
    }
}

/// Get the model version from the `Expr` parameter.
fn get_model_version(
    db: &dyn SyntaxGroup,
    arg_value: Expr,
    diagnostics: &mut Vec<PluginDiagnostic>,
) -> u8 {
    match arg_value {
        Expr::Literal(ref value) => {
            if let Ok(value) = value.text(db).parse::<u8>() {
                if value <= DEFAULT_MODEL_VERSION {
                    value
                } else {
                    diagnostics.push(PluginDiagnostic {
                        message: format!("dojo::model version {} not supported", value),
                        stable_ptr: arg_value.stable_ptr().untyped(),
                        severity: Severity::Error,
                    });
                    DEFAULT_MODEL_VERSION
                }
            } else {
                diagnostics.push(PluginDiagnostic {
                    message: format!(
                        "The argument '{}' of dojo::model must be an integer",
                        MODEL_VERSION_NAME
                    ),
                    stable_ptr: arg_value.stable_ptr().untyped(),
                    severity: Severity::Error,
                });
                DEFAULT_MODEL_VERSION
            }
        }
        _ => {
            diagnostics.push(PluginDiagnostic {
                message: format!(
                    "The argument '{}' of dojo::model must be an integer",
                    MODEL_VERSION_NAME
                ),
                stable_ptr: arg_value.stable_ptr().untyped(),
                severity: Severity::Error,
            });
            DEFAULT_MODEL_VERSION
        }
    }
}

/// Get the model namespace from the `Expr` parameter.
fn get_model_namespace(
    db: &dyn SyntaxGroup,
    arg_value: Expr,
    diagnostics: &mut Vec<PluginDiagnostic>,
) -> Option<String> {
    match arg_value {
        Expr::ShortString(ss) => Some(ss.string_value(db).unwrap()),
        Expr::String(s) => Some(s.string_value(db).unwrap()),
        _ => {
            diagnostics.push(PluginDiagnostic {
                message: format!(
                    "The argument '{}' of dojo::model must be a string",
                    MODEL_NAMESPACE
                ),
                stable_ptr: arg_value.stable_ptr().untyped(),
                severity: Severity::Error,
            });
            Option::None
        }
    }
}

/// Get parameters of the dojo::model attribute.
///
/// Note: dojo::model attribute has already been checked so there is one and only one attribute.
///
/// Parameters:
/// * db: The semantic database.
/// * struct_ast: The AST of the model struct.
/// * diagnostics: vector of compiler diagnostics.
///
/// Returns:
/// * A [`ModelParameters`] object containing all the dojo::model parameters with their default
///   values if not set in the code.
fn get_model_parameters(
    db: &dyn SyntaxGroup,
    struct_ast: ItemStruct,
    diagnostics: &mut Vec<PluginDiagnostic>,
) -> ModelParameters {
    let mut parameters = ModelParameters::default();
    let mut processed_args: HashMap<String, bool> = HashMap::new();

    if let OptionArgListParenthesized::ArgListParenthesized(arguments) = struct_ast
        .attributes(db)
        .query_attr(db, DOJO_MODEL_ATTR)
        .first()
        .unwrap()
        .arguments(db)
    {
        arguments
            .arguments(db)
            .elements(db)
            .iter()
            .for_each(|a| match a.arg_clause(db) {
                ArgClause::Named(x) => {
                    let arg_name = x.name(db).text(db).to_string();
                    let arg_value = x.value(db);

                    if processed_args.contains_key(&arg_name) {
                        diagnostics.push(PluginDiagnostic {
                            message: format!("Too many '{}' attributes for dojo::model", arg_name),
                            stable_ptr: struct_ast.stable_ptr().untyped(),
                            severity: Severity::Error,
                        });
                    } else {
                        processed_args.insert(arg_name.clone(), true);

                        match arg_name.as_str() {
                            MODEL_VERSION_NAME => {
                                parameters.version = get_model_version(db, arg_value, diagnostics);
                            }
                            MODEL_NAMESPACE => {
                                parameters.namespace =
                                    get_model_namespace(db, arg_value, diagnostics);
                            }
                            MODEL_NOMAPPING => {
                                parameters.nomapping = true;
                            }
                            _ => {
                                diagnostics.push(PluginDiagnostic {
                                    message: format!(
                                        "Unexpected argument '{}' for dojo::model",
                                        arg_name
                                    ),
                                    stable_ptr: x.stable_ptr().untyped(),
                                    severity: Severity::Warning,
                                });
                            }
                        }
                    }
                }
                ArgClause::Unnamed(x) => {
                    diagnostics.push(PluginDiagnostic {
                        message: format!(
                            "Unexpected argument '{}' for dojo::model",
                            x.as_syntax_node().get_text(db)
                        ),
                        stable_ptr: x.stable_ptr().untyped(),
                        severity: Severity::Warning,
                    });
                }
                ArgClause::FieldInitShorthand(x) => {
                    diagnostics.push(PluginDiagnostic {
                        message: format!(
                            "Unexpected argument '{}' for dojo::model",
                            x.name(db).name(db).text(db).to_string()
                        ),
                        stable_ptr: x.stable_ptr().untyped(),
                        severity: Severity::Warning,
                    });
                }
            })
    }

    parameters
}

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

        let parameters = get_model_parameters(db, struct_ast.clone(), &mut diagnostics);

        let model_type = struct_ast
            .name(db)
            .as_syntax_node()
            .get_text(db)
            .trim()
            .to_string();
        let model_name_snake = RewriteNode::Text(model_type.to_case(Case::Snake));
        let model_name_snake_upper = RewriteNode::Text(model_type.to_case(Case::UpperSnake));

        let unmapped_namespace = parameters
            .namespace
            .unwrap_or(namespace_config.default.clone());

        let model_namespace = if parameters.nomapping {
            unmapped_namespace
        } else {
            // Maps namespace from the tag to ensure higher precision on matching namespace mappings.
            namespace_config.get_mapping(&naming::get_tag(&unmapped_namespace, &model_type))
        };

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
                RewriteNode::Text(DEFAULT_MODEL_VERSION.to_string()),
                RewriteNode::Text(
                    naming::compute_selector_from_hashes(model_namespace_hash, model_name_hash)
                        .to_string(),
                ),
            ),
        };

        let mut members: Vec<Member> = vec![];
        let mut values: Vec<Member> = vec![];
        let mut keys: Vec<Member> = vec![];

        let mut members_values: Vec<RewriteNode> = vec![];
        let mut param_keys: Vec<String> = vec![];

        let mut key_names: Vec<String> = vec![];
        let mut key_types: Vec<String> = vec![];
        let mut key_attrs: Vec<String> = vec![];

        let mut field_accessors: Vec<RewriteNode> = vec![];

        let elements = struct_ast.members(db).elements(db);

        elements.iter().for_each(|member_ast| {
            let member = ast_to_member(db, member_ast);
            members.push(member);
            if member.key {
                validate_key_member(&member, db, member_ast, &mut diagnostics);
                keys.push(member);
                key_types.push(member.ty.clone());
                key_attrs.push(format!("*self.{}", member.name.clone()))
            } else {
                values.push(member);
            }
        });

        let (key_attr, key_type) = if keys.len() > 1 {
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

        members.iter().filter(|m| !m.key).for_each(|member| {
            field_accessors.push(generate_field_accessors(
                model_type.clone(),
                param_keys.clone(),
                keys.clone(),
                serialized_param_keys.clone(),
                member,
            ));
            entity_field_accessors
                .push(generate_entity_field_accessors(model_type.clone(), member));
        });

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
            MODEL_CODE_STRING,
            &UnorderedHashMap::from([
                (
                    "model_name_snake".to_string(),
                    RewriteNode::Text(model_name_snake),
                ),
                (
                    "type_name".to_string(),
                    RewriteNode::Text(model_type.clone()),
                ),
                (
                    "namespace".to_string(),
                    RewriteNode::Text("namespace".to_string()),
                ),
                (
                    "serialized_keys".to_string(),
                    RewriteNode::new_modified(serialized_keys),
                ),
                (
                    "serialized_values".to_string(),
                    RewriteNode::new_modified(serialized_values),
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
                ("keys".to_string(), RewriteNode::Text(keys)),
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

fn ast_to_member(db: &dyn SyntaxGroup, member: &MemberAst) -> Member {
    Member {
        name: member.name(db).text(db).to_string(),
        ty: member
            .type_clause(db)
            .ty(db)
            .as_syntax_node()
            .get_text(db)
            .trim()
            .to_string(),
        key: member.has_attr(db, "key"),
    }
}

/// Validates that the key member is valid.
/// # Arguments
///
/// * member: The member to validate.
/// * diagnostics: The diagnostics to push to, if the member is an invalid key.
fn validate_key_member(
    member: &Member,
    db: &dyn SyntaxGroup,
    member_ast: &MemberAst,
    diagnostics: &mut Vec<PluginDiagnostic>,
) {
    if member.ty == "u256" {
        diagnostics.push(PluginDiagnostic {
            message: "Key is only supported for core types that are 1 felt long once serialized. \
                      `u256` is a struct of 2 u128, hence not supported."
                .into(),
            stable_ptr: member_ast.name(db).stable_ptr().untyped(),
            severity: Severity::Error,
        });
    }
}

/// Creates a [`RewriteNode`] for the member type serialization.
///
/// # Arguments
///
/// * member: The member to serialize.
fn serialize_member_ty(member: &Member, with_self: bool) -> RewriteNode {
    match member.ty.as_str() {
        "felt252" => RewriteNode::Text(format!(
            "core::array::ArrayTrait::append(ref serialized, {}{});\n",
            if with_self { "*self." } else { "" },
            member.name
        )),
        _ => RewriteNode::Text(format!(
            "core::serde::Serde::serialize({}{}, ref serialized);\n",
            if with_self { "self." } else { "@" },
            member.name
        )),
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
    keys: String,
    serialized_param_keys: Vec<RewriteNode>,
    member: &Member,
) -> RewriteNode {
    RewriteNode::interpolate_patched(
        MODEL_FIELD_CODE_STRING,
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
            ("keys".to_string(), RewriteNode::Text(keys)),
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
        ENTITY_FIELD_CODE_STRING,
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
