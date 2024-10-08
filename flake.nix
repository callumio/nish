{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";

    fenix.inputs.nixpkgs.follows = "nixpkgs";
    fenix.url = "github:nix-community/fenix";

    crane.url = "github:ipetkov/crane";

    advisory-db = {
      url = "github:rustsec/advisory-db";
      flake = false;
    };

    systems.url = "github:nix-systems/default";

    treefmt-nix.url = "github:numtide/treefmt-nix";
    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";

    pre-commit-hooks = {
      url = "github:cachix/pre-commit-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs = {
    self,
    nixpkgs,
    flake-parts,
    ...
  } @ inputs:
    flake-parts.lib.mkFlake {inherit self inputs;} {
      systems = import inputs.systems;
      imports = [
        inputs.pre-commit-hooks.flakeModule
        inputs.treefmt-nix.flakeModule
      ];

      perSystem = {
        pkgs,
        inputs',
        self',
        config,
        ...
      }: let
        rustToolchain = inputs'.fenix.packages.fromToolchainFile {
          file = ./rust-toolchain.toml;
          sha256 = "sha256-VZZnlyP69+Y3crrLHQyJirqlHrTtGTsyiSnZB8jEvVo=";
        };
        craneLib = (inputs.crane.mkLib pkgs).overrideToolchain rustToolchain;
        src = craneLib.cleanCargoSource (craneLib.path ./.);

        nativeBuildInputs = with pkgs; [rustToolchain pkg-config];
        buildInputs = with pkgs; [udev];

        commonArgs = {
          inherit src buildInputs nativeBuildInputs;
        };

        cargoArtifacts = craneLib.buildDepsOnly commonArgs;
        bin = craneLib.buildPackage (commonArgs // {inherit cargoArtifacts;});
      in {
        _module.args.pkgs = inputs'.nixpkgs.legacyPackages.extend inputs.fenix.overlays.default;

        checks = {
          inherit bin;
          clippy = craneLib.cargoClippy (commonArgs
            // {
              inherit cargoArtifacts;
              cargoClippyExtraArgs = "--all-targets -- --deny warnings";
            });
          coverage = craneLib.cargoTarpaulin (commonArgs // {inherit cargoArtifacts;});
          fmt = craneLib.cargoFmt {inherit src;};
          audit = craneLib.cargoAudit {
            inherit src;
            inherit (inputs) advisory-db;
          };
        };
        packages = {
          default = bin;
        };

        devShells.default = craneLib.devShell {
          inherit (self') checks;
          inputsFrom = [config.pre-commit.devShell config.treefmt.build.devShell];
          packages = [];
        };

        pre-commit = {
          check.enable = false;
          settings.hooks = {
            alejandra.enable = true;
            deadnix.enable = true;
            rustfmt.enable = true;
          };
        };

        treefmt.config = {
          projectRootFile = "flake.nix";
          programs = {
            alejandra.enable = true;
            deadnix.enable = true;
            rustfmt.enable = true;
          };
        };
      };
    };

  nixConfig = {
    extra-substituters = ["https://callumio-public.cachix.org"];
    extra-trusted-public-keys = ["callumio-public.cachix.org-1:VucOSl7vh44GdqcILwMIeHlI0ufuAnHAl8cO1U/7yhg="];
  };
}
