use std::collections::HashMap;

use cairo_lang_macro::TokenStream;

pub trait TokenStreamExt {
    fn interpolate_patched(code: &str, patches: &HashMap<String, String>) -> TokenStream;
}

impl TokenStreamExt for TokenStream {
    /// Simplified implementation taken from `RewriteNode::interpolate_patches`.
    fn interpolate_patched(code: &str, patches: &HashMap<String, String>) -> TokenStream {
        let mut chars = code.chars().peekable();
        let mut pending_text = String::new();
        let mut children = Vec::new();
        while let Some(c) = chars.next() {
            if c != '$' {
                pending_text.push(c);
                continue;
            }

            // An opening $ was detected.

            // Read the name
            let mut name = String::new();
            for c in chars.by_ref() {
                if c == '$' {
                    break;
                }
                name.push(c);
            }

            // A closing $ was found.
            // If the string between the `$`s is empty - push a single `$` to the output.
            if name.is_empty() {
                pending_text.push('$');
                continue;
            }
            // If the string wasn't empty and there is some pending text, first flush it as a text
            // child.
            if !pending_text.is_empty() {
                children.push(pending_text.clone());
                pending_text.clear();
            }
            // Replace the substring with the relevant rewrite node.
            // Panic here as it's not expected to happen and the developer
            // must be notified.
            children.push(
                patches
                    .get(&name)
                    .expect(&format!(
                        "Patch with name `{}` not found while interpolating: {}",
                        name, code
                    ))
                    .clone(),
            );
        }
        // Flush the remaining text as a text child.
        if !pending_text.is_empty() {
            children.push(pending_text.clone());
        }

        TokenStream::new(children.join(""))
    }
}

pub trait TokenStreamsExt {
    fn join_to_token_stream(&self, separator: &str) -> TokenStream;
}

impl TokenStreamsExt for Vec<TokenStream> {
    fn join_to_token_stream(&self, separator: &str) -> TokenStream {
        let result: String = self
            .iter()
            .map(|ts| format!("{}", ts))
            .collect::<Vec<String>>()
            .join(separator);

        TokenStream::new(result)
    }
}

impl TokenStreamsExt for Vec<String> {
    fn join_to_token_stream(&self, separator: &str) -> TokenStream {
        TokenStream::new(self.join(separator))
    }
}
