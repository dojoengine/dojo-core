use anyhow::Result;
use camino::Utf8PathBuf;
use scarb::core::{Package, TargetKind, Workspace};
use serde::Deserialize;
use tracing::{trace, warn};

use crate::namespace_config::NamespaceConfig;

/// Dojo compiler configuration file contents.
#[derive(Debug, Clone, Default, Deserialize)]
pub struct CompilerConfig {
    pub namespace: NamespaceConfig,
}

/// Loads the Dojo configuration for a given configuration type `T`.
///
/// By having a generic type for the config, we can avoid having multiple configuration files,
/// and only extract the part that is relevant.
///
/// For example, the compiler only relies on the `namespace` configuration. However, sozo
/// requires additional configurations, like `world`, `env`, etc.
pub struct DojoConfigLoader<T>
where
    T: serde::de::DeserializeOwned + Default,
{
    _phantom: std::marker::PhantomData<T>,
}

impl<T> DojoConfigLoader<T>
where
    T: serde::de::DeserializeOwned + Default,
{
    /// Loads the Dojo configuration from the given package.
    pub fn from_package(package: &Package, ws: &Workspace<'_>) -> Result<T> {
        // If it's a lib, we can try to extract dojo data. If failed -> then we can return default.
        // But like so, if some metadata are here, we get them.
        // [[target.dojo]] shouldn't be used with [lib] as no files will be deployed.
        let is_lib = package.target(&TargetKind::new("lib")).is_some();
        let is_dojo = package.target(&TargetKind::new("dojo")).is_some();

        if is_lib && is_dojo {
            return Err(anyhow::anyhow!(
                "[lib] package cannot have [[target.dojo]]."
            ));
        }

        let profile = ws.current_profile()?;
        let manifest_dir = &Utf8PathBuf::from(package.manifest_path().parent().unwrap());
        let dev_config_path = manifest_dir.join("dojo_dev.toml");
        let config_path = manifest_dir.join(format!("dojo_{}.toml", profile.as_str()));

        trace!(package = ?package.id.name, manifest_dir = ?manifest_dir, profile = ?profile, "Loading dojo config.");

        if !dev_config_path.exists() {
            if !is_lib {
                warn!("Dojo configuration file not found, using default config. Consider adding `dojo_{profile}.toml` alongside your `Scarb.toml` to configure Dojo with this profile.");
            }

            return Ok(Default::default());
        }

        // If the profile file is not found, default to the dev config, if any.
        let config_path = if !config_path.exists() {
            dev_config_path
        } else {
            config_path
        };

        let content = std::fs::read_to_string(&config_path)?;
        let config: T = toml::from_str(&content)?;
        Ok(config)
    }

    /// Loads the Dojo metadata from the workspace, where exactly one package with [[target.dojo]] is required.
    pub fn from_workspace(ws: &Workspace<'_>) -> Result<T> {
        let dojo_packages: Vec<Package> = ws
            .members()
            .filter(|package| {
                package.target(&TargetKind::new("dojo")).is_some()
                    && package.target(&TargetKind::new("lib")).is_none()
            })
            .collect();

        match dojo_packages.len() {
            0 => {
                ws.config()
                    .ui()
                    .warn("No package with [[target.dojo]] found in workspace.");
                Ok(Default::default())
            }
            1 => {
                let dojo_package = dojo_packages
                    .into_iter()
                    .next()
                    .expect("Package must exist as len is 1.");
                Ok(Self::from_package(&dojo_package, ws)?)
            }
            _ => {
                let error_message = "Multiple packages with [[target.dojo]] found in workspace. Please specify a package \
                 using --package option or maybe one of them must be declared as a [lib].";

                ws.config().ui().error(error_message);

                Err(anyhow::anyhow!(error_message))
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use scarb::core::Config;
    use std::fs;
    use tempfile::TempDir;

    /// Setups a default config for a given Scarb manifest path.
    fn setup_default_config(manifest_path: &Utf8PathBuf) -> Config {
        Config::builder(manifest_path).build().unwrap()
    }

    #[test]
    fn test_valid_config_from_workspace() {
        let temp_dir = TempDir::new().unwrap();
        let temp_path = temp_dir.path();

        let scarb_toml =
            Utf8PathBuf::from(temp_path.join("Scarb.toml").to_string_lossy().to_string());
        let dojo_dev = Utf8PathBuf::from(
            temp_path
                .join("dojo_dev.toml")
                .to_string_lossy()
                .to_string(),
        );

        let scarb_toml_content = r#"
[package]
name = "test_package"
version = "0.1.0"

[[target.dojo]]
"#;
        fs::write(&scarb_toml, scarb_toml_content).unwrap();

        let dojo_dev_content = r#"
[namespace]
default = "ns1"
"#;
        fs::write(&dojo_dev, dojo_dev_content).unwrap();

        let config = setup_default_config(&scarb_toml);
        let workspace = scarb::ops::read_workspace(&scarb_toml, &config).unwrap();

        let config: CompilerConfig = DojoConfigLoader::from_workspace(&workspace).unwrap();
        assert_eq!(config.namespace.default, "ns1");
    }

    #[test]
    #[should_panic]
    fn test_invalid_config_from_workspace() {
        let temp_dir = TempDir::new().unwrap();
        let temp_path = temp_dir.path();

        let scarb_toml =
            Utf8PathBuf::from(temp_path.join("Scarb.toml").to_string_lossy().to_string());
        let dojo_dev = Utf8PathBuf::from(
            temp_path
                .join("dojo_dev.toml")
                .to_string_lossy()
                .to_string(),
        );

        let scarb_toml_content = r#"
[package]
name = "test_package"
version = "0.1.0"

[[target.dojo]]
"#;
        fs::write(&scarb_toml, scarb_toml_content).unwrap();

        let dojo_dev_content = r#"
"#;
        fs::write(&dojo_dev, dojo_dev_content).unwrap();

        let config = setup_default_config(&scarb_toml);
        let workspace = scarb::ops::read_workspace(&scarb_toml, &config).unwrap();

        let _: CompilerConfig = DojoConfigLoader::from_workspace(&workspace).unwrap();
    }
}
