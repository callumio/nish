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
    /// List of packages to include in the shell.
    ///
    /// <package> to implicitly use nixpkgs
    ///
    /// <flake#package> to use a different flake
    #[arg(value_parser = preprocess)]
    pkgs: Vec<Installable>,
}

fn preprocess(s: &str) -> Result<Installable, String> {
    Ok(Installable::from(if s.contains('#') {
        s.to_owned()
    } else {
        format!("nixpkgs#{}", s)
    }))
}

#[tokio::main]
async fn main() -> Result<(), runix::default::NixCommandLineRunError> {
    let cli = Args::parse();
    Shell {
        flake: FlakeArgs::default(),
        eval: EvaluationArgs::default(),
        source: SourceArgs::default(),
        installables: InstallablesArgs::from(cli.pkgs),
    }
    .run(&NixCommandLine::default(), &NixArgs::default())
    .await
}
