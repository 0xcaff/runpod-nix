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
        ssh = ./modules/ssh.nix;
        nix-runtime = ./modules/nix-runtime.nix;
        env = ./modules/base/env.nix;
        base-env = ./modules/base/env.nix;
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
          full = mkImage {
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

          minimal = mkImage {
            name = "ghcr.io/0xcaff/runpod-nix";
            tag = "minimal";
            modules = [ ./modules/base/default.nix ];
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
        default = images.${system}.full;
        full = images.${system}.full;
        minimal = images.${system}.minimal;
      });

      apps = forDeploymentSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };
        in {
          deploy = {
            type = "app";
            program = "${pkgs.writeShellScript "deploy" ''
              set -e
              echo "Pushing image to ghcr.io/0xcaff/runpod-nix:latest..."
              ${pkgs.skopeo}/bin/skopeo copy --insecure-policy docker-archive:${defaultImages.full} docker://ghcr.io/0xcaff/runpod-nix:latest
            ''}";
          };
        }
      );
    };
}
