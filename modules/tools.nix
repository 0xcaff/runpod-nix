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
