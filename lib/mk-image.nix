{ pkgs, lib, nixpkgs }:
{ name
, tag ? "latest"
, modules ? []
}:
let
  eval = lib.evalModules {
    specialArgs = { inherit pkgs lib nixpkgs runpodImageEnv; };
    modules = modules;
  };

  cfg = eval.config.runpod;

  startScript = pkgs.writeShellApplication {
    name = "start.sh";
    text = ''
      set -euo pipefail

      echo "Pod Started"
      ${lib.concatStringsSep "\n\n" cfg.startHooks}
      echo "Start script(s) finished, Pod is ready to use."

      exec sleep infinity
    '';
  };

  envBundle = pkgs.buildEnv {
    name = "${lib.strings.sanitizeDerivationName name}-env";
    paths = cfg.contents ++ [ startScript ];
  };

  runpodImageEnv = envBundle;

  imageConfig = {
    Cmd = [ "${startScript}/bin/start.sh" ];
    Env = lib.mapAttrsToList (k: v: "${k}=${v}") cfg.env;
    ExposedPorts = lib.genAttrs cfg.exposedPorts (_: {});
  } // lib.optionalAttrs (cfg.entrypoint != []) {
    Entrypoint = cfg.entrypoint;
  };
in
pkgs.dockerTools.buildLayeredImage {
  inherit name tag;

  contents = envBundle;
  config = imageConfig;

  extraCommands = lib.concatStringsSep "\n\n" cfg.extraCommands;
}
