use clap::Parser;
use runix::{
    arguments::{
        eval::EvaluationArgs, flake::FlakeArgs, source::SourceArgs, InstallablesArgs, NixArgs,
    },
    command::Shell,
    default::NixCommandLine,
    installable::Installable,
    Run,
};

#[derive(Parser, Debug)]
#[command(version, about)]
struct Args {
    /// Enables unfree packages, if not already allowed by the local Nix config
    #[arg(short = 'u', long, required = false)]
    allow_unfree: bool,

    /// List of packages to include in the shell.
    ///
    /// <package> to implicitly use nixpkgs
    ///
    /// <flake#package> to use a different flake
    #[arg(value_parser = preprocess, required = true)]
    pkgs: Vec<Installable>,
}

fn preprocess(s: &str) -> Result<Installable, String> {
    Ok(Installable::from(if s.contains('#') {
        s.to_owned()
    } else {
        format!("nixpkgs#{s}")
    }))
}

#[tokio::main]
async fn main() -> Result<(), runix::default::NixCommandLineRunError> {
    let cli = Args::parse();
    std::env::set_var("NIXPKGS_ALLOW_UNFREE", "1");
    Shell {
        flake: FlakeArgs::default(),
        eval: EvaluationArgs {
            impure: cli.allow_unfree.into(),
        },
        source: SourceArgs::default(),
        installables: InstallablesArgs::from(cli.pkgs),
    }
    .run(&NixCommandLine::default(), &NixArgs::default())
    .await
}
