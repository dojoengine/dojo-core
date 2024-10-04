//! Manifests generated by the compiler.
//!
//! The manifests files contains metadata about
//! the contracts being compiled, since in Dojo
//! every resource is represented as a starknet contract.

use std::io::Write;

use anyhow::Result;
use dojo_types::naming;
use scarb::core::Workspace;
use serde::{Deserialize, Serialize};
use serde_with::serde_as;
use starknet::core::serde::unsigned_field_element::UfeHex;
use starknet::core::types::Felt;

use crate::scarb_extensions::WorkspaceExt;
use crate::{
    BASE_CONTRACT_TAG, CAIRO_PATH_SEPARATOR, CONTRACTS_DIR, MODELS_DIR, WORLD_CONTRACT_TAG,
};

const TOML_EXTENSION: &str = "toml";

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

/// Represents the contract of a dojo contract.
#[serde_as]
#[derive(Clone, Default, Debug, Serialize, Deserialize)]
#[cfg_attr(test, derive(PartialEq))]
#[serde(tag = "kind", rename = "DojoContract")]
pub struct ContractManifest {
    #[serde_as(as = "UfeHex")]
    pub class_hash: Felt,
    pub qualified_path: String,
    pub tag: String,
    pub systems: Vec<String>,
}

/// Represents the contract of a dojo model.
#[serde_as]
#[derive(Clone, Default, Debug, Serialize, Deserialize)]
#[cfg_attr(test, derive(PartialEq))]
#[serde(tag = "kind", rename = "DojoModel")]
pub struct ModelManifest {
    #[serde_as(as = "UfeHex")]
    pub class_hash: Felt,
    pub qualified_path: String,
    pub tag: String,
    pub members: Vec<Member>,
}

/// Represents a starknet contract.
#[serde_as]
#[derive(Clone, Default, Debug, Serialize, Deserialize)]
#[cfg_attr(test, derive(PartialEq))]
#[serde(tag = "kind", rename = "StarknetContract")]
pub struct StarknetContractManifest {
    #[serde_as(as = "UfeHex")]
    pub class_hash: Felt,
    pub qualified_path: String,
    pub name: String,
}

/// An abstract representation of the manifest files combined.
///
/// An [`AbstractBaseManifest`] internalizes the workspace reference
/// to automatically provide the paths to the manifest files based on the
/// workspace configuration.
#[derive(Clone, Debug)]
pub struct AbstractBaseManifest<'w> {
    workspace: &'w Workspace<'w>,
    pub world: StarknetContractManifest,
    pub base: StarknetContractManifest,
    pub contracts: Vec<ContractManifest>,
    pub models: Vec<ModelManifest>,
    pub sn_contracts: Vec<StarknetContractManifest>,
}

impl<'w> AbstractBaseManifest<'w> {
    /// Creates a new abstract base manifest.
    pub fn new(workspace: &'w Workspace) -> Self {
        Self {
            workspace,
            world: StarknetContractManifest::default(),
            base: StarknetContractManifest::default(),
            contracts: vec![],
            models: vec![],
            sn_contracts: vec![],
        }
    }
    /// Writes the manifest to the given path.
    ///
    /// # Arguments
    ///
    /// * `path` - The path to write the manifest files to.
    pub fn write(&self) -> Result<()> {
        let base_dir = self.workspace.manfiests_dir_profile();

        let world = toml::to_string(&self.world)?;

        let mut file = base_dir.open_rw(
            format!("{}.toml", naming::get_filename_from_tag(WORLD_CONTRACT_TAG)),
            &format!("world manifest"),
            self.workspace.config(),
        )?;

        file.write(world.as_bytes())?;

        let base = toml::to_string(&self.base)?;

        let mut file = base_dir.open_rw(
            format!("{}.toml", naming::get_filename_from_tag(BASE_CONTRACT_TAG)),
            &format!("base manifest"),
            self.workspace.config(),
        )?;

        file.write(base.as_bytes())?;

        let contracts_dir = base_dir.child(CONTRACTS_DIR);
        let models_dir = base_dir.child(MODELS_DIR);

        for contract in &self.contracts {
            let name = format!(
                "{}.{}",
                naming::get_filename_from_tag(&contract.tag),
                TOML_EXTENSION
            );

            let mut file = contracts_dir.open_rw(
                name,
                &format!("contract manifest for `{}`", contract.qualified_path),
                self.workspace.config(),
            )?;

            file.write(toml::to_string(contract)?.as_bytes())?;
        }

        for model in &self.models {
            let name = format!(
                "{}.{}",
                naming::get_filename_from_tag(&model.tag),
                TOML_EXTENSION
            );

            let mut file = models_dir.open_rw(
                name,
                &format!("model manifest for `{}`", model.qualified_path),
                self.workspace.config(),
            )?;

            file.write(toml::to_string(model)?.as_bytes())?;
        }

        for sn_contract in &self.sn_contracts {
            let name = format!(
                "{}.{}",
                sn_contract
                    .qualified_path
                    .replace(CAIRO_PATH_SEPARATOR, "_"),
                TOML_EXTENSION
            );

            let mut file = base_dir.open_rw(
                name,
                &format!("starknet contract manifest for `{}`", sn_contract.name),
                self.workspace.config(),
            )?;

            file.write(toml::to_string(sn_contract)?.as_bytes())?;
        }

        Ok(())
    }
}
