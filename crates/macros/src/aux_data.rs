//! Auxiliary data for Dojo generated files.
//!
//! The plugin generates aux data for models, contracts and events.
//! Then the compiler uses this aux data to generate the manifests and organize the artifacts.

use serde::{Deserialize, Serialize};

/// Represents a member of a struct.
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct Member {
    // Name of the member.
    pub name: String,
    // Type of the member.
    pub ty: String,
    // Whether the member is a key.
    pub key: bool,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct ModelAuxData {
    pub name: String,
    pub members: Vec<Member>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ContractAuxData {
    pub name: String,
    pub systems: Vec<String>,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct EventAuxData {
    pub name: String,
    pub members: Vec<Member>,
}
