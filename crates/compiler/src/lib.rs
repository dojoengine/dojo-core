//! Dojo compiler.
//!
//! This crate contains the Dojo compiler, with a cairo plugin for the Cairo language.

pub mod aux_data;
pub mod compiler;
pub mod namespace_config;
pub mod plugin;
pub mod scarb_extensions;

pub const CAIRO_PATH_SEPARATOR: &str = "::";
pub const WORLD_QUALIFIED_PATH: &str = "dojo::world::world_contract::world";
pub const WORLD_CONTRACT_TAG: &str = "dojo-world";
pub const BASE_QUALIFIED_PATH: &str = "dojo::contract::base_contract::base";
pub const BASE_CONTRACT_TAG: &str = "dojo-base";
pub const RESOURCE_METADATA_QUALIFIED_PATH: &str = "dojo::model::metadata::resource_metadata";
pub const CONTRACTS_DIR: &str = "contracts";
pub const MODELS_DIR: &str = "models";
pub const MANIFESTS_DIR: &str = "manifests";
pub const MANIFESTS_BASE_DIR: &str = "base";
