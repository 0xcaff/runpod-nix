# Useful tools for interactive use.
{ pkgs, ... }:
{
  config.runpod.contents = with pkgs; [
    gnugrep
    gawk
    findutils
    which
    procps
    curl
    jq
    tree
    vim
    tmux
  ];
}
