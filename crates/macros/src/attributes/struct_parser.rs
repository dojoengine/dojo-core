use std::collections::HashMap;

use cairo_lang_macro::{Diagnostic, Severity, TokenStream};
use cairo_lang_syntax::node::ast::{
    ArgClause, ArgClauseNamed, Expr, ItemStruct, Member as MemberAst, OptionArgListParenthesized,
};
use cairo_lang_syntax::node::db::SyntaxGroup;
use cairo_lang_syntax::node::helpers::QueryAttrs;
use cairo_lang_syntax::node::{Terminal, TypedSyntaxNode};
use dojo_types::naming;
use crate::aux_data::Member;
use crate::diagnostic_ext::DiagnosticsExt;

pub const DEFAULT_VERSION: u8 = 1;

pub const PARAMETER_VERSION_NAME: &str = "version";
pub const PARAMETER_NAMESPACE: &str = "namespace";

/// `StructParameterParser` provides a general `from_struct` function to parse
/// the parameters of a struct attribute like dojo::model or dojo::event.
///
/// Processing of specific parameters can then be implemented through the `process_named_parameters`
/// function.
pub trait StructParameterParser {
    fn load_from_struct(
        &mut self,
        db: &dyn SyntaxGroup,
        attribute_name: &String,
        struct_ast: ItemStruct,
        diagnostics: &mut Vec<Diagnostic>,
    ) {
        let mut processed_args: HashMap<String, bool> = HashMap::new();

        if let OptionArgListParenthesized::ArgListParenthesized(arguments) = struct_ast
            .attributes(db)
            .query_attr(db, attribute_name)
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

                        if processed_args.contains_key(&arg_name) {
                            diagnostics.push(Diagnostic {
                                message: format!(
                                    "Too many '{}' attributes for {attribute_name}",
                                    arg_name
                                ),
                                severity: Severity::Error,
                            });
                        } else {
                            processed_args.insert(arg_name.clone(), true);
                            self.process_named_parameters(db, attribute_name, x, diagnostics);
                        }
                    }
                    ArgClause::Unnamed(x) => {
                        diagnostics.push(Diagnostic {
                            message: format!(
                                "Unexpected argument '{}' for {attribute_name}",
                                x.as_syntax_node().get_text(db)
                            ),
                            severity: Severity::Warning,
                        });
                    }
                    ArgClause::FieldInitShorthand(x) => {
                        diagnostics.push(Diagnostic {
                            message: format!(
                                "Unexpected argument '{}' for {attribute_name}",
                                x.name(db).name(db).text(db).to_string()
                            ),
                            severity: Severity::Warning,
                        });
                    }
                })
        }
    }

    fn process_named_parameters(
        &mut self,
        db: &dyn SyntaxGroup,
        attribute_name: &str,
        arg: ArgClauseNamed,
        diagnostics: &mut Vec<Diagnostic>,
    );
}

#[derive(Debug)]
pub struct CommonStructParameters {
    pub version: u8,
    pub namespace: String,
}

impl Default for CommonStructParameters {
    fn default() -> CommonStructParameters {
        CommonStructParameters {
            version: DEFAULT_VERSION,
            namespace: String::new(),
        }
    }
}

impl StructParameterParser for CommonStructParameters {
    fn process_named_parameters(
        &mut self,
        db: &dyn SyntaxGroup,
        attribute_name: &str,
        arg: ArgClauseNamed,
        diagnostics: &mut Vec<Diagnostic>,
    ) {
        let arg_name = arg.name(db).text(db).to_string();
        let arg_value = arg.value(db);

        match arg_name.as_str() {
            PARAMETER_VERSION_NAME => {
                self.version = get_version(db, attribute_name, arg_value, diagnostics);
            }
            PARAMETER_NAMESPACE => {
                if let Some(ns) = get_namespace(db, attribute_name, arg_value, diagnostics) {
                    self.namespace = ns;
                } else {
                    diagnostics.push(Diagnostic {
                        message: format!(
                            "Namespace is required for dojo::{attribute_name}. Use `#[dojo::{attribute_name}(namespace = \"namespace\")]` to set the namespace.",
                        ),
                        severity: Severity::Error,
                    });
                }
            }
            _ => {
                diagnostics.push(Diagnostic {
                    message: format!("Unexpected argument '{}' for {attribute_name}", arg_name),
                    severity: Severity::Warning,
                });
            }
        }
    }
}

pub fn parse_members(
    db: &dyn SyntaxGroup,
    members: &[MemberAst],
    diagnostics: &mut Vec<Diagnostic>,
) -> Vec<Member> {
    members
        .iter()
        .filter_map(|member_ast| {
            let member = Member {
                name: member_ast.name(db).text(db).to_string(),
                ty: member_ast
                    .type_clause(db)
                    .ty(db)
                    .as_syntax_node()
                    .get_text(db)
                    .trim()
                    .to_string(),
                key: member_ast.has_attr(db, "key"),
            };

            // validate key member
            if member.key && member.ty == "u256" {
                diagnostics.push(Diagnostic {
                    message: "Key is only supported for core types that are 1 felt long once \
                              serialized. `u256` is a struct of 2 u128, hence not supported."
                        .into(),
                    severity: Severity::Error,
                });
                None
            } else {
                Some(member)
            }
        })
        .collect::<Vec<_>>()
}

