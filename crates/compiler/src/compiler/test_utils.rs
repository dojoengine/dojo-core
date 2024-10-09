//! Test utilities for the compiler testing.
//!
//! Mostly related to Scrab configuration.
//! Important to note that if tests are run in parallel, the cache_dir and output directories
//! may clash. In such cases, consider copying the project or overriding the directories.

use std::env;
use std::path::PathBuf;

use assert_fs::TempDir;
use camino::{Utf8Path, Utf8PathBuf};
use scarb::compiler::{CompilationUnit, CompilerRepository, Profile};
use scarb::core::Config;
use scarb::ops;
use scarb::ops::{FeaturesOpts, FeaturesSelector};
use scarb_ui::Verbosity;

use super::DojoCompiler;
use crate::plugin::CairoPluginRepository;

/// Builds a test config with a temporary cache directory.
///
/// # Arguments
///
/// * `path` - The path to the Scarb.toml file to build the config for.
/// * `profile` - The profile to use for the config.
pub fn build_test_config(path: &str, profile: Profile) -> anyhow::Result<Config> {
    let mut compilers = CompilerRepository::empty();
    compilers.add(Box::new(DojoCompiler::default())).unwrap();

    let cairo_plugins = CairoPluginRepository::default();

    // If the cache_dir is not overriden, we can't run tests in parallel.
    let cache_dir = TempDir::new().unwrap();

    let path = Utf8PathBuf::from_path_buf(path.into()).unwrap();
    Config::builder(path.canonicalize_utf8().unwrap())
        .global_cache_dir_override(Some(Utf8Path::from_path(cache_dir.path()).unwrap()))
        .ui_verbosity(Verbosity::Verbose)
        .log_filter_directive(env::var_os("SCARB_LOG"))
        .compilers(compilers)
        .profile(profile)
        .cairo_plugins(cairo_plugins.into())
        .build()
}

/// Returns the path to the corelib for the given [`Config`].
///
/// `detect_corelib` from cairo compiler is not used, since it's not finding the corelib
/// in the testing environment.
/// We then leverage the Scarb workspace capabilities to detect the corelib.
///
/// # Arguments
///
/// * `config` - The [`Config`] to use for the corelib detection.
pub fn corelib(config: &Config) -> PathBuf {
    let ws = ops::read_workspace(config.manifest_path(), config).unwrap();
    let resolve = ops::resolve_workspace(&ws).unwrap();

    let features_opts = FeaturesOpts {
        features: FeaturesSelector::AllFeatures,
        no_default_features: false,
    };

    let compilation_units = ops::generate_compilation_units(&resolve, &features_opts, &ws).unwrap();

    if let CompilationUnit::Cairo(unit) = &compilation_units[0] {
        unit.core_package_component()
            .expect("should have component")
            .targets[0]
            .source_root()
            .into()
    } else {
        panic!("should have cairo compilation unit")
    }
}
