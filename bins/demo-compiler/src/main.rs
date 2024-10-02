use std::env;
use std::process::exit;

use anyhow::Result;
use args::CompilerArgs;
use clap::Parser;
use dojo_compiler::compiler::{self, DojoCompiler};
use dojo_compiler::plugin::CairoPluginRepository;
use scarb::compiler::CompilerRepository;
use scarb::core::Config;
use scarb_ui::{OutputFormat, Ui};
use tracing::trace;

use crate::commands::Commands;

mod args;
mod commands;

fn main() {
    let args = CompilerArgs::parse();
    let _ = args.init_logging();
    let ui = Ui::new(args.ui_verbosity(), OutputFormat::Text);

    if let Err(err) = cli_main(args) {
        ui.anyhow(&err);
        exit(1);
    }
}

fn cli_main(args: CompilerArgs) -> Result<()> {
    let mut compilers = CompilerRepository::std();
    let cairo_plugins = CairoPluginRepository::default();

    match &args.command {
        Commands::Build(args) => {
            trace!("Adding DojoCompiler to compiler repository.");
            compilers
                .add(Box::new(DojoCompiler::new(args.output_debug_info)))
                .unwrap()
        }
        Commands::Dev(_) | Commands::Clean(_) => {
            trace!("Adding DojoCompiler to compiler repository.");
            compilers.add(Box::new(DojoCompiler::default())).unwrap()
        }
        _ => {}
    }

    let manifest_path = scarb::ops::find_manifest_path(args.manifest_path.as_deref())?;

    compiler::version::verify_cairo_version_compatibility(&manifest_path)?;

    let config = Config::builder(manifest_path.clone())
        .log_filter_directive(env::var_os("SCARB_LOG"))
        .profile(args.profile_spec.determine()?)
        .offline(args.offline)
        .cairo_plugins(cairo_plugins.into())
        .ui_verbosity(args.ui_verbosity())
        .compilers(compilers)
        .build()?;

    commands::run(args.command, &config)
}