use std::fs;

use anyhow::{Context, Result};
use camino::Utf8PathBuf;
use clap::Args;
use scarb::core::Config;
use scarb::ops;
use tracing::trace;

// TODO when porting manifests.
const BASE_DIR: &str = "base";
const MANIFESTS_DIR: &str = "manifests";

#[derive(Debug, Args)]
pub struct CleanArgs {
    #[arg(long)]
    #[arg(
        help = "Removes all the generated files, including scarb artifacts and ALL the \
                  manifests files."
    )]
    pub full: bool,

    #[arg(long)]
    #[arg(help = "Clean all profiles.")]
    pub all_profiles: bool,
}

impl CleanArgs {
    /// Cleans the manifests and abis files that are generated at build time.
    ///
    /// # Arguments
    ///
    /// * `profile_dir` - The directory where the profile files are located.
    pub fn clean_manifests(profile_dir: &Utf8PathBuf) -> Result<()> {
        trace!(?profile_dir, "Cleaning manifests.");
        let dirs = vec![profile_dir.join(BASE_DIR)];

        for d in dirs {
            if d.exists() {
                trace!(directory=?d, "Removing directory.");
                fs::remove_dir_all(d)?;
            }
        }

        Ok(())
    }

    pub fn run(self, config: &Config) -> Result<()> {
        let ws = scarb::ops::read_workspace(config.manifest_path(), config)?;
        trace!(ws=?ws, "Workspace read successfully.");

        let profile_names = if self.all_profiles {
            ws.profile_names()
        } else {
            vec![ws
                .current_profile()
                .expect("Scarb profile is expected at this point.")
                .to_string()]
        };

        for profile_name in profile_names {
            // Manifest path is always a file, we can unwrap safely to get the
            // parent folder.
            let manifest_dir = ws.manifest_path().parent().unwrap().to_path_buf();

            // By default, this command cleans the build manifests and scarb artifacts.
            trace!("Cleaning Scarb artifacts and build manifests.");

            {
                // copied from scarb::ops::clean since scarb cleans build file of all the profiles
                // we only want to clean build files for specified profile
                //
                // cleaning build files for all profiles would create inconsistency with the
                // manifest files in `manifests` directory
                let ws = ops::read_workspace(config.manifest_path(), config)?;
                let path = ws.target_dir().path_unchecked().join(&profile_name);
                if path.exists() {
                    fs::remove_dir_all(path).context("failed to clean generated artifacts")?;
                }
            }

            let profile_dir = manifest_dir.join(MANIFESTS_DIR).join(&profile_name);

            Self::clean_manifests(&profile_dir)?;

            if self.full && profile_dir.exists() {
                trace!(?profile_dir, "Removing entire profile directory.");
                fs::remove_dir_all(profile_dir)?;
            }
        }

        Ok(())
    }
}
