//! Dojo plugin for Cairo.

use anyhow::Result;
use cairo_lang_defs::patcher::PatchBuilder;
use cairo_lang_defs::plugin::{
    DynGeneratedFileAuxData, MacroPlugin, MacroPluginMetadata, PluginDiagnostic,
    PluginGeneratedFile, PluginResult,
};
use cairo_lang_diagnostics::Severity;
use cairo_lang_semantic::plugin::PluginSuite;
use cairo_lang_syntax::node::db::SyntaxGroup;
use cairo_lang_syntax::node::helpers::QueryAttrs;
use cairo_lang_syntax::node::{ast, Terminal, TypedSyntaxNode};
use scarb::compiler::plugin::builtin::BuiltinStarkNetPlugin;
use scarb::compiler::plugin::{CairoPlugin, CairoPluginInstance};
use scarb::core::{PackageId, PackageName, SourceId};
use semver::Version;
use url::Url;

use super::attribute_macros::{
    DojoContract, DojoEvent, DojoInterface, DojoModel, DOJO_CONTRACT_ATTR, DOJO_EVENT_ATTR,
    DOJO_INTERFACE_ATTR, DOJO_MODEL_ATTR,
};
use super::derive_macros::{
    extract_derive_attr_names, handle_derive_attrs, DOJO_INTROSPECT_DERIVE, DOJO_PACKED_DERIVE,
};
use super::inline_macros::{
    DeleteMacro, EmitMacro, GetMacro, GetModelsTestClassHashes, SelectorFromTagMacro, SetMacro,
    SpawnTestWorld,
};

use crate::aux_data::DojoAuxData;

#[cfg(test)]
#[path = "plugin_test.rs"]
mod test;

pub const PACKAGE_NAME: &str = "dojo_plugin";

#[derive(Debug, Default)]
pub struct BuiltinDojoPlugin;

impl CairoPlugin for BuiltinDojoPlugin {
    fn id(&self) -> PackageId {
        let url = Url::parse("https://github.com/dojoengine/dojo-core").unwrap();
        let version = env!("CARGO_PKG_VERSION");

        let source_id = SourceId::for_git(&url, &scarb::core::GitReference::DefaultBranch).unwrap();

        PackageId::new(
            PackageName::new(PACKAGE_NAME),
            Version::parse(version).unwrap(),
            source_id,
        )
    }

    fn instantiate(&self) -> Result<Box<dyn CairoPluginInstance>> {
        Ok(Box::new(BuiltinDojoPluginInstance))
    }
}

struct BuiltinDojoPluginInstance;
impl CairoPluginInstance for BuiltinDojoPluginInstance {
    fn plugin_suite(&self) -> PluginSuite {
        dojo_plugin_suite()
    }
}

pub fn dojo_plugin_suite() -> PluginSuite {
    let mut suite = PluginSuite::default();

    suite
        .add_plugin::<BuiltinDojoPlugin>()
        .add_inline_macro_plugin::<DeleteMacro>()
        .add_inline_macro_plugin::<GetMacro>()
        .add_inline_macro_plugin::<SetMacro>()
        .add_inline_macro_plugin::<EmitMacro>()
        .add_inline_macro_plugin::<SelectorFromTagMacro>()
        .add_inline_macro_plugin::<GetModelsTestClassHashes>()
        .add_inline_macro_plugin::<SpawnTestWorld>();

    suite
}

