use cairo_lang_macro::Diagnostic;
use cairo_lang_syntax::node::db::SyntaxGroup;
use cairo_lang_syntax::node::ast;

use crate::diagnostic_ext::DiagnosticsExt;

use super::utils as syntax_utils;

const WORLD_PARAM_NAME: &str = "world";
const WORLD_PARAM_TYPE: &str = "IWorldDispatcher";
const WORLD_PARAM_TYPE_SNAPSHOT: &str = "@IWorldDispatcher";

#[derive(Debug, PartialEq, Eq)]
pub enum WorldParamInjectionKind {
    None,
    View,
    External,
}

/// Checks if the given parameter is the `world` parameter.
///
/// The `world` must be named `world`, and be placed first in the argument list.
pub fn is_world_param(param_name: &str, param_type: &str) -> bool {
    param_name == WORLD_PARAM_NAME
        && (param_type == WORLD_PARAM_TYPE || param_type == WORLD_PARAM_TYPE_SNAPSHOT)
}

/// Extracts the state mutability of a function from the `world` parameter.
///
/// Checks if the function has only one `world` parameter (or None).
/// The `world` must be named `world`, and be placed first in the argument list.
///
/// `fn func1(ref world)` // would be external.
/// `fn func2(world)` // would be view.
/// `fn func3()` // would be view.
///
/// Returns
///  * The [`WorldParamInjectionKind`] determined from the function's params list.
pub fn parse_world_injection(
    db: &dyn SyntaxGroup,
    param_list: ast::ParamList,
    diagnostics: &mut Vec<Diagnostic>,
) -> WorldParamInjectionKind {
    let mut has_world_injected = false;
    let mut injection_kind = WorldParamInjectionKind::None;

    param_list
        .elements(db)
        .iter()
        .enumerate()
        .for_each(|(idx, param)| {
            let (name, modifiers, param_type) = syntax_utils::get_parameter_info(db, param.clone());

            if !is_world_param(&name, &param_type) {
                if name.eq(super::self_param::SELF_PARAM_NAME) && has_world_injected {
                    diagnostics.push_error(format!(
                        "You cannot use `self` and `world` parameters together."
                    ));
                }

                return;
            }

            if has_world_injected {
                diagnostics.push_error(format!(
                    "Only one world parameter is allowed"
                ));

                return;
            } else {
                has_world_injected = true;
            }

            if idx != 0 {
                diagnostics.push_error(format!(
                    "World parameter must be the first parameter."
                ));

                return;
            }

            if modifiers.contains(&"ref".to_string()) {
                injection_kind = WorldParamInjectionKind::External;
            } else {
                injection_kind = WorldParamInjectionKind::View;

                if param_type == WORLD_PARAM_TYPE {
                    diagnostics.push_error(format!(
                        "World parameter must be a snapshot if `ref` is not used."
                    ));
                }
            }
        });

    injection_kind
}
