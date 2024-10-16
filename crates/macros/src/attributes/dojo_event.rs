//! A custom implementation of the starknet::Event derivation path.
//!
//! We append the event selector directly within the append_keys_and_data function.
//! Without the need of the enum for all event variants.
//!
//! <https://github.com/starkware-libs/cairo/blob/main/crates/cairo-lang-starknet/src/plugin/derive/event.rs>

use cairo_lang_macro::{
    attribute_macro, AuxData, Diagnostic, Diagnostics, ProcMacroResult, TokenStream,
};
use cairo_lang_parser::utils::SimpleParserDatabase;
use cairo_lang_syntax::node::db::SyntaxGroup;
use cairo_lang_syntax::node::helpers::QueryAttrs;
use cairo_lang_syntax::node::kind::SyntaxKind::ItemStruct;
use cairo_lang_syntax::node::{ast, TypedSyntaxNode};
use convert_case::{Case, Casing};

use std::collections::HashMap;

use dojo_types::naming;

use crate::attributes::struct_parser::remove_derives;
use crate::aux_data::ModelAuxData;
use crate::derives::{extract_derive_attr_names, DOJO_INTROSPECT_DERIVE, DOJO_PACKED_DERIVE};
use crate::diagnostic_ext::DiagnosticsExt;
use crate::syntax::utils::parse_arguments_kv;
use crate::token_stream_ext::{TokenStreamExt, TokenStreamsExt};

use super::patches::EVENT_PATCH;
use super::struct_parser::{
    parse_members, serialize_keys_and_values,
    validate_namings_diagnostics,
};

const DOJO_EVENT_ATTR: &str = "dojo_event";
const EVENT_NAMESPACE: &str = "namespace";
const DEFAULT_VERSION: u64 = 0;
pub const PARAMETER_HISTORICAL: &str = "historical";
pub const DEFAULT_HISTORICAL_VALUE: bool = true;

