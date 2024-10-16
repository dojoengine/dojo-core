//! Artifact manager for the compiler.
//!
//! The primary purpose of this module is to manage the compiled artifacts
//! and abstract the writing of the artifacts to the filesystem.
//!
//! The artifact manager can be completed with the dojo annotations extracted
//! from the aux data of the generated files, which retain the information about
//! the nature of the contracts being compiled.
//!
//! When using annotations, the qualified path is the link connecting the artifact
//! to the annotation.

use std::collections::HashMap;
use std::ops::DerefMut;
use std::rc::Rc;

use anyhow::{Context, Result};
use cairo_lang_compiler::db::RootDatabase;
use cairo_lang_filesystem::ids::CrateId;
use cairo_lang_starknet_classes::contract_class::ContractClass;
use scarb::core::Workspace;
use scarb::flock::Filesystem;
use starknet::core::types::Felt;
use tracing::trace;

use crate::compiler::cairo_compiler::compute_class_hash_of_contract_class;
use crate::scarb_extensions::WorkspaceExt;
use crate::{CONTRACTS_DIR, EVENTS_DIR, MODELS_DIR};

use super::annotation::{AnnotationInfo, DojoAnnotation};
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

#[derive(Debug)]
pub struct ArtifactManager<'w> {
    /// The workspace of the current compilation.
    workspace: &'w Workspace<'w>,
    /// The compiled artifacts.
    compiled_artifacts: CompiledArtifactByPath,
    /// Dojo annotation.
    dojo_annotation: DojoAnnotation,
}

impl<'w> ArtifactManager<'w> {
    /// Creates a new artifact manager.
    pub fn new(workspace: &'w Workspace<'_>) -> Self {
        Self {
            workspace,
            compiled_artifacts: HashMap::new(),
            dojo_annotation: DojoAnnotation::default(),
        }
    }

    /// Sets the dojo annotations form the aux data extracted from the database.
    pub fn set_dojo_annotation(&mut self, db: &RootDatabase, crate_ids: &[CrateId]) -> Result<()> {
        // Ensures that the dojo annotations are empty to not keep any stale data.
        self.dojo_annotation = DojoAnnotation::default();
        self.dojo_annotation = DojoAnnotation::from_aux_data(db, crate_ids)?;

        Ok(())
    }

    /// Returns the dojo annotation.
    pub fn dojo_annotation(&self) -> &DojoAnnotation {
        &self.dojo_annotation
    }

    /// Returns the workspace of the current compilation.
    pub fn workspace(&self) -> &Workspace<'_> {
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
        self.dojo_annotation.write(self.workspace)?;

        let target_dir = self.workspace.target_dir_profile();

        self.write_sierra_class(
            &self.dojo_annotation.world.qualified_path,
            &target_dir,
            &self.dojo_annotation.world.filename(),
        )?;

        for contract in &self.dojo_annotation.contracts {
            let filename = contract.filename();
            let target_dir = target_dir.child(CONTRACTS_DIR);
            self.write_sierra_class(&contract.qualified_path, &target_dir, &filename)?;
        }

        for model in &self.dojo_annotation.models {
            let filename = model.filename();
            let target_dir = target_dir.child(MODELS_DIR);
            self.write_sierra_class(&model.qualified_path, &target_dir, &filename)?;
        }

        for event in &self.dojo_annotation.events {
            let filename = event.filename();
            let target_dir = target_dir.child(EVENTS_DIR);
            self.write_sierra_class(&event.qualified_path, &target_dir, &filename)?;
        }

        for sn_contract in &self.dojo_annotation.sn_contracts {
            // TODO: we might want to use namespace for starknet contracts too.
            let file_name = sn_contract.filename();
            self.write_sierra_class(&sn_contract.qualified_path, &target_dir, &file_name)?;
        }

