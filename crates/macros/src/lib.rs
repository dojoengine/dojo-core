
pub mod attributes;
pub mod derives;
pub mod syntax;
pub mod aux_data;
pub mod token_stream_ext;
pub mod diagnostic_ext;

/// Prints the given string only if the `DOJO_EXPAND` environemnt variable is set.
/// This is useful for debugging the compiler with verbose output.
///
/// # Arguments
///
/// * `loc` - The location of the code to be expanded.
/// * `code` - The code to be expanded.
pub fn debug_expand(loc: &str, code: &str) {
    if std::env::var("DOJO_EXPAND").is_ok() {
        println!(
            "\n// *> EXPAND {} <*\n{}\n\n",
            loc, code
        );
    }
}
