{ pkgs, ... }:
{
  config.runpod = {
    contents = [
      pkgs.gotty
      pkgs.gnused
    ];

    startHooks = [ ''
      rm -f /usr/bin/gotty
    '' ];
  };
}
