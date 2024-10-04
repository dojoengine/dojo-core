use anyhow::Result;
use clap::Args;
use dojo_compiler::compiler::DojoCompiler;
use dojo_compiler::scarb_extensions::ProfileSpec;
use scarb::core::Config;
use tracing::trace;

#[derive(Debug, Args)]
pub struct CleanArgs {
    #[arg(long)]
    #[arg(help = "Removes the scarb artifacts AND the dojo compiler manifests.")]
    pub remove_dojo_manifests: bool,

    #[arg(long)]
    #[arg(help = "Clean all profiles.")]
    pub all_profiles: bool,
}

impl CleanArgs {
    pub fn run(self, config: &Config) -> Result<()> {
        let ws = scarb::ops::read_workspace(config.manifest_path(), config)?;
        trace!(ws=?ws, "Workspace read successfully.");

        let profile_spec = if self.all_profiles {
            ProfileSpec::All
        } else {
            ProfileSpec::WorkspaceCurrent
        };

        DojoCompiler::clean(config, profile_spec, self.remove_dojo_manifests)?;

        Ok(())
    }
}
