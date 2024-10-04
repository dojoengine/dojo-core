//! Version information for the Dojo compiler.

use std::str::FromStr;

use anyhow::Result;
use camino::Utf8PathBuf;
use scarb::core::{Package, TomlManifest, Workspace};
use semver::Version;
use tracing::trace;

/// Generates the version string for the Dojo compiler.
pub fn generate_version() -> String {
    const DOJO_VERSION: &str = env!("CARGO_PKG_VERSION");
    let scarb_version = scarb::version::get().version;
    let scarb_sierra_version = scarb::version::get().sierra.version;
    let scarb_cairo_version = scarb::version::get().cairo.version;

    let version_string = format!(
        "{}\nscarb: {}\ncairo: {}\nsierra: {}",
        DOJO_VERSION, scarb_version, scarb_cairo_version, scarb_sierra_version,
    );
    version_string
}

/// Verifies that the Cairo version specified in the manifest file is compatible with the current
/// version of Cairo used by Dojo.
pub fn verify_cairo_version_compatibility(manifest_path: &Utf8PathBuf) -> Result<()> {
    let scarb_cairo_version = scarb::version::get().cairo;

    let Ok(manifest) = TomlManifest::read_from_path(manifest_path) else {
        return Ok(());
    };
    let Some(package) = manifest.package else {
        return Ok(());
    };
    let Some(cairo_version) = package.cairo_version else {
        return Ok(());
    };

    let version_req = cairo_version.as_defined().unwrap();
    let version = Version::from_str(scarb_cairo_version.version).unwrap();

    trace!(version_req = %version_req, version = %version, "Cairo version compatibility.");

    if !version_req.matches(&version) {
        anyhow::bail!(
            "Cairo version `{version_req}` specified in the manifest file `{manifest_path}` is not supported by dojo, which is expecting `{version}`. \
             Please verify and update dojo or change the Cairo version in the manifest file.",
        );
    };

    Ok(())
}

/// Checks if the package has a compatible version of dojo-core.
/// In case of a workspace with multiple packages, each package is individually checked
/// and the workspace manifest path is returned in case of virtual workspace.
pub fn check_package_dojo_version(ws: &Workspace<'_>, package: &Package) -> anyhow::Result<()> {
    if let Some(dojo_dep) = package
        .manifest
        .summary
        .dependencies
        .iter()
        .find(|dep| dep.name.as_str() == "dojo")
    {
        let dojo_version = env!("CARGO_PKG_VERSION");

        let dojo_dep_str = dojo_dep.to_string();

        // Only in case of git dependency with an explicit tag, we check if the tag is the same as
        // the current version.
        if dojo_dep_str.contains("git+")
            && dojo_dep_str.contains("tag=v")
            && !dojo_dep_str.contains(dojo_version)
        {
            if let Ok(cp) = ws.current_package() {
                let path = if cp.id == package.id {
                    package.manifest_path()
                } else {
                    ws.manifest_path()
                };

                anyhow::bail!(
                    "Found dojo-core version mismatch: expected {}. Please verify your dojo \
                     dependency in {}",
                    dojo_version,
                    path
                )
            } else {
                // Virtual workspace.
                anyhow::bail!(
                    "Found dojo-core version mismatch: expected {}. Please verify your dojo \
                     dependency in {}",
                    dojo_version,
                    ws.manifest_path()
                )
            }
        }
    }

    Ok(())
}
