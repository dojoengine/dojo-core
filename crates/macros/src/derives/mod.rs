//! Derive macros.
//!
//! A derive macros is a macro that is used to generate code generally for a struct or enum.
//! The input of the macro consists of the AST of the struct or enum and the attributes of the derive macro.

use cairo_lang_macro::{Diagnostic, ProcMacroResult, TokenStream};
use cairo_lang_syntax::attribute::structured::{AttributeArgVariant, AttributeStructurize};
use cairo_lang_syntax::node::ast::Attribute;
use cairo_lang_syntax::node::db::SyntaxGroup;
use cairo_lang_syntax::node::ids::SyntaxStablePtrId;
use cairo_lang_syntax::node::{ast, Terminal, TypedSyntaxNode};

use crate::diagnostic_ext::DiagnosticsExt;

pub const DOJO_PRINT_DERIVE: &str = "Print";
pub const DOJO_INTROSPECT_DERIVE: &str = "Introspect";
pub const DOJO_PACKED_DERIVE: &str = "IntrospectPacked";

/// Extracts the names of the derive attributes from the given attributes.
///
/// # Examples
///
/// Derive usage should look like this:
///
/// ```no_run,ignore
/// #[derive(Introspect)]
/// struct MyStruct {}
/// ```
///
/// And this function will return `["Introspect"]`.
pub fn extract_derive_attr_names(
    db: &dyn SyntaxGroup,
    diagnostics: &mut Vec<Diagnostic>,
    attrs: Vec<Attribute>,
) -> Vec<String> {
    attrs
        .iter()
        .filter_map(|attr| {
            let args = attr.clone().structurize(db).args;
            if args.is_empty() {
                diagnostics.push_error("Expected args.".into());
                None
            } else {
                Some(args.into_iter().filter_map(|a| {
                    if let AttributeArgVariant::Unnamed(ast::Expr::Path(path)) = a.variant {
                        if let [ast::PathSegment::Simple(segment)] = &path.elements(db)[..] {
                            Some(segment.ident(db).text(db).to_string())
                        } else {
                            None
                        }
                    } else {
                        None
                    }
                }))
            }
        })
        .flatten()
        .collect::<Vec<_>>()
}
