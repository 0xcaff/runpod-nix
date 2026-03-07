{
  description = "composable runpod images built with nix modules";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
  };

  outputs = { self, nixpkgs }:
    let
      supportedSystems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;

      pkgs-linux = import nixpkgs { system = "x86_64-linux"; };

      modulePaths = {
        base = ./modules/base/default.nix;
        base-patched-bin = ./modules/base/patched-bin.nix;
        options = ./modules/base/options.nix;
        base-options = ./modules/base/options.nix;
        ssh = ./modules/ssh.nix;
        nix-runtime = ./modules/nix-runtime.nix;
        env = ./modules/base/env.nix;
        base-env = ./modules/base/env.nix;
        gotty = ./modules/gotty.nix;
        tools = ./modules/tools.nix;
        host-libs = ./modules/base/host-libs.nix;
        base-host-libs = ./modules/base/host-libs.nix;
      };

      mkImage = import ./lib/mk-image.nix {
        pkgs = pkgs-linux;
        lib = pkgs-linux.lib;
        inherit nixpkgs;
      };

      fullImage = mkImage {
        name = "ghcr.io/0xcaff/runpod-nix";
        tag = "latest";
        modules = [
          ./modules/base/default.nix
          ./modules/tools.nix
          ./modules/ssh.nix
          ./modules/nix-runtime.nix
          ./modules/gotty.nix
        ];
      };

      minimalImage = mkImage {
        name = "ghcr.io/0xcaff/runpod-nix";
        tag = "minimal";
        modules = [ ./modules/base/default.nix ];
      };
    in {
      lib = {
        inherit mkImage modulePaths;
      };

      packages = forAllSystems (system: {
        default = fullImage;
        full = fullImage;
        minimal = minimalImage;
      });

      apps = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };
        in {
          deploy = {
            type = "app";
            program = "${pkgs.writeShellScript "deploy" ''
              set -e
              echo "Pushing image to ghcr.io/0xcaff/runpod-nix:latest..."
              ${pkgs.skopeo}/bin/skopeo copy --insecure-policy docker-archive:${fullImage} docker://ghcr.io/0xcaff/runpod-nix:latest
            ''}";
          };
        }
      );
    };
}
