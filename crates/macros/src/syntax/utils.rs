use std::collections::HashMap;

use cairo_lang_syntax::node::ast::OptionTypeClause;
use cairo_lang_syntax::node::db::SyntaxGroup;
use cairo_lang_syntax::node::{ast, Terminal, TypedSyntaxNode};

/// Gets the name, modifiers and type of a function parameter.
///
/// # Arguments
///
/// * `db` - The syntax group.
/// * `param` - The parameter.
///
/// # Returns
///
/// * A tuple containing the name, modifiers and type of the parameter.
pub fn get_parameter_info(db: &dyn SyntaxGroup, param: ast::Param) -> (String, String, String) {
    let name = param.name(db).text(db).trim().to_string();
    let modifiers = param
        .modifiers(db)
        .as_syntax_node()
        .get_text(db)
        .trim()
        .to_string();

    let param_type = if let OptionTypeClause::TypeClause(ty) = param.type_clause(db) {
        ty.ty(db).as_syntax_node().get_text(db).trim().to_string()
    } else {
        "()".to_string()
    };

    (name, modifiers, param_type)
}

/// Extracts all arguments that are `key: value`, separated by commas.
/// This is used mainly with new proc macros that are already extracting the
/// arguments and passing them as a string.
///
/// `#[dojo_contract(namespace: "sn")]` is given as input as `(namespace: "sn")`.
///
/// # Arguments
///
/// * `args` - The arguments as a string in the format `(key: value, key: value, ...)`.
///
/// # Returns
///
/// * A `HashMap<String, String>` with the arguments.
pub fn parse_arguments_kv(args: &str) -> HashMap<String, String> {
    let mut arguments = HashMap::new();
    let args = args.trim_start_matches('(').trim_end_matches(')');

    for arg in args.split(',') {
        let parts: Vec<&str> = arg.split(':').map(|s| s.trim()).collect();
        if parts.len() == 2 {
            let key = parts[0].to_string();
            let value = parts[1].trim_matches('"').to_string();
            arguments.insert(key, value);
        }
    }

    arguments
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_parse_arguments_kv_single_argument() {
        let args = "(namespace: \"sn\")";
        let result = parse_arguments_kv(args);
        let mut expected = HashMap::new();
        expected.insert("namespace".to_string(), "sn".to_string());
        assert_eq!(result, expected);
    }

    #[test]
    fn test_parse_arguments_kv_multiple_arguments() {
        let args = "(namespace: \"sn\", version: \"1.0\")";
        let result = parse_arguments_kv(args);
        let mut expected = HashMap::new();
        expected.insert("namespace".to_string(), "sn".to_string());
        expected.insert("version".to_string(), "1.0".to_string());
        assert_eq!(result, expected);
    }

    #[test]
    fn test_parse_arguments_kv_no_arguments() {
        let args = "()";
        let result = parse_arguments_kv(args);
        let expected: HashMap<String, String> = HashMap::new();
        assert_eq!(result, expected);
    }

    #[test]
    fn test_parse_arguments_kv_trailing_comma() {
        let args = "(namespace: \"sn\",)";
        let result = parse_arguments_kv(args);
        let mut expected = HashMap::new();
        expected.insert("namespace".to_string(), "sn".to_string());
        assert_eq!(result, expected);
    }

    #[test]
    fn test_parse_arguments_kv_whitespace() {
        let args = "(  namespace  :  \"sn\"  ,  version  :  \"1.0\"  )";
        let result = parse_arguments_kv(args);
        let mut expected = HashMap::new();
        expected.insert("namespace".to_string(), "sn".to_string());
        expected.insert("version".to_string(), "1.0".to_string());
        assert_eq!(result, expected);
    }
}
