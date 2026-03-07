# Container-side support for Runpod web terminals.
#
# Runpod uses gotty to power the web terminal exposed by the "Enable web terminal"
# toggle in the console. This module adds the required tools to the container and
# removes the runtime-provided /usr/bin/gotty, which does not work in bare containers.
{ pkgs, ... }:
{
  config.runpod = {
    contents = [
      pkgs.gotty
      pkgs.gnused
    ];

    # /usr/bin/gotty is provided by the runpod runtime but it doesn't launch in
    # these bare containers. remove it to prevent accidental references
    startHooks = [ ''
      rm -f /usr/bin/gotty
    '' ];
  };
}
