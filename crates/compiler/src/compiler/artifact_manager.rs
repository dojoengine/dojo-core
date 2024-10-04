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
use cairo_lang_starknet_classes::contract_class::ContractClass;
use scarb::core::Workspace;
use scarb::flock::Filesystem;
use starknet::core::types::Felt;
use tracing::trace;

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
}

impl<'w> ArtifactManager<'w> {
    /// Creates a new artifact manager.
    pub fn new(workspace: &'w Workspace) -> Self {
        Self {
            workspace,
            compiled_artifacts: HashMap::new(),
        }
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