        Ok(())
    }

    /// Reads the artifacts from the filesystem by reading the dojo annotations.
    pub fn read(&mut self, workspace: &'w Workspace<'_>) -> Result<()> {
        self.dojo_annotation = DojoAnnotation::read(workspace)?;

        self.add_artifact(
            self.dojo_annotation.world.qualified_path.to_string(),
            self.read_compiled_artifact(
                &self.dojo_annotation.world.qualified_path,
                &workspace.target_dir_profile(),
                &self.dojo_annotation.world.filename(),
            )?,
        );

        for contract in self.dojo_annotation.contracts.clone() {
            let target_dir = workspace.target_dir_profile().child(CONTRACTS_DIR);

            self.add_artifact(
                contract.qualified_path.to_string(),
                self.read_compiled_artifact(
                    &contract.qualified_path,
                    &target_dir,
                    &contract.filename(),
                )?,
            );
        }

        for model in self.dojo_annotation.models.clone() {
            let target_dir = workspace.target_dir_profile().child(MODELS_DIR);

            self.add_artifact(
                model.qualified_path.to_string(),
                self.read_compiled_artifact(&model.qualified_path, &target_dir, &model.filename())?,
            );
        }

        for event in self.dojo_annotation.events.clone() {
            let target_dir = workspace.target_dir_profile().child(EVENTS_DIR);

            self.add_artifact(
                event.qualified_path.to_string(),
                self.read_compiled_artifact(&event.qualified_path, &target_dir, &event.filename())?,
            );
        }

        for sn_contract in self.dojo_annotation.sn_contracts.clone() {
            let target_dir = workspace.target_dir_profile();

            self.add_artifact(
                sn_contract.qualified_path.to_string(),
                self.read_compiled_artifact(
                    &sn_contract.qualified_path,
                    &target_dir,
                    &sn_contract.filename(),
                )?,
            );
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
    fn write_sierra_class(
        &self,
        qualified_path: &str,
        target_dir: &Filesystem,
        file_name: &str,
    ) -> anyhow::Result<()> {
        trace!(target_dir = ?target_dir, qualified_path, file_name, "Saving sierra class file.");

        let artifact = self
            .get_artifact(qualified_path)
            .context(format!("Artifact file for `{}` not found.", qualified_path))?;

        let mut file = target_dir.create_rw(
            format!("{file_name}.json"),
            &format!("sierra class file for `{}`", qualified_path),
            self.workspace.config(),
        )?;

        serde_json::to_writer_pretty(file.deref_mut(), &*artifact.contract_class)
            .with_context(|| format!("failed to serialize sierra class file: {qualified_path}"))?;

        if let Some(debug_info) = &artifact.debug_info {
            let mut file = target_dir.create_rw(
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

    /// Reads a Sierra contract class from a JSON file.
    /// If debug info is available, it will also be read from a separate file.
    ///
    /// # Arguments
    ///
    /// * `qualified_path` - The cairo module qualified path.
    /// * `target_dir` - The target directory to save the artifact to.
    /// * `file_name` - The name of the file to save the artifact to, without extension.
    fn read_compiled_artifact(
        &self,
        qualified_path: &str,
        target_dir: &Filesystem,
        file_name: &str,
    ) -> anyhow::Result<CompiledArtifact> {
        trace!(target_dir = ?target_dir, qualified_path, file_name, "Reading compiled artifact.");

        let mut file = target_dir.open_ro(
            format!("{file_name}.json"),
            &format!("sierra class file for `{}`", qualified_path),
            self.workspace.config(),
        )?;

        // Read the class, that must be present, and recompute the class hash.
        let contract_class: ContractClass = serde_json::from_reader(file.deref_mut())?;

        let class_hash =
            compute_class_hash_of_contract_class(&contract_class).with_context(|| {
                format!(
                    "problem computing class hash for contract `{}`",
                    qualified_path
                )
            })?;

        // Debug info may or may not be present.
        let debug_info = if target_dir.child(format!("{file_name}.debug.json")).exists() {
            trace!(target_dir = ?target_dir, qualified_path, file_name, "Reading sierra debug info.");

            let mut file = target_dir.open_ro(
                format!("{file_name}.debug.json"),
                &format!("sierra debug info for `{}`", qualified_path),
                self.workspace.config(),
            )?;

            Some(Rc::new(serde_json::from_reader(file.deref_mut())?))
        } else {
            None
        };

        let compiled_artifact = CompiledArtifact {
            class_hash,
            contract_class: Rc::new(contract_class),
            debug_info,
        };

        Ok(compiled_artifact)
    }
}
