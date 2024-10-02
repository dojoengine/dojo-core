use anyhow::Result;
use camino::Utf8PathBuf;
use clap::Parser;
use scarb::compiler::Profile;
use scarb_ui::Verbosity;
use smol_str::SmolStr;
use tracing::level_filters::LevelFilter;
use tracing_log::{AsTrace, LogTracer};
use tracing_subscriber::FmtSubscriber;

use crate::commands::Commands;

#[derive(Parser, Debug)]
pub struct CompilerArgs {
    /// Override path to a directory containing a Scarb.toml file.
    #[arg(
        short,
        long,
        global = true,
        help = "Override path to a directory containing a Scarb.toml file."
    )]
    pub manifest_path: Option<Utf8PathBuf>,

    /// Specify the profile to use, defaults to `dev`.
    #[command(flatten)]
    pub profile_spec: ProfileSpec,

    /// Logging verbosity.
    #[command(flatten)]
    pub verbose: clap_verbosity_flag::Verbosity,

    /// Run without accessing the network for scarb dependencies.
    #[arg(short, long, help = "Run without accessing the network.")]
    pub offline: bool,

    #[command(subcommand)]
    pub command: Commands,
}

impl CompilerArgs {
    pub fn ui_verbosity(&self) -> Verbosity {
        let filter = self.verbose.log_level_filter().as_trace();
        if filter >= LevelFilter::WARN {
            Verbosity::Verbose
        } else if filter > LevelFilter::OFF {
            Verbosity::Normal
        } else {
            Verbosity::Quiet
        }
    }

    pub fn init_logging(&self) -> Result<(), Box<dyn std::error::Error>> {
        const DEFAULT_LOG_FILTER: &str = "info,hyper=off,scarb=off,salsa=off";

        LogTracer::init()?;

        let subscriber = FmtSubscriber::builder()
            .with_env_filter(
                tracing_subscriber::EnvFilter::try_from_default_env()
                    .unwrap_or_else(|_| tracing_subscriber::EnvFilter::new(DEFAULT_LOG_FILTER)),
            )
            .finish();

        Ok(tracing::subscriber::set_global_default(subscriber)?)
    }
}

/// Profile specifier.
#[derive(Parser, Clone, Debug)]
#[group(multiple = false)]
pub struct ProfileSpec {
    #[arg(short = 'P', long, global = true, group = "profiles")]
    #[arg(help = "Specify profile to use by name.")]
    pub profile: Option<SmolStr>,

    #[arg(long, hide_short_help = true, global = true, group = "profiles")]
    #[arg(help = "Use release profile.")]
    pub release: bool,

    #[arg(long, hide_short_help = true, global = true, group = "profiles")]
    #[arg(help = "Use dev profile.")]
    pub dev: bool,
}

impl ProfileSpec {
    pub fn determine(&self) -> Result<Profile> {
        Ok(match &self {
            Self { release: true, .. } => Profile::RELEASE,
            Self { dev: true, .. } => Profile::DEV,
            Self {
                profile: Some(profile),
                ..
            } => Profile::new(profile.clone())?,
            _ => Profile::default(),
        })
    }
}