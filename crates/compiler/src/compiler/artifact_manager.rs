//! Artifact manager for the compiler.
//!
//! The primary purpose of this module is to manage the compiled artifacts
//! and abstract the writing of the artifacts to the filesystem.
//!
//! The artifact manager doesn't have any context of the nature of the contracts
//! that are being compiled (dojo contract, model contract, starknet contract, ...).
//!
//! The plugin aux data are the one that will keep this information mapped to the
//! qualified path of the compiled contracts.

use std::collections::HashMap;
use std::ops::DerefMut;
use std::rc::Rc;

use anyhow::{Context, Result};
use cairo_lang_compiler::db::RootDatabase;
use cairo_lang_defs::db::DefsGroup;
use cairo_lang_filesystem::ids::CrateId;
use cairo_lang_starknet::plugin::aux_data::StarkNetContractAuxData;
use cairo_lang_starknet_classes::contract_class::ContractClass;
use dojo_types::naming;
use scarb::core::Workspace;
use scarb::flock::Filesystem;
use starknet::core::types::Felt;
use tracing::trace;

use crate::aux_data::{AuxDataToAnnotation, ContractAuxData, EventAuxData, ModelAuxData};
use crate::scarb_extensions::WorkspaceExt;
use crate::{
    BASE_CONTRACT_TAG, BASE_QUALIFIED_PATH, CAIRO_PATH_SEPARATOR, CONTRACTS_DIR, EVENTS_DIR,
    MODELS_DIR, RESOURCE_METADATA_QUALIFIED_PATH, WORLD_CONTRACT_TAG, WORLD_QUALIFIED_PATH,
};

use super::annotation::{BaseAnnotation, DojoAnnotation, WorldAnnotation};
use super::scarb_internal::debug::SierraToCairoDebugInfo;

#[derive(Debug, Clone)]
pub struct CompiledArtifact {
    /// The class hash of the Sierra class.
    pub class_hash: Felt,
    /// The actual compiled Sierra class.
    pub contract_class: Rc<ContractClass>,
    /// Optional debug info for the Sierra class.
    pub debug_info: Option<Rc<SierraToCairoDebugInfo>>,
}

/// A type alias for a map of compiled artifacts by their path.
type CompiledArtifactByPath = HashMap<String, CompiledArtifact>;

pub struct ArtifactManager<'w> {
    /// The workspace of the current compilation.
    workspace: &'w Workspace<'w>,
    /// The compiled artifacts.
    compiled_artifacts: CompiledArtifactByPath,
    /// Dojo annotations.
    dojo_annotations: DojoAnnotation,
}

impl<'w> ArtifactManager<'w> {
    /// Creates a new artifact manager.
    pub fn new(workspace: &'w Workspace) -> Self {
        Self {
            workspace,
            compiled_artifacts: HashMap::new(),
            dojo_annotations: DojoAnnotation::default(),
        }
    }

    /// Sets the dojo annotations form the aux data extracted from the database.
    pub fn set_dojo_annotations(&mut self, db: &RootDatabase, crate_ids: &[CrateId]) -> Result<()> {
        // Ensures that the dojo annotations are empty to not keep any stale data.
        self.dojo_annotations = DojoAnnotation::default();

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
                        let annotation = aux_data.to_annotation(self, &module_path)?;
                        self.dojo_annotations.contracts.push(annotation);
                        continue;
                    }

                    if let Some(aux_data) = aux_data.downcast_ref::<ModelAuxData>() {
                        let annotation = aux_data.to_annotation(self, &module_path)?;
                        self.dojo_annotations.models.push(annotation);
                        continue;
                    }

                    if let Some(aux_data) = aux_data.downcast_ref::<EventAuxData>() {
                        let annotation = aux_data.to_annotation(self, &module_path)?;
                        self.dojo_annotations.events.push(annotation);
                        continue;
                    }

