//! Auxiliary data for Dojo generated files.
//!
//! The plugin generates aux data for models, contracts and events.
//! Then the compiler uses this aux data to generate the manifests and organize the artifacts.

use std::cmp::Ordering;

use anyhow::Result;
use cairo_lang_compiler::db::RootDatabase;
use cairo_lang_defs::patcher::PatchBuilder;
use cairo_lang_defs::plugin::{
    DynGeneratedFileAuxData, GeneratedFileAuxData, MacroPlugin, MacroPluginMetadata,
    PluginDiagnostic, PluginGeneratedFile, PluginResult,
};
use cairo_lang_diagnostics::Severity;
use cairo_lang_filesystem::ids::CrateId;
use cairo_lang_semantic::plugin::PluginSuite;
use cairo_lang_starknet::plugin::aux_data::{StarkNetContractAuxData, StarkNetEventAuxData};
use cairo_lang_syntax::attribute::structured::{AttributeArgVariant, AttributeStructurize};
use cairo_lang_syntax::node::ast::Attribute;
use cairo_lang_syntax::node::db::SyntaxGroup;
use cairo_lang_syntax::node::helpers::QueryAttrs;
use cairo_lang_syntax::node::ids::SyntaxStablePtrId;
use cairo_lang_syntax::node::{ast, Terminal, TypedSyntaxNode};

use cairo_lang_defs::db::DefsGroup;
use cairo_lang_defs::ids::{
    ModuleId, ModuleItemId, NamedLanguageElementId, TopLevelLanguageElementId,
};
use cairo_lang_filesystem::db::FilesGroup;
use cairo_lang_formatter::format_string;
use cairo_lang_semantic::db::SemanticGroup;
use cairo_lang_starknet::compile::compile_prepared_db;
use cairo_lang_starknet::contract::{find_contracts, ContractDeclaration};
use cairo_lang_starknet_classes::abi;
use cairo_lang_starknet_classes::allowed_libfuncs::{AllowedLibfuncsError, ListSelector};
use cairo_lang_starknet_classes::contract_class::ContractClass;
use cairo_lang_utils::UpcastMut;

use scarb::compiler::plugin::builtin::BuiltinStarkNetPlugin;
use scarb::compiler::plugin::{CairoPlugin, CairoPluginInstance};
use scarb::core::{PackageId, PackageName, SourceId};
use semver::Version;
use smol_str::SmolStr;
use url::Url;

/// Represents a member of a struct.
#[derive(Clone, Debug, PartialEq)]
pub struct Member {
    // Name of the member.
    pub name: String,
    // Type of the member.
    // #[serde(rename = "type")]
    pub ty: String,
    // Whether the member is a key.
    pub key: bool,
}

#[derive(Clone, Debug, PartialEq)]
pub struct ModelAuxData {
    pub name: String,
    pub namespace: String,
    pub members: Vec<Member>,
}

impl GeneratedFileAuxData for ModelAuxData {
    fn as_any(&self) -> &dyn std::any::Any {
        self
    }

    fn eq(&self, other: &dyn GeneratedFileAuxData) -> bool {
        if let Some(other) = other.as_any().downcast_ref::<Self>() {
            self == other
        } else {
            false
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ContractAuxData {
    pub name: SmolStr,
    pub namespace: String,
    pub systems: Vec<String>,
}

impl GeneratedFileAuxData for ContractAuxData {
    fn as_any(&self) -> &dyn std::any::Any {
        self
    }

    fn eq(&self, other: &dyn GeneratedFileAuxData) -> bool {
        if let Some(other) = other.as_any().downcast_ref::<Self>() {
            self == other
        } else {
            false
        }
    }
}

/// Dojo related auxiliary data of the Dojo plugin.
#[derive(Debug, Default, PartialEq)]
pub struct DojoAuxData {
    /// A list of models that were processed by the plugin.
    pub models: Vec<ModelAuxData>,
    /// A list of contracts that were processed by the plugin.
    pub contracts: Vec<ContractAuxData>,
}

impl DojoAuxData {
    pub fn from_crates(crate_ids: &[CrateId], db: &RootDatabase) -> Self {
        let mut dojo_aux_data = DojoAuxData::default();

        for crate_id in crate_ids {
            for module_id in db.crate_modules(*crate_id).as_ref() {
                let file_infos = db
                    .module_generated_file_infos(*module_id)
                    .unwrap_or(std::sync::Arc::new([]));

                // Skip(1) to avoid internal aux data of Starknet aux data.
                for aux_data in file_infos
                    .iter()
                    .skip(1)
                    .filter_map(|info| info.as_ref().map(|i| &i.aux_data))
                    .filter_map(|aux_data| aux_data.as_ref().map(|aux_data| aux_data.0.as_any()))
                {
                    if let Some(model_aux_data) = aux_data.downcast_ref::<ModelAuxData>() {
                        dojo_aux_data.models.push(model_aux_data.clone());
                    }

                    if let Some(contract_aux_data) = aux_data.downcast_ref::<ContractAuxData>() {
                        dojo_aux_data.contracts.push(contract_aux_data.clone());
                    }

                    if let Some(sn_contract_aux_data) =
                        aux_data.downcast_ref::<StarkNetContractAuxData>()
                    {
                        println!(
                            "starknet_contract_aux_data: {:?} {:?}",
                            module_id.full_path(db),
                            sn_contract_aux_data
                        );
                    }

                    // StarknetAuxData shouldn't be required. Every dojo contract and model are starknet
                    // contracts under the hood. But the dojo aux data are attached to
                    // the parent module of the actual contract, so StarknetAuxData will
                    // only contain the contract's name.
                }
            }
        }

        dojo_aux_data
    }
}
