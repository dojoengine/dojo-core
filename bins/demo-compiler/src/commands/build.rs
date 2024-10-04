use anyhow::Result;
use clap::{Args, Parser};
use dojo_compiler::compiler::DojoCompiler;
use scarb::core::Config;
use scarb_ui::args::{FeaturesSpec, PackagesFilter};

#[derive(Debug, Args)]
pub struct BuildArgs {
    /// Specify the features to activate.
    #[command(flatten)]
    pub features: FeaturesSpec,

    /// Specify packages to build.
    #[command(flatten)]
    pub packages: Option<PackagesFilter>,

    #[arg(long)]
    #[arg(help = "Output the Sierra debug information for the compiled contracts.")]
    pub output_debug_info: bool,
}

impl BuildArgs {
    pub fn run(self, config: &Config) -> Result<()> {
        DojoCompiler::compile_workspace(config, self.packages, self.features)
    }
}

impl Default for BuildArgs {
    fn default() -> Self {
        // use the clap defaults
        let features = FeaturesSpec::parse_from([""]);

        Self {
            features,
            packages: None,
            output_debug_info: false,
        }
    }
}
