# Useful tools for interactive use.
{ pkgs, ... }:
{
  config.runpod.contents = with pkgs; [
    gnugrep
    gawk
    procps
    curl
    jq
  ];
}
