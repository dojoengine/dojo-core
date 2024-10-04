use core::fmt;

use anyhow::Result;
use clap::Subcommand;
use scarb::core::Config;

pub(crate) mod build;
pub(crate) mod clean;
pub(crate) mod dev;
pub(crate) mod test;

use build::BuildArgs;
use clean::CleanArgs;
use dev::DevArgs;
use test::TestArgs;

use tracing::info_span;

#[derive(Debug, Subcommand)]
pub enum Commands {
    #[command(about = "Build the world, generating the necessary artifacts for deployment")]
    Build(BuildArgs),
    #[command(about = "Remove generated artifacts, manifests and abis")]
    Clean(CleanArgs),
    #[command(about = "Developer mode: watcher for building and migration")]
    Dev(DevArgs),
    #[command(about = "Test the project's smart contracts")]
    Test(TestArgs),
}

impl fmt::Display for Commands {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Commands::Build(_) => write!(f, "Build"),
            Commands::Clean(_) => write!(f, "Clean"),
            Commands::Dev(_) => write!(f, "Dev"),
            Commands::Test(_) => write!(f, "Test"),
        }
    }
}

pub fn run(command: Commands, config: &Config) -> Result<()> {
    let name = command.to_string();
    let span = info_span!("Subcommand", name);
    let _span = span.enter();

    // use `.map(|_| ())` to avoid returning a value here but still
    // useful to write tests for each command.

    match command {
        Commands::Clean(args) => args.run(config),
        Commands::Test(args) => args.run(config),
        Commands::Build(args) => args.run(config),
        Commands::Dev(args) => args.run(config),
    }
}
