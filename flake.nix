{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";

    rust-overlay.url = "github:oxalica/rust-overlay";
    rust-overlay.inputs.nixpkgs.follows = "nixpkgs";

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
        config,
        ...
      }: let
        rustToolchain = pkgs.rust-bin.fromRustupToolchainFile ./rust-toolchain.toml;
        rustPlatform = pkgs.makeRustPlatform {
          cargo = rustToolchain;
          rustc = rustToolchain;
        };

        bin = rustPlatform.buildRustPackage {
          pname = "nish";
          version = (builtins.fromTOML (builtins.readFile ./Cargo.toml)).package.version;
          src = ./.;
          cargoLock.lockFile = ./Cargo.lock;
          nativeBuildInputs = with pkgs; [pkg-config];
          buildInputs = with pkgs; [udev];
        };
      in {
        _module.args.pkgs = inputs'.nixpkgs.legacyPackages.extend inputs.rust-overlay.overlays.default;

        checks = {
          inherit bin;
        };
        packages = {
          default = bin;
        };

        devShells.default = pkgs.mkShell {
          inputsFrom = [config.pre-commit.devShell config.treefmt.build.devShell];
          packages = [rustToolchain pkgs.pkg-config pkgs.udev];
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
