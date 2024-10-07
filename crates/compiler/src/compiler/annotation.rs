//! Dojo resource annotations.
//!
//! The dojo resource annotations are used to annotate the artifacts
//! generated by the compiler with information about the Dojo resources
//! found during the compilation process.
//!
//! The purpose of this file is to convey the annotations to the different
//! steps of the compilation decoupling from the aux data type that is very specific
//! to the `attribute_macros` plugin. Aux data don't have access to the qualified path,
//! annotations do include the qualified path.
//!
//! The qualified path in the annotation is the link connecting the artifact
//! to the annotation.

use std::io::{Read, Write};

use anyhow::Result;
use cairo_lang_compiler::db::RootDatabase;
use cairo_lang_defs::db::DefsGroup;
use cairo_lang_filesystem::ids::CrateId;
use cairo_lang_starknet::plugin::aux_data::StarkNetContractAuxData;
use dojo_types::naming;
use scarb::core::Workspace;
use serde::{Deserialize, Serialize};
use serde_with::serde_as;

use crate::aux_data::{AuxDataToAnnotation, ContractAuxData, EventAuxData, ModelAuxData};
use crate::scarb_extensions::WorkspaceExt;
use crate::{
    CAIRO_PATH_SEPARATOR, RESOURCE_METADATA_QUALIFIED_PATH, WORLD_CONTRACT_TAG,
    WORLD_QUALIFIED_PATH,
};

const DOJO_ANNOTATION_FILE_NAME: &str = "annotations";

pub trait AnnotationInfo {
    fn filename(&self) -> String;
    fn qualified_path(&self) -> String;
    fn tag(&self) -> String;
}

/// Represents a member of a struct.
#[derive(Clone, Debug, Serialize, Deserialize, PartialEq)]
pub struct Member {
    // Name of the member.
    pub name: String,
    // Type of the member.
    #[serde(rename = "type")]
    pub ty: String,
    // Whether the member is a key.
    pub key: bool,
}

/// Represents the annotations of a dojo contract.
#[serde_as]
#[derive(Clone, Default, Debug, Serialize, Deserialize)]
#[cfg_attr(test, derive(PartialEq))]
#[serde(tag = "kind", rename = "DojoContract")]
pub struct ContractAnnotation {
    pub qualified_path: String,
    pub tag: String,
    pub systems: Vec<String>,
}

/// Represents the annotations of a dojo model.
#[serde_as]
#[derive(Clone, Default, Debug, Serialize, Deserialize)]
#[cfg_attr(test, derive(PartialEq))]
#[serde(tag = "kind", rename = "DojoModel")]
pub struct ModelAnnotation {
    pub qualified_path: String,
    pub tag: String,
    pub members: Vec<Member>,
}

/// Represents the annotations of a dojo event.
#[serde_as]
#[derive(Clone, Default, Debug, Serialize, Deserialize)]
#[cfg_attr(test, derive(PartialEq))]
#[serde(tag = "kind", rename = "DojoEvent")]
pub struct EventAnnotation {
    pub qualified_path: String,
    pub tag: String,
    pub members: Vec<Member>,
}

/// Represents the world contract annotation.
#[serde_as]
#[derive(Clone, Debug, Serialize, Deserialize)]
#[cfg_attr(test, derive(PartialEq))]
#[serde(tag = "kind", rename = "DojoWorld")]
pub struct WorldAnnotation {
    pub qualified_path: String,
    pub tag: String,
}

impl Default for WorldAnnotation {
    fn default() -> Self {
        Self {
            qualified_path: WORLD_QUALIFIED_PATH.to_string(),
            tag: WORLD_CONTRACT_TAG.to_string(),
        }
    }
}

/// Represents the annotations of a starknet contract.
#[serde_as]
#[derive(Clone, Default, Debug, Serialize, Deserialize)]
#[cfg_attr(test, derive(PartialEq))]
#[serde(tag = "kind", rename = "StarknetContract")]
pub struct StarknetContractAnnotation {
    pub qualified_path: String,
    pub name: String,
}

impl AnnotationInfo for ModelAnnotation {
    fn filename(&self) -> String {
        naming::get_filename_from_tag(&self.tag)
    }
    fn qualified_path(&self) -> String {
        self.qualified_path.clone()
    }
    fn tag(&self) -> String {
        self.tag.clone()
    }
}

impl AnnotationInfo for EventAnnotation {
    fn filename(&self) -> String {
        naming::get_filename_from_tag(&self.tag)
    }
    fn qualified_path(&self) -> String {
        self.qualified_path.clone()
    }
    fn tag(&self) -> String {
        self.tag.clone()
    }
}

impl AnnotationInfo for ContractAnnotation {
    fn filename(&self) -> String {
        naming::get_filename_from_tag(&self.tag)
    }
    fn qualified_path(&self) -> String {
        self.qualified_path.clone()
    }
    fn tag(&self) -> String {
        self.tag.clone()
    }
}

