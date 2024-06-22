{
  description = "Pulse development environment";

  inputs = {
    nixpkgs.url = "nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";

    mprocs = {
      url = "github:pvolok/mprocs/eabc95fd215d8de0439d3f5bd805b57c69a2c2d8";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, flake-utils, mprocs }:
    flake-utils.lib.eachSystem ["x86_64-linux" "x86_64-darwin" "aarch64-darwin"] (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;  # Allow unfree package: mongodb
        };

        pulse = import ./nix/builder.nix {
          inherit pkgs;
        } {};

        pulseVimPlugin = pkgs.vimUtils.buildVimPlugin {
          name = "pulse-vim-plugin";
          version = pulse.version;
          src = pkgs.lib.cleanSourceWith {
            src = ./.;
            filter = path: type: (pkgs.lib.hasPrefix (toString ./. + "/plugin") path);
          };
          dontBuild = true;
          postInstall = ''
            substituteInPlace $out/plugin/pulse.vim \
              --replace-fail "['pulse-client']" "['${pulse}/bin/pulse-client']" \
              --replace-quiet "system('uuidgen')" "system('${pkgs.util-linux}/bin/uuidgen')"
          '';
        };

      in {
        packages = {
          default = pulse;
          pulse = pulse;
          pulseVimPlugin = pulseVimPlugin;
        };

        devShell = import ./nix/devshell.nix {
          inherit pkgs mprocs;
        };

        nixosModules.default = { config, lib, pkgs, ... }: import ./nix/module.nix {
          inherit config lib pkgs;
        };
      }
    );
}
