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
use dojo_types::naming;
use smol_str::SmolStr;
use tracing::trace;

use super::compiler::manifest::Member;
use crate::CAIRO_PATH_SEPARATOR;

pub trait AuxDataTrait {
    fn name(&self) -> String;
    fn namespace(&self) -> String;
    fn tag(&self) -> String;
}

pub trait AuxDataProcessor: std::fmt::Debug {
    const ELEMENT_NAME: &'static str;

    fn contract_path(&self, module_path: &String) -> String;

    fn insert(&self, dojo_aux_data: &mut DojoAuxData, module_path: &String);

    fn process(&self, dojo_aux_data: &mut DojoAuxData, module_path: &String) {
        trace!(
            contract_path = self.contract_path(&module_path),
            ?self,
            "Adding dojo {} to aux data.",
            Self::ELEMENT_NAME
        );

        self.insert(dojo_aux_data, module_path);
    }
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

impl AuxDataTrait for ModelAuxData {
    fn name(&self) -> String {
        self.name.clone()
    }
    fn namespace(&self) -> String {
        self.namespace.clone()
    }
    fn tag(&self) -> String {
        naming::get_tag(&self.namespace, &self.name)
    }
}

impl AuxDataProcessor for ModelAuxData {
    const ELEMENT_NAME: &'static str = "model";

    fn insert(&self, dojo_aux_data: &mut DojoAuxData, module_path: &String) {
        dojo_aux_data
            .models
            .insert(self.contract_path(module_path), self.clone());
    }

    // As models are defined from a struct (usually Pascal case), we have converted
    // the underlying starknet contract name to snake case in the `#[dojo::model]` attribute
    // macro processing.
    // Same thing as for contracts, we need to add the model name to the module path
    // to get the fully qualified path of the contract.
    fn contract_path(&self, module_path: &String) -> String {
        format!(
            "{}{}{}",
            module_path,
            CAIRO_PATH_SEPARATOR,
            self.name.to_case(Case::Snake)
        )
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

impl AuxDataTrait for EventAuxData {
    fn name(&self) -> String {
        self.name.clone()
    }
    fn namespace(&self) -> String {
        self.namespace.clone()
    }
    fn tag(&self) -> String {
        naming::get_tag(&self.namespace, &self.name)
    }
}

impl AuxDataProcessor for EventAuxData {
    const ELEMENT_NAME: &'static str = "event";

    fn insert(&self, dojo_aux_data: &mut DojoAuxData, module_path: &String) {
        dojo_aux_data
            .events
            .insert(self.contract_path(module_path), self.clone());
    }

    // As events are defined from a struct (usually Pascal case), we have converted
    // the underlying starknet contract name to snake case in the `#[dojo::event]` attribute
    // macro processing.
    // Same thing as for contracts, we need to add the event name to the module path
    // to get the fully qualified path of the contract.
    fn contract_path(&self, module_path: &String) -> String {
        format!(
            "{}{}{}",
            module_path,
            CAIRO_PATH_SEPARATOR,
            self.name.to_case(Case::Snake)
        )
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

impl AuxDataTrait for ContractAuxData {
    fn name(&self) -> String {
        self.name.to_string()
    }
    fn namespace(&self) -> String {
        self.namespace.clone()
    }
    fn tag(&self) -> String {
        naming::get_tag(&self.namespace, &self.name)
    }
}

impl AuxDataProcessor for ContractAuxData {
    const ELEMENT_NAME: &'static str = "contract";

    fn insert(&self, dojo_aux_data: &mut DojoAuxData, module_path: &String) {
        dojo_aux_data
            .contracts
            .insert(self.contract_path(module_path), self.clone());
    }

    // The module path for contracts is the path to the contract file, not the fully
    // qualified path of the actual contract module.
    // Adding the contract name to the module path allows to get the fully qualified path
    fn contract_path(&self, module_path: &String) -> String {
        format!("{}{}{}", module_path, CAIRO_PATH_SEPARATOR, self.name)
    }
}

impl AuxDataProcessor for StarkNetContractAuxData {
    const ELEMENT_NAME: &'static str = "starknet contract";

    fn insert(&self, dojo_aux_data: &mut DojoAuxData, module_path: &String) {
        dojo_aux_data
            .sn_contracts
            .insert(module_path.clone(), self.contract_path(module_path));
    }

    fn contract_path(&self, _module_path: &String) -> String {
        self.contract_name.to_string()
    }

    // As every contracts and models are starknet contracts under the hood,
    // we need to filter already processed Starknet contracts.
    // Also important to note that, the module id for a starknet contract is
    // already the fully qualified path of the contract.
    //
    // Important to note that all the dojo-core contracts are starknet contracts
    // (currently world, base and resource_metadata model). They will be added here
    // but we may choose to ignore them.
    fn process(&self, dojo_aux_data: &mut DojoAuxData, module_path: &String)
    where
        Self: Sized,
    {
        if !dojo_aux_data.contains_starknet_contract(&module_path) {
            trace!(
                %module_path,
                contract_name = self.contract_path(module_path),
                "Adding {} to aux data.",
                Self::ELEMENT_NAME
            );

            self.insert(dojo_aux_data, module_path);
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
        self.contracts.contains_key(qualified_path)
            || self.models.contains_key(qualified_path)
            || self.events.contains_key(qualified_path)
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

                    if let Some(aux_data) = aux_data.downcast_ref::<ContractAuxData>() {
                        aux_data.process(&mut dojo_aux_data, &module_path);
                        continue;
                    }

                    if let Some(aux_data) = aux_data.downcast_ref::<ModelAuxData>() {
                        aux_data.process(&mut dojo_aux_data, &module_path);
                        continue;
                    }

                    if let Some(aux_data) = aux_data.downcast_ref::<EventAuxData>() {
                        aux_data.process(&mut dojo_aux_data, &module_path);
                        continue;
                    }

                    if let Some(aux_data) = aux_data.downcast_ref::<StarkNetContractAuxData>() {
                        aux_data.process(&mut dojo_aux_data, &module_path);
                    }
                }
            }
        }

        dojo_aux_data
    }
}
