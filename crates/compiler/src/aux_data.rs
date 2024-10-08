//! Auxiliary data for Dojo generated files.
//!
//! The plugin generates aux data for models, contracts and events.
//! Then the compiler uses this aux data to generate the manifests and organize the artifacts.

use anyhow::Result;
use cairo_lang_defs::plugin::GeneratedFileAuxData;
use cairo_lang_starknet::plugin::aux_data::StarkNetContractAuxData;
use convert_case::{Case, Casing};
use dojo_types::naming;
use smol_str::SmolStr;
use tracing::trace;

use super::compiler::annotation::Member;
use crate::{
    compiler::{
        annotation::{
            ContractAnnotation, EventAnnotation, ModelAnnotation, StarknetContractAnnotation,
        },
        artifact_manager::ArtifactManager,
    },
    CAIRO_PATH_SEPARATOR,
};

#[derive(Clone, Debug, PartialEq)]
pub struct ModelAuxData {
    pub name: String,
    pub namespace: String,
    pub members: Vec<Member>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ContractAuxData {
    pub name: SmolStr,
    pub namespace: String,
    pub systems: Vec<String>,
}

#[derive(Clone, Debug, PartialEq)]
pub struct EventAuxData {
    pub name: String,
    pub namespace: String,
    pub members: Vec<Member>,
}

pub trait AuxDataToAnnotation<T> {
    /// Returns the qualified path of the contract, since dependingo on the aux data type
    /// the qualified path is computed differently from the module path.
    ///
    /// # Arguments
    ///
    /// * `module_path` - The path to the module that generated the aux data.
    fn contract_qualified_path(&self, module_path: &String) -> String;

    /// Converts the aux data to the corresponding annotation.
    ///
    /// # Arguments
    ///
    /// * `artifact_manager` - The artifact manager to get the class from the artifact.
    /// * `module_path` - The path to the module that generated the aux data.
    fn to_annotation(&self, artifact_manager: &ArtifactManager, module_path: &String) -> Result<T>;
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

impl AuxDataToAnnotation<ModelAnnotation> for ModelAuxData {
    fn contract_qualified_path(&self, module_path: &String) -> String {
        // As models are defined from a struct (usually Pascal case), we have converted
        // the underlying starknet contract name to snake case in the `#[dojo::model]` attribute
        // macro processing.
        // Same thing as for contracts, we need to add the model name to the module path
        // to get the fully qualified path of the contract.
        format!(
            "{}{}{}",
            module_path,
            CAIRO_PATH_SEPARATOR,
            self.name.to_case(Case::Snake)
        )
    }

    fn to_annotation(
        &self,
        artifact_manager: &ArtifactManager,
        module_path: &String,
    ) -> Result<ModelAnnotation> {
        let contract_qualified_path = self.contract_qualified_path(&module_path);

        let artifact = artifact_manager
            .get_artifact(&contract_qualified_path)
            .ok_or(anyhow::anyhow!("Artifact not found"))?;

        let annotation = ModelAnnotation {
            qualified_path: contract_qualified_path.clone(),
            class_hash: artifact.class_hash,
            tag: naming::get_tag(&self.namespace, &self.name),
            members: self.members.clone(),
        };

        trace!(
            contract_path = contract_qualified_path,
            ?self,
            "Generating annotations for model {} ({}).",
            annotation.tag,
            annotation.qualified_path,
        );

        Ok(annotation)
    }
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

impl AuxDataToAnnotation<EventAnnotation> for EventAuxData {
    fn contract_qualified_path(&self, module_path: &String) -> String {
        // As events are defined from a struct (usually Pascal case), we have converted
        // the underlying starknet contract name to snake case in the `#[dojo::event]` attribute
        // macro processing.
        // Same thing as for contracts, we need to add the event name to the module path
        // to get the fully qualified path of the contract.
        format!(
            "{}{}{}",
            module_path,
            CAIRO_PATH_SEPARATOR,
            self.name.to_case(Case::Snake)
        )
    }

    fn to_annotation(
        &self,
        artifact_manager: &ArtifactManager,
        module_path: &String,
    ) -> Result<EventAnnotation> {
        let contract_qualified_path = self.contract_qualified_path(&module_path);

        let artifact = artifact_manager
            .get_artifact(&contract_qualified_path)
            .ok_or(anyhow::anyhow!("Artifact not found"))?;

        let annotation = EventAnnotation {
            qualified_path: contract_qualified_path.clone(),
            class_hash: artifact.class_hash,
            tag: naming::get_tag(&self.namespace, &self.name),
            members: self.members.clone(),
        };

        trace!(
            contract_path = contract_qualified_path,
            ?self,
            "Generating annotations for event {} ({}).",
            annotation.tag,
            annotation.qualified_path,
        );

        Ok(annotation)
    }
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

impl AuxDataToAnnotation<ContractAnnotation> for ContractAuxData {
    fn contract_qualified_path(&self, module_path: &String) -> String {
        // The module path for contracts is the path to the contract file, not the fully
        // qualified path of the actual contract module.
        // Adding the contract name to the module path allows to get the fully qualified path
        format!("{}{}{}", module_path, CAIRO_PATH_SEPARATOR, self.name)
    }

    fn to_annotation(
        &self,
        artifact_manager: &ArtifactManager,
        module_path: &String,
    ) -> Result<ContractAnnotation> {
        let contract_qualified_path = self.contract_qualified_path(&module_path);

        let artifact = artifact_manager
            .get_artifact(&contract_qualified_path)
            .ok_or(anyhow::anyhow!("Artifact not found"))?;

        let annotation = ContractAnnotation {
            qualified_path: contract_qualified_path.clone(),
            class_hash: artifact.class_hash,
            tag: naming::get_tag(&self.namespace, &self.name),
            systems: self.systems.clone(),
        };

        trace!(
            contract_path = contract_qualified_path,
            ?self,
            "Generating annotations for dojo contract {} ({}).",
            annotation.tag,
            annotation.qualified_path,
        );

        Ok(annotation)
    }
}

impl AuxDataToAnnotation<StarknetContractAnnotation> for StarkNetContractAuxData {
    fn contract_qualified_path(&self, module_path: &String) -> String {
        // The qualified path for starknet contracts is the same as the module path.
        module_path.clone()
    }

    fn to_annotation(
        &self,
        artifact_manager: &ArtifactManager,
        module_path: &String,
    ) -> Result<StarknetContractAnnotation> {
        let contract_qualified_path = self.contract_qualified_path(&module_path);

        let artifact = artifact_manager
            .get_artifact(&contract_qualified_path)
            .ok_or(anyhow::anyhow!("Artifact not found"))?;

        let annotation = StarknetContractAnnotation {
            qualified_path: contract_qualified_path.clone(),
            class_hash: artifact.class_hash,
            name: self.contract_name.to_string(),
        };

        trace!(
            contract_path = contract_qualified_path,
            ?self,
            "Generating annotations for starknet contract {} ({}).",
            annotation.name,
            annotation.qualified_path,
        );

        Ok(annotation)
    }
}
