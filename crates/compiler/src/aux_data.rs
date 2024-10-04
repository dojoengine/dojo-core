//! Auxiliary data for Dojo generated files.
//!
//! The plugin generates aux data for models, contracts and events.
//! Then the compiler uses this aux data to generate the manifests and organize the artifacts.

use std::collections::HashMap;

use cairo_lang_compiler::db::RootDatabase;
use cairo_lang_defs::db::DefsGroup;
use cairo_lang_defs::plugin::GeneratedFileAuxData;
use cairo_lang_filesystem::ids::CrateId;
use cairo_lang_starknet::plugin::aux_data::StarkNetContractAuxData;
use convert_case::{Case, Casing};
use smol_str::SmolStr;
use tracing::trace;

use super::compiler::manifest::Member;
use crate::CAIRO_PATH_SEPARATOR;

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

#[derive(Clone, Debug, PartialEq)]
pub struct EventAuxData {
    pub name: String,
    pub namespace: String,
    pub members: Vec<Member>,
}

impl GeneratedFileAuxData for EventAuxData {
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
///
/// All the keys are full paths to the cairo module that contains the expanded code.
/// This eases the match with compiled artifacts that are using the fully qualified path
/// as keys.
#[derive(Debug, Default, PartialEq)]
pub struct DojoAuxData {
    /// A list of events that were processed by the plugin.
    pub events: HashMap<String, EventAuxData>,
    /// A list of models that were processed by the plugin.
    pub models: HashMap<String, ModelAuxData>,
    /// A list of contracts that were processed by the plugin.
    pub contracts: HashMap<String, ContractAuxData>,
    /// A list of starknet contracts that were processed by the plugin (qualified path, contract name).
    pub sn_contracts: HashMap<String, String>,
}

impl DojoAuxData {
    /// Checks if a starknet contract with the given qualified path has been processed
    /// for a contract or a model.
    pub fn contains_starknet_contract(&self, qualified_path: &str) -> bool {
        self.contracts.contains_key(qualified_path) || self.models.contains_key(qualified_path)
    }

    /// Creates a new `DojoAuxData` from a list of crate ids and a database by introspecting
    /// the generated files of each module in the database.
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
                    let module_path = module_id.full_path(db);

                    if let Some(contract_aux_data) = aux_data.downcast_ref::<ContractAuxData>() {
                        // The module path for contracts is the path to the contract file, not the fully
                        // qualified path of the actual contract module.
                        // Adding the contract name to the module path allows to get the fully qualified path.
                        let contract_path = format!(
                            "{}{}{}",
                            module_path, CAIRO_PATH_SEPARATOR, contract_aux_data.name
                        );

                        trace!(
                            contract_path,
                            ?contract_aux_data,
                            "Adding dojo contract to aux data."
                        );

                        dojo_aux_data
                            .contracts
                            .insert(contract_path, contract_aux_data.clone());
                    }

                    if let Some(model_aux_data) = aux_data.downcast_ref::<ModelAuxData>() {
                        // As models are defined from a struct (usually Pascal case), we have converted
                        // the underlying starknet contract name to snake case in the `#[dojo::model]` attribute
                        // macro processing.
                        // Same thing as for contracts, we need to add the model name to the module path
                        // to get the fully qualified path of the contract.
                        let model_contract_path = format!(
                            "{}{}{}",
                            module_path,
                            CAIRO_PATH_SEPARATOR,
                            model_aux_data.name.to_case(Case::Snake)
                        );

                        trace!(
                            model_contract_path,
                            ?model_aux_data,
                            "Adding dojo model to aux data."
                        );

                        dojo_aux_data
                            .models
                            .insert(model_contract_path, model_aux_data.clone());
                        continue;
                    }

                    if let Some(event_aux_data) = aux_data.downcast_ref::<EventAuxData>() {
                        // As events are defined from a struct (usually Pascal case), we have converted
                        // the underlying starknet contract name to snake case in the `#[dojo::event]` attribute
                        // macro processing.
                        // Same thing as for contracts, we need to add the event name to the module path
                        // to get the fully qualified path of the contract.
                        let event_contract_path = format!(
                            "{}{}{}",
                            module_path,
                            CAIRO_PATH_SEPARATOR,
                            event_aux_data.name.to_case(Case::Snake)
                        );

                        trace!(
                            event_contract_path,
                            ?event_aux_data,
                            "Adding dojo event to aux data."
                        );

                        dojo_aux_data
                            .events
                            .insert(event_contract_path, event_aux_data.clone());
                        continue;
                    }

                    // As every contracts and models are starknet contracts under the hood,
                    // we need to filter already processed Starknet contracts.
                    // Also important to note that, the module id for a starknet contract is
                    // already the fully qualified path of the contract.
                    //
                    // Important to note that all the dojo-core contracts are starknet contracts
                    // (currently world, base and resource_metadata model). They will be added here
                    // but we may choose to ignore them.
                    if let Some(sn_contract_aux_data) =
                        aux_data.downcast_ref::<StarkNetContractAuxData>()
                    {
                        if !dojo_aux_data.contains_starknet_contract(&module_path) {
                            dojo_aux_data.sn_contracts.insert(
                                module_path.clone(),
                                sn_contract_aux_data.contract_name.to_string(),
                            );

                            trace!(
                                %module_path,
                                contract_name = %sn_contract_aux_data.contract_name,
                                "Adding starknet contract to aux data."
                            );
                        }
                    }
                }
            }
        }

        dojo_aux_data
    }
}