/// `#[dojo_event(...)]` attribute macro.
#[attribute_macro]
pub fn dojo_event(args: TokenStream, token_stream: TokenStream) -> ProcMacroResult {
    // Arguments of the macro are already parsed. Hence, we can't use the query_attr since the
    // attribute that triggered the macro execution is not available in the syntax node.
    let parsed_args = parse_arguments_kv(&args.to_string());

    let event_namespace = if let Some(event_namespace) = parsed_args.get(EVENT_NAMESPACE) {
        event_namespace.to_string()
    } else {
        return ProcMacroResult::new(TokenStream::empty())
            .with_diagnostics(Diagnostics::new(vec![Diagnostic::error(
                format!("{DOJO_EVENT_ATTR} attribute requires a '{EVENT_NAMESPACE}' argument. Use `#[{DOJO_EVENT_ATTR}({EVENT_NAMESPACE}: \"<namespace>\")]` to specify the namespace.",
                ))]));
    };

    let event_version = if let Some(event_version) = parsed_args.get("version") {
        if let Ok(version) = event_version.parse::<u64>() {
            version
        } else {
            return ProcMacroResult::new(TokenStream::empty()).with_diagnostics(Diagnostics::new(
                vec![Diagnostic::error(format!(
                    "Invalid event version: {event_version}. Expected a number (u64)."
                ))],
            ));
        }
    } else {
        DEFAULT_VERSION
    };

    let event_historical = if let Some(event_historical) = parsed_args.get("historical") {
        if let Ok(historical) = event_historical.parse::<bool>() {
            historical
        } else {
            return ProcMacroResult::new(TokenStream::empty()).with_diagnostics(Diagnostics::new(
                vec![Diagnostic::error(format!(
                    "Invalid event historical: {event_historical}. Expected a boolean."
                ))],
            ));
        }
    } else {
        DEFAULT_HISTORICAL_VALUE
    };

    let db = SimpleParserDatabase::default();
    let (syn_file, _diagnostics) = db.parse_virtual_with_diagnostics(token_stream);

    for n in syn_file.descendants(&db) {
        if n.kind(&db) == ItemStruct {
            let struct_ast = ast::ItemStruct::from_syntax_node(&db, n);

            match DojoEvent::from_struct(&event_namespace, event_version, event_historical, &db, &struct_ast) {
                Some(c) => {
                    return ProcMacroResult::new(c.token_stream)
                        .with_diagnostics(Diagnostics::new(c.diagnostics))
                        .with_aux_data(AuxData::new(
                            serde_json::to_vec(&ModelAuxData {
                                name: c.name.to_string(),
                                namespace: c.namespace.to_string(),
                                members: vec![],
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
pub struct DojoEvent {
    pub name: String,
    pub namespace: String,
    pub diagnostics: Vec<Diagnostic>,
    pub token_stream: TokenStream,
}

impl DojoEvent {
    pub fn from_struct(
        event_namespace: &str,
        event_version: u64,
        event_historical: bool,
        db: &dyn SyntaxGroup,
        struct_ast: &ast::ItemStruct,
    ) -> Option<DojoEvent> {
        let mut event = DojoEvent {
            diagnostics: vec![],
            token_stream: TokenStream::empty(),
            name: String::new(),
            namespace: String::new(),
        };

        let event_name = struct_ast
            .name(db)
            .as_syntax_node()
            .get_text(db)
            .trim()
            .to_string();

        event.diagnostics.extend(validate_namings_diagnostics(&[
            ("event namespace", &event_namespace),
            ("event name", &event_name),
        ]));

        let event_tag = naming::get_tag(&event_namespace, &event_name);
        let event_name_hash = naming::compute_bytearray_hash(&event_name);
        let event_namespace_hash = naming::compute_bytearray_hash(&event_namespace);
        let event_selector =
            naming::compute_selector_from_hashes(event_namespace_hash, event_name_hash);

        let members = parse_members(
            db,
            &struct_ast.members(db).elements(db),
            &mut event.diagnostics,
        );

        let mut serialized_keys: Vec<TokenStream> = vec![];
        let mut serialized_values: Vec<TokenStream> = vec![];

        serialize_keys_and_values(&members, &mut serialized_keys, &mut serialized_values);

        if serialized_keys.is_empty() {
            event
                .diagnostics
                .push_error("Event must define at least one #[key] attribute".to_string());
        }

        if serialized_values.is_empty() {
            event
                .diagnostics
                .push_error("Event must define at least one member that is not a key".to_string());
        }

        let derive_attr_names = extract_derive_attr_names(
            db,
            &mut event.diagnostics,
            struct_ast.attributes(db).query_attr(db, "derive"),
        );

        let has_introspect = derive_attr_names.contains(&DOJO_INTROSPECT_DERIVE.to_string());
        let has_introspect_packed = derive_attr_names.contains(&DOJO_PACKED_DERIVE.to_string());
        let has_drop = derive_attr_names.contains(&"Drop".to_string());
        let has_serde = derive_attr_names.contains(&"Serde".to_string());

        if has_introspect && has_introspect_packed {
            event.diagnostics.push_error(
                "Event cannot derive from both Introspect and IntrospectPacked. Only Introspect is allowed.".to_string(),
            );
        }

        if !has_introspect && !has_drop && !has_serde {
            event.diagnostics.push_error(
                "Event must derive from Introspect, Drop and Serde.".to_string(),
            );
        }

        let derive_node = if has_introspect {
            TokenStream::new(format!("#[derive({})]", DOJO_INTROSPECT_DERIVE))
        } else {
            TokenStream::empty()
        };

        // Must remove the derives from the original struct since they would create duplicates
        // with the derives of other plugins.
        let original_struct = remove_derives(db, &struct_ast);

        let node = TokenStream::interpolate_patched(
            EVENT_PATCH,
            &HashMap::from([
                (
                    "contract_name".to_string(),
                    event_name.to_case(Case::Snake),
                ),
                (
                    "type_name".to_string(),
                    event_name.clone(),
                ),
                (
                    "serialized_keys".to_string(),
                    serialized_keys.join_to_token_stream("").to_string(),
                ),
                (
                    "serialized_values".to_string(),
                    serialized_values.join_to_token_stream("").to_string(),
                ),
                ("event_tag".to_string(), event_tag),
                (
                    "event_version".to_string(),
                    event_version.to_string(),
                ),
                (
                    "event_historical".to_string(),
                    event_historical.to_string(),
                ),
                (
                    "event_selector".to_string(),
                    event_selector.to_string(),
                ),
                (
                    "event_namespace".to_string(),
                    event_namespace.to_string(),
                ),
                (
                    "event_name_hash".to_string(),
                    event_name_hash.to_string(),
                ),
                (
                    "event_namespace_hash".to_string(),
                    event_namespace_hash.to_string(),
                ),
            ]),
        );

        event.name = event_name.clone();
        event.namespace = event_namespace.to_string();
        event.token_stream = vec![derive_node, original_struct, node].join_to_token_stream("");

        crate::debug_expand(
            &format!("EVENT PATCH: {event_namespace}-{event_name}"),
            &event.token_stream.to_string(),
        );

        Some(event)
    }
}