                    if let Some(aux_data) = aux_data.downcast_ref::<StarkNetContractAuxData>() {
                        let annotation = aux_data.to_annotation(self, &module_path)?;

                        if annotation.qualified_path == WORLD_QUALIFIED_PATH {
                            self.dojo_annotations.world = WorldAnnotation {
                                class_hash: annotation.class_hash,
                                qualified_path: WORLD_QUALIFIED_PATH.to_string(),
                                tag: WORLD_CONTRACT_TAG.to_string(),
                            };
                        } else if annotation.qualified_path == BASE_QUALIFIED_PATH {
                            self.dojo_annotations.base = BaseAnnotation {
                                class_hash: annotation.class_hash,
                                qualified_path: BASE_QUALIFIED_PATH.to_string(),
                                tag: BASE_CONTRACT_TAG.to_string(),
                            };
                        } else if annotation.qualified_path == RESOURCE_METADATA_QUALIFIED_PATH {
                            // Skip this annotation as not used in the migration process.
                            continue;
                        } else {
                            self.dojo_annotations.sn_contracts.push(annotation);
                        }
                    }
                }
            }
        }

        // Since dojo resources are just starknet contracts under the hood,
        // we remove them from the sn_contracts list. We can't filter them earlier
        // as we need to wait all the annotations to be extracted before filtering.
        let mut filtered_sn_contracts = self.dojo_annotations.sn_contracts.clone();

        filtered_sn_contracts.retain(|sn_contract| {
            !self
                .dojo_annotations
                .is_dojo_resource(&sn_contract.qualified_path)
        });

        self.dojo_annotations.sn_contracts = filtered_sn_contracts;

        Ok(())
    }

    /// Returns the workspace of the current compilation.
    pub fn workspace(&self) -> &Workspace {
        self.workspace
    }

    /// Returns an iterator over the compiled artifacts.
    pub fn iter(&self) -> impl Iterator<Item = (&String, &CompiledArtifact)> {
        self.compiled_artifacts.iter()
    }

    /// Gets a compiled artifact from the manager.
    pub fn get_artifact(&self, qualified_path: &str) -> Option<&CompiledArtifact> {
        self.compiled_artifacts.get(qualified_path)
    }

    /// Gets the class hash of a compiled artifact.
    pub fn get_class_hash(&self, qualified_path: &str) -> Result<Felt> {
        let artifact = self.get_artifact(qualified_path).context(format!(
            "Can't get class hash from artifact for qualified path {qualified_path}"
        ))?;

        Ok(artifact.class_hash)
    }

    /// Adds a compiled artifact to the manager.
    ///
    /// # Arguments
    ///
    /// * `qualified_path` - The cairo module qualified path of the artifact.
    /// * `artifact` - The compiled artifact.
    pub fn add_artifact(&mut self, qualified_path: String, artifact: CompiledArtifact) {
        trace!(qualified_path, "Adding artifact to the manager.");
        self.compiled_artifacts.insert(qualified_path, artifact);
    }

    /// Writes all the dojo annotations and artifacts to the filesystem.
    pub fn write(&self) -> Result<()> {
        self.dojo_annotations.write(self.workspace)?;

        let target_dir = self.workspace.target_dir_profile();

        self.write_sierra_class(WORLD_QUALIFIED_PATH, &target_dir, WORLD_CONTRACT_TAG)?;
        self.write_sierra_class(BASE_QUALIFIED_PATH, &target_dir, BASE_CONTRACT_TAG)?;

        for contract in &self.dojo_annotations.contracts {
            let filename = naming::get_filename_from_tag(&contract.tag);
            let target_dir = target_dir.child(CONTRACTS_DIR);
            self.write_sierra_class(&contract.qualified_path, &target_dir, &filename)?;
        }

        for model in &self.dojo_annotations.models {
            let filename = naming::get_filename_from_tag(&model.tag);
            let target_dir = target_dir.child(MODELS_DIR);
            self.write_sierra_class(&model.qualified_path, &target_dir, &filename)?;
        }

        for event in &self.dojo_annotations.events {
            let filename = naming::get_filename_from_tag(&event.tag);
            let target_dir = target_dir.child(EVENTS_DIR);
            self.write_sierra_class(&event.qualified_path, &target_dir, &filename)?;
        }

        for sn_contract in &self.dojo_annotations.sn_contracts {
            // TODO: we might want to use namespace for starknet contracts too.
            let file_name = sn_contract
                .qualified_path
                .replace(CAIRO_PATH_SEPARATOR, "_");

            self.write_sierra_class(&sn_contract.qualified_path, &target_dir, &file_name)?;
        }

        Ok(())
    }

    /// Saves a Sierra contract class to a JSON file.
    /// If debug info is available, it will also be saved to a separate file.
    ///
    /// # Arguments
    ///
    /// * `qualified_path` - The cairo module qualified path.
    /// * `target_dir` - The target directory to save the artifact to.
    /// * `file_name` - The name of the file to save the artifact to, without extension.
    pub fn write_sierra_class(
        &self,
        qualified_path: &str,
        target_dir: &Filesystem,
        file_name: &str,
    ) -> anyhow::Result<()> {
        trace!(target_dir = ?target_dir, qualified_path, file_name, "Saving sierra class file.");

        let artifact = self
            .get_artifact(qualified_path)
            .context(format!("Artifact file for `{}` not found.", qualified_path))?;

        let mut file = target_dir.open_rw(
            format!("{file_name}.json"),
            &format!("sierra class file for `{}`", qualified_path),
            self.workspace.config(),
        )?;

        serde_json::to_writer_pretty(file.deref_mut(), &*artifact.contract_class)
            .with_context(|| format!("failed to serialize sierra class file: {qualified_path}"))?;

        if let Some(debug_info) = &artifact.debug_info {
            let mut file = target_dir.open_rw(
                format!("{file_name}.debug.json"),
                &format!("sierra debug info for `{}`", qualified_path),
                self.workspace.config(),
            )?;

            serde_json::to_writer_pretty(file.deref_mut(), &**debug_info).with_context(|| {
                format!("failed to serialize sierra debug info: {qualified_path}")
            })?;
        }

        Ok(())
    }

    /// Saves the ABI of a compiled artifact to a JSON file.
    ///
    /// # Arguments
    ///
    /// * `qualified_path` - The cairo module qualified path.
    /// * `target_dir` - The target directory to save the artifact to.
    /// * `file_name` - The name of the file to save the artifact to, without extension.
    pub fn write_abi(
        &self,
        qualified_path: &str,
        target_dir: &Filesystem,
        file_name: &str,
    ) -> anyhow::Result<()> {
        trace!(target_dir = ?target_dir, qualified_path, file_name, "Saving abi file.");

        let artifact = self
            .get_artifact(qualified_path)
            .context(format!("Artifact file for `{}` not found.", qualified_path))?;

        let mut file = target_dir.open_rw(
            format!("{file_name}.json"),
            &format!("abi file for `{}`", qualified_path),
            self.workspace.config(),
        )?;

        serde_json::to_writer_pretty(file.deref_mut(), &artifact.contract_class.abi)
            .with_context(|| format!("failed to serialize abi: {qualified_path}"))?;

        Ok(())
    }
}