pub fn serialize_keys_and_values(
    members: &[Member],
    serialized_keys: &mut Vec<TokenStream>,
    serialized_values: &mut Vec<TokenStream>,
) {
    members.iter().for_each(|member| {
        if member.key {
            serialized_keys.push(serialize_member_ty(member, true));
        } else {
            serialized_values.push(serialize_member_ty(member, true));
        }
    });
}

pub fn deserialize_keys_and_values(
    members: &[Member],
    keys_input_name: &str,
    deserialized_keys: &mut Vec<TokenStream>,
    values_input_name: &str,
    deserialized_values: &mut Vec<TokenStream>,
) {
    members.iter().for_each(|member| {
        if member.key {
            deserialized_keys.push(deserialize_member_ty(member, keys_input_name));
        } else {
            deserialized_values.push(deserialize_member_ty(member, values_input_name));
        }
    });
}

/// Creates a [`RewriteNode`] for the member type serialization.
///
/// # Arguments
///
/// * member: The member to serialize.
pub fn serialize_member_ty(member: &Member, with_self: bool) -> TokenStream {
    TokenStream::new(format!(
        "core::serde::Serde::serialize({}{}, ref serialized);\n",
        if with_self { "self." } else { "@" },
        member.name
    ))
}

pub fn deserialize_member_ty(member: &Member, input_name: &str) -> TokenStream {
    TokenStream::new(format!(
        "let {} = core::serde::Serde::<{}>::deserialize(ref {input_name})?;\n",
        member.name, member.ty
    ))
}

/// Get the version from the `Expr` parameter.
fn get_version(
    db: &dyn SyntaxGroup,
    attribute_name: &str,
    arg_value: Expr,
    diagnostics: &mut Vec<Diagnostic>,
) -> u8 {
    match arg_value {
        Expr::Literal(ref value) => {
            if let Ok(value) = value.text(db).parse::<u8>() {
                if value <= DEFAULT_VERSION {
                    value
                } else {
                    diagnostics.push(Diagnostic {
                        message: format!("{attribute_name} version {} not supported", value),
                        severity: Severity::Error,
                    });
                    DEFAULT_VERSION
                }
            } else {
                diagnostics.push(Diagnostic {
                    message: format!(
                        "The argument '{}' of {attribute_name} must be an integer",
                        PARAMETER_VERSION_NAME
                    ),
                    severity: Severity::Error,
                });
                DEFAULT_VERSION
            }
        }
        _ => {
            diagnostics.push(Diagnostic {
                message: format!(
                    "The argument '{}' of {attribute_name} must be an integer",
                    PARAMETER_VERSION_NAME
                ),
                severity: Severity::Error,
            });
            DEFAULT_VERSION
        }
    }
}

/// Get the namespace from the `Expr` parameter.
fn get_namespace(
    db: &dyn SyntaxGroup,
    attribute_name: &str,
    arg_value: Expr,
    diagnostics: &mut Vec<Diagnostic>,
) -> Option<String> {
    match arg_value {
        Expr::ShortString(ss) => Some(ss.string_value(db).unwrap()),
        Expr::String(s) => Some(s.string_value(db).unwrap()),
        _ => {
            diagnostics.push(Diagnostic {
                message: format!(
                    "The argument '{}' of {attribute_name} must be a string",
                    PARAMETER_NAMESPACE
                ),
                severity: Severity::Error,
            });
            Option::None
        }
    }
}

/// Validates the namings of the attributes.
///
/// # Arguments
///
/// * namings: A list of tuples containing the id and value of the attribute.
///
/// # Returns
///
/// A vector of diagnostics.
pub fn validate_namings_diagnostics(namings: &[(&str, &str)]) -> Vec<Diagnostic> {
    let mut diagnostics = vec![];

    for (id, value) in namings {
        if !naming::is_name_valid(value) {
            diagnostics.push_error(format!(
                "The {id} '{value}' can only contain characters (a-z/A-Z), \
                     digits (0-9) and underscore (_)."
            ));
        }
    }

    diagnostics
}

/// Removes the derives from the original struct.
pub fn remove_derives(db: &dyn SyntaxGroup, struct_ast: &ItemStruct) -> TokenStream {
    let mut out_lines = vec![];

    let struct_str = struct_ast.as_syntax_node().get_text_without_trivia(db).to_string();

    for l in struct_str.lines() {
        if !l.starts_with("#[derive") {
            out_lines.push(l);
        }
    }

    TokenStream::new(out_lines.join("\n"))
}
