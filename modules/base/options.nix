{ lib, ... }:
let
  inherit (lib) mkOption types;
in {
  options.runpod = {
    contents = mkOption {
      type = types.listOf types.package;
      default = [];
      description = "Packages/files that should be present in the image rootfs.";
    };

    env = mkOption {
      type = types.attrsOf types.str;
      default = {};
      description = "Container environment variables.";
    };

    startHooks = mkOption {
      type = types.listOf types.lines;
      default = [];
      description = "Shell snippets appended into generated start.sh.";
    };

    extraCommands = mkOption {
      type = types.listOf types.lines;
      default = [];
      description = "dockerTools extraCommands fragments.";
    };

    exposedPorts = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "Ports to expose in OCI config.";
    };

    entrypoint = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "Optional container entrypoint.";
    };
  };
}
