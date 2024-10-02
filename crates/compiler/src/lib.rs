//! Dojo compiler.
//!
//! This crate contains the Dojo compiler, with a cairo plugin for the Cairo language.
pub mod attribute_macros;
pub mod compiler;
pub mod inline_macros;
pub mod introspect;
pub mod namespace_config;
pub mod plugin;
pub mod print;
pub mod semantics;
pub mod syntax;
pub mod utils;

// Copy of non pub functions from scarb + extension.
pub mod scarb_internal;
