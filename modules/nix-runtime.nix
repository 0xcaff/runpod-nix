# Configures the container for interactive Nix usage.
#
# This includes:
# - Nix tooling and PATH setup
# - substituters for the standard and CUDA caches
# - nix-command and flakes enabled in nix.conf
# - GC roots to preserve image dependencies
# - max-jobs and cores derived from the container CPU count
# - a pinned nixpkgs registry entry matching this project
{ lib, pkgs, runpodImageEnv, ... }:
let
  nixProfileEnv = pkgs.writeTextDir "etc/profile.d/nix-runtime.sh" ''
    runpod_nix_profile_root="''${RP_WORKSPACE:-/root}"
    runpod_nix_profile_dir="$runpod_nix_profile_root/nix-profiles"
    export PATH="$runpod_nix_profile_dir/profile/bin:/nix/var/nix/profiles/default/bin:$PATH"
    export NIXPKGS_ALLOW_UNFREE=1
  '';

  nixConf = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];

    sandbox = false;

    build-users-group = "";

    substituters = [
      "https://cache.nixos.org"
      "https://cache.nixos-cuda.org"
    ];

    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M="
    ];
  };

  nixConfEncoded = pkgs.writeTextDir "etc/nix/nix.conf" (
    lib.generators.toKeyValue {
      mkKeyValue = lib.generators.mkKeyValueDefault {
        mkValueString = v:
          if builtins.isList v then lib.concatStringsSep " " v
          else if builtins.isBool v then (if v then "true" else "false")
          else builtins.toString v;
      } " = ";
    } nixConf
  );

  registryFile = pkgs.writeText "registry.json" (builtins.toJSON {
    version = 2;
    flakes = [
      {
        from = { id = "nixpkgs"; type = "indirect"; };
        to = { type = "path"; path = pkgs.path; };
      }
    ];
  });
in {
  config.runpod = {
    contents = [
      pkgs.nix
      pkgs.git
      nixProfileEnv
    ];

    env = {
      NIX_PAGER = "cat";
      NIX_SSL_CERT_FILE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
    };

    startHooks = [
      ''
        runpod_nix_profile_root="''${RP_WORKSPACE:-/root}"
        runpod_nix_profile_dir="$runpod_nix_profile_root/nix-profiles"
        mkdir -p "$runpod_nix_profile_dir"
        mkdir -p /nix/var/nix/profiles/per-user
        rm -rf /nix/var/nix/profiles/per-user/root
        ln -s "$runpod_nix_profile_dir" /nix/var/nix/profiles/per-user/root
      ''
      ''
        if [[ -n "''${RUNPOD_CPU_COUNT:-}" ]]; then
          runpod_cpu_nix_config="$(printf 'max-jobs = %s\ncores = %s' "''${RUNPOD_CPU_COUNT}" "''${RUNPOD_CPU_COUNT}")"
          if [[ -n "''${NIX_CONFIG:-}" ]]; then
            export NIX_CONFIG="$NIX_CONFIG"$'\n'"$runpod_cpu_nix_config"
          else
            export NIX_CONFIG="$runpod_cpu_nix_config"
          fi
        fi
      ''
    ];

    extraCommands = [
      ''
        mkdir -p nix/var/nix/gcroots
        ln -s ${runpodImageEnv} nix/var/nix/gcroots/base-env
      ''
      ''
        rm -rf etc/nix
        mkdir -p etc/nix
        cp ${registryFile} etc/nix/registry.json
        cp ${nixConfEncoded}/etc/nix/nix.conf etc/nix/nix.conf
      ''
    ];
  };
}