impl MacroPlugin for BuiltinDojoPlugin {
    /// This function is called for every item in whole db. Hence,
    /// the sooner we can return, the better.
    /// As an example, compiling spawn-and-move project, it's almost 14K calls to this
    /// function.
    ///
    /// Currently Dojo mainly supports:
    /// - Contracts: which are built from attribute macros on a module.
    /// - Interfaces: which are built from attribute macros on a trait.
    /// - Models: which are built from attribute macros on a struct.
    /// - Events: which are built from attribute macros on a struct.
    /// - Enums: mostly used for deriving introspect to be used into a model or event.
    fn generate_code(
        &self,
        db: &dyn SyntaxGroup,
        item_ast: ast::ModuleItem,
        metadata: &MacroPluginMetadata<'_>,
    ) -> PluginResult {
        // Metadata gives information from the crates from where `item_ast` was parsed.
        // During the compilation phase, we inject namespace information into the `CfgSet`
        // so that it can be used here.
        let namespace_config = metadata.cfg_set.into();

        match &item_ast {
            ast::ModuleItem::Module(module_ast) => {
                if module_ast.has_attr(db, DOJO_CONTRACT_ATTR) {
                    DojoContract::from_module(db, module_ast, &namespace_config, metadata)
                } else {
                    PluginResult::default()
                }
            }
            ast::ModuleItem::Trait(trait_ast) => {
                if trait_ast.has_attr(db, DOJO_INTERFACE_ATTR) {
                    DojoInterface::from_trait(db, trait_ast, metadata)
                } else {
                    PluginResult::default()
                }
            }
            ast::ModuleItem::Enum(enum_ast) => {
                let mut diagnostics = vec![];

                let derive_attr_names = extract_derive_attr_names(
                    db,
                    &mut diagnostics,
                    enum_ast.attributes(db).query_attr(db, "derive"),
                );

                let (rewrite_nodes, derive_diagnostics) =
                    handle_derive_attrs(db, &derive_attr_names, &item_ast);

                diagnostics.extend(derive_diagnostics);

                if rewrite_nodes.is_empty() {
                    return PluginResult {
                        diagnostics,
                        ..PluginResult::default()
                    };
                }

                let name = enum_ast.name(db).text(db);
                let mut builder = PatchBuilder::new(db, enum_ast);
                for node in rewrite_nodes {
                    builder.add_modified(node);
                }

                let (code, code_mappings) = builder.build();

                PluginResult {
                    code: Some(PluginGeneratedFile {
                        name,
                        content: code,
                        aux_data: None,
                        code_mappings,
                    }),
                    diagnostics,
                    remove_original_item: false,
                }
            }
            ast::ModuleItem::Struct(struct_ast) => {
                let mut aux_data = DojoAuxData::default();
                let mut diagnostics = vec![];

                let mut derive_attr_names = extract_derive_attr_names(
                    db,
                    &mut diagnostics,
                    struct_ast.attributes(db).query_attr(db, "derive"),
                );

                let is_model = struct_ast.has_attr(db, DOJO_MODEL_ATTR);
                let is_event = struct_ast.has_attr(db, DOJO_EVENT_ATTR);

                // Ensures models and events always derive Introspect if not already derived.
                if is_model || is_event {
                    if !derive_attr_names.contains(&DOJO_INTROSPECT_DERIVE.to_string())
                        && !derive_attr_names.contains(&DOJO_PACKED_DERIVE.to_string())
                    {
                        derive_attr_names.push(DOJO_INTROSPECT_DERIVE.to_string());
                    }
                }

                let (mut rewrite_nodes, derive_diagnostics) =
                    handle_derive_attrs(db, &derive_attr_names, &item_ast);

                diagnostics.extend(derive_diagnostics);

                let n_model_attrs = struct_ast
                    .attributes(db)
                    .query_attr(db, DOJO_MODEL_ATTR)
                    .len();
                let n_event_attrs = struct_ast
                    .attributes(db)
                    .query_attr(db, DOJO_EVENT_ATTR)
                    .len();

                // TODO: when event will be separated from model, we need to check for conflicts.
                // The same struct can't be used for both `#[dojo::model]` and `#[dojo::event]`.
                //
                // Events will be reworked to be similar to models, and emitted via a World's event
                // instead of using the syscall.
                //
                // `#[dojo::event]` for now does nothing.

                if is_model {
                    if n_model_attrs == 1 {
                        let (model_rewrite_nodes, model_diagnostics) = DojoModel::from_struct(
                            db,
                            &mut aux_data,
                            struct_ast.clone(),
                            &namespace_config,
                        );
                        rewrite_nodes.push(model_rewrite_nodes);
                        diagnostics.extend(model_diagnostics);
                    } else {
                        diagnostics.push(PluginDiagnostic {
                            message: "A Dojo model must have one dojo::model attribute.".into(),
                            stable_ptr: struct_ast.stable_ptr().0,
                            severity: Severity::Error,
                        });
                    }
                }

                if rewrite_nodes.is_empty() {
                    return PluginResult {
                        diagnostics,
                        ..PluginResult::default()
                    };
                }

                let name = struct_ast.name(db).text(db);
                let mut builder = PatchBuilder::new(db, struct_ast);
                for node in rewrite_nodes {
                    builder.add_modified(node);
                }

                let (code, code_mappings) = builder.build();

                PluginResult {
                    code: Some(PluginGeneratedFile {
                        name,
                        content: code,
                        aux_data: Some(DynGeneratedFileAuxData::new(aux_data)),
                        code_mappings,
                    }),
                    diagnostics,
                    remove_original_item: false,
                }
            }
            _ => PluginResult::default(),
        }
    }

    fn declared_attributes(&self) -> Vec<String> {
        vec![
            DOJO_INTERFACE_ATTR.to_string(),
            DOJO_CONTRACT_ATTR.to_string(),
            DOJO_EVENT_ATTR.to_string(),
            DOJO_MODEL_ATTR.to_string(),
            "key".to_string(),
        ]
    }

    fn declared_derives(&self) -> Vec<String> {
        vec![
            DOJO_INTROSPECT_DERIVE.to_string(),
            DOJO_PACKED_DERIVE.to_string(),
        ]
    }
}

#[derive(Debug)]
pub struct CairoPluginRepository(scarb::compiler::plugin::CairoPluginRepository);

impl Default for CairoPluginRepository {
    fn default() -> Self {
        let mut repo = scarb::compiler::plugin::CairoPluginRepository::empty();
        repo.add(Box::new(BuiltinDojoPlugin)).unwrap();
        repo.add(Box::new(BuiltinStarkNetPlugin)).unwrap();
        Self(repo)
    }
}

impl From<CairoPluginRepository> for scarb::compiler::plugin::CairoPluginRepository {
    fn from(val: CairoPluginRepository) -> Self {
        val.0
    }
}
