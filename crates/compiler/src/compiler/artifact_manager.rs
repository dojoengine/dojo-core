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

use std::collections::{BTreeMap, HashMap};
use std::fs;
use std::io::Write;
use std::ops::DerefMut;
use std::rc::Rc;

use anyhow::{anyhow, Context, Result};
use cairo_lang_compiler::db::RootDatabase;
use cairo_lang_compiler::CompilerConfig;
use cairo_lang_defs::ids::NamedLanguageElementId;
use cairo_lang_filesystem::db::FilesGroup;
use cairo_lang_filesystem::ids::{CrateId, CrateLongId};
use cairo_lang_starknet::compile::compile_prepared_db;
use cairo_lang_starknet::contract::{find_contracts, ContractDeclaration};
use cairo_lang_starknet_classes::allowed_libfuncs::{AllowedLibfuncsError, ListSelector};
use cairo_lang_starknet_classes::contract_class::ContractClass;
use cairo_lang_utils::UpcastMut;
use dojo_types::naming;
use itertools::{izip, Itertools};
use scarb::compiler::helpers::build_compiler_config;
use scarb::compiler::{CairoCompilationUnit, CompilationUnitAttributes, Compiler};
use scarb::core::{Config, Package, TargetKind, Workspace};
use scarb::flock::Filesystem;
use scarb::ops::CompileOpts;
use scarb_ui::args::{FeaturesSpec, PackagesFilter};
use scarb_ui::Ui;
use serde::de::DeserializeOwned;
use serde::{Deserialize, Serialize};
use smol_str::SmolStr;
use starknet::core::types::contract::SierraClass;
use starknet::core::types::Felt;
use tracing::{trace, trace_span};

use super::contract_selector::ContractSelector;
use super::scarb_internal;
use super::scarb_internal::debug::SierraToCairoDebugInfo;
use super::version::check_package_dojo_version;

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

pub struct ArtifactManager {
    /// The compiled artifacts.
    compiled_artifacts: CompiledArtifactByPath,
}

impl ArtifactManager {
    /// Creates a new artifact manager.
    pub fn new() -> Self {
        Self {
            compiled_artifacts: HashMap::new(),
        }
    }

    /// Returns an iterator over the compiled artifacts.
    pub fn iter(&self) -> impl Iterator<Item = (&String, &CompiledArtifact)> {
        self.compiled_artifacts.iter()
    }

    /// Gets a compiled artifact from the manager.
    pub fn get_artifact(&self, path: &str) -> Option<&CompiledArtifact> {
        self.compiled_artifacts.get(path)
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
    pub fn save_sierra_class(
        &self,
        config: &Config,
        target_dir: &Filesystem,
        qualified_path: &str,
        file_name: &str,
    ) -> anyhow::Result<()> {
        trace!(target_dir = %target_dir, qualified_path, file_name, "Saving sierra class file.");

        let artifact = self
            .get_artifact(qualified_path)
            .context(format!("Artifact file for `{}` not found.", qualified_path))?;

        let mut file = target_dir.open_rw(
            format!("{file_name}.json"),
            &format!("sierra class file for `{}`", qualified_path),
            config,
        )?;

        serde_json::to_writer_pretty(file.deref_mut(), &*artifact.contract_class)
            .with_context(|| format!("failed to serialize sierra class file: {qualified_path}"))?;

        if let Some(debug_info) = &artifact.debug_info {
            let mut file = target_dir.open_rw(
                format!("{file_name}.debug.json"),
                &format!("sierra debug info for `{}`", qualified_path),
                config,
            )?;

            serde_json::to_writer_pretty(file.deref_mut(), &**debug_info).with_context(|| {
                format!("failed to serialize sierra debug info: {qualified_path}")
            })?;
        }

        Ok(())
    }

    /// Saves the ABI of a compiled artifact to a JSON file.
    pub fn save_abi(
        &self,
        config: &Config,
        target_dir: &Filesystem,
        qualified_path: &str,
        file_name: &str,
    ) -> anyhow::Result<()> {
        trace!(target_dir = %target_dir, qualified_path, file_name, "Saving abi file.");

        let artifact = self
            .get_artifact(qualified_path)
            .context(format!("Artifact file for `{}` not found.", qualified_path))?;

        let mut file = target_dir.open_rw(
            format!("{file_name}.json"),
            &format!("sierra class file for `{}`", qualified_path),
            config,
        )?;

        serde_json::to_writer_pretty(file.deref_mut(), &artifact.contract_class.abi)
            .with_context(|| format!("failed to serialize abi: {qualified_path}"))?;

        Ok(())
    }
}
