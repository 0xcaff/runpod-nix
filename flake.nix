{
  description = "composable runpod images built with nix modules";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
  };

  outputs = { self, nixpkgs }:
    let
      targetSystems = [ "x86_64-linux" ];
      deploymentSystems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      forTargetSystems = nixpkgs.lib.genAttrs targetSystems;
      forDeploymentSystems = nixpkgs.lib.genAttrs deploymentSystems;
      defaultTargetSystem = builtins.head targetSystems;

      modulePaths = {
        base = ./modules/base/default.nix;
        base-patched-bin = ./modules/base/patched-bin.nix;
        options = ./modules/base/options.nix;
        base-options = ./modules/base/options.nix;
        ssh = ./modules/ssh/default.nix;
        ssh-module = ./modules/ssh/ssh.nix;
        ssh-env = ./modules/ssh/env.nix;
        nix-runtime = ./modules/nix-runtime.nix;
        env = ./modules/ssh/env.nix;
        gotty = ./modules/gotty.nix;
        tools = ./modules/tools.nix;
        host-libs = ./modules/base/host-libs.nix;
        base-host-libs = ./modules/base/host-libs.nix;
      };

      mkImagesForSystem = system:
        let
          pkgs = import nixpkgs { inherit system; };
          mkImage = import ./lib/mk-image.nix { inherit pkgs; };
        in {
          # Minimal Runpod runtime image. Use this for serving. Weights ~71MB
          # compressed (~282 MB uncompressed).
          base = mkImage {
            name = "ghcr.io/0xcaff/runpod-nix";
            tag = "base";
            modules = [ ./modules/base/default.nix ];
          };

          # Full interactive Runpod image. Use this for development and
          # interactive debugging. Weighs ~300MB compressed (~1GB
          # uncompressed).
          #
          # * full nix cli available
          # * ssh access via dedicated port
          # * GoTTY support for Runpod Web Terminal
          interactive = mkImage {
            name = "ghcr.io/0xcaff/runpod-nix";
            tag = "interactive";
            modules = [
              ./modules/base/default.nix
              ./modules/tools.nix
              ./modules/ssh/default.nix
              ./modules/nix-runtime.nix
              ./modules/gotty.nix
            ];
          };
        };

      images = forTargetSystems mkImagesForSystem;
      defaultImages = images.${defaultTargetSystem};
    in
    {
      lib = {
        inherit modulePaths;
        mkImage = import ./lib/mk-image.nix;
      };

      inherit images;

      packages = forTargetSystems (system: {
        default = images.${system}.interactive;
        interactive = images.${system}.interactive;
        base = images.${system}.base;
      });

      apps = forDeploymentSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };
        in {
          deploy = {
            type = "app";
            program = "${pkgs.writeShellScript "deploy" ''
              set -e
              echo "Pushing image to ghcr.io/0xcaff/runpod-nix:interactive..."
              ${pkgs.skopeo}/bin/skopeo copy --insecure-policy docker-archive:${defaultImages.interactive} docker://ghcr.io/0xcaff/runpod-nix:interactive
            ''}";
          };
        }
      );
    };
}