impl AnnotationInfo for StarknetContractAnnotation {
    fn filename(&self) -> String {
        self.qualified_path.replace(CAIRO_PATH_SEPARATOR, "_")
    }
    fn qualified_path(&self) -> String {
        self.qualified_path.clone()
    }
    fn tag(&self) -> String {
        self.name.clone()
    }
}

impl AnnotationInfo for WorldAnnotation {
    fn filename(&self) -> String {
        WORLD_CONTRACT_TAG.to_string()
    }
    fn qualified_path(&self) -> String {
        self.qualified_path.clone()
    }
    fn tag(&self) -> String {
        self.tag.clone()
    }
}

/// An abstract representation of the annotations of dojo resources.
#[derive(Clone, Debug, Default, Serialize, Deserialize)]
pub struct DojoAnnotation {
    pub world: WorldAnnotation,
    pub contracts: Vec<ContractAnnotation>,
    pub models: Vec<ModelAnnotation>,
    pub events: Vec<EventAnnotation>,
    pub sn_contracts: Vec<StarknetContractAnnotation>,
}

impl DojoAnnotation {
    /// Creates a new dojo annotation.
    pub fn new() -> Self {
        Self {
            world: WorldAnnotation::default(),
            contracts: vec![],
            models: vec![],
            events: vec![],
            sn_contracts: vec![],
        }
    }

    /// Checks if the provided qualified path is a dojo resource.
    pub fn is_dojo_resource(&self, qualified_path: &str) -> bool {
        self.contracts
            .iter()
            .any(|c| c.qualified_path == qualified_path)
            || self
                .models
                .iter()
                .any(|m| m.qualified_path == qualified_path)
            || self
                .events
                .iter()
                .any(|e| e.qualified_path == qualified_path)
            || self.world.qualified_path == qualified_path
    }

    /// Sets the dojo annotations form the aux data extracted from the database.
    pub fn from_aux_data(db: &RootDatabase, crate_ids: &[CrateId]) -> Result<Self> {
        let mut annotations = DojoAnnotation::default();

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
                        let annotation = aux_data.to_annotation(&module_path)?;
                        annotations.contracts.push(annotation);
                        continue;
                    }

                    if let Some(aux_data) = aux_data.downcast_ref::<ModelAuxData>() {
                        let annotation = aux_data.to_annotation(&module_path)?;
                        annotations.models.push(annotation);
                        continue;
                    }

                    if let Some(aux_data) = aux_data.downcast_ref::<EventAuxData>() {
                        let annotation = aux_data.to_annotation(&module_path)?;
                        annotations.events.push(annotation);
                        continue;
                    }

                    if let Some(aux_data) = aux_data.downcast_ref::<StarkNetContractAuxData>() {
                        let annotation = aux_data.to_annotation(&module_path)?;

                        if annotation.qualified_path == WORLD_QUALIFIED_PATH {
                            annotations.world = WorldAnnotation {
                                qualified_path: WORLD_QUALIFIED_PATH.to_string(),
                                tag: WORLD_CONTRACT_TAG.to_string(),
                            };
                        } else if annotation.qualified_path == RESOURCE_METADATA_QUALIFIED_PATH {
                            // Skip this annotation as not used in the migration process.
                            continue;
                        } else {
                            annotations.sn_contracts.push(annotation);
                        }
                    }
                }
            }
        }

        // Since dojo resources are just starknet contracts under the hood,
        // we remove them from the sn_contracts list. We can't filter them earlier
        // as we need to wait all the annotations to be extracted before filtering.
        let mut filtered_sn_contracts = annotations.sn_contracts.clone();

        filtered_sn_contracts
            .retain(|sn_contract| !annotations.is_dojo_resource(&sn_contract.qualified_path));

        annotations.sn_contracts = filtered_sn_contracts;

        Ok(annotations)
    }

    /// Reads the annotations from the target directory of the provided workspace,
    /// for the current profile.
    ///
    /// # Arguments
    ///
    /// * `workspace` - The workspace to read the annotations from.
    pub fn read(workspace: &Workspace<'_>) -> Result<Self> {
        let target_dir = workspace.target_dir_profile();

        let mut file = target_dir.open_ro(
            format!("{}.toml", DOJO_ANNOTATION_FILE_NAME),
            "Dojo annotations",
            workspace.config(),
        )?;

        let mut content = String::new();
        file.read_to_string(&mut content)?;

        let annotations = toml::from_str(&content)?;

        Ok(annotations)
    }

    /// Writes the annotations to the target directory of the provided workspace,
    /// for the current profile.
    ///
    /// # Arguments
    ///
    /// * `workspace` - The workspace to write the annotations to.
    pub fn write(&self, workspace: &Workspace<'_>) -> Result<()> {
        let target_dir = workspace.target_dir_profile();
        let content = toml::to_string(&self)?;

        let mut file = target_dir.open_rw(
            format!("{}.toml", DOJO_ANNOTATION_FILE_NAME),
            "Dojo annotations",
            workspace.config(),
        )?;

        let _written = file.write(content.as_bytes())?;

        Ok(())
    }
}
