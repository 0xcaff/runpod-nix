# Runpod provides NVIDIA driver libraries such as libcuda.so in either
# /usr/lib/x86_64-linux-gnu or /usr/lib64, while Nix CUDA consumers look for
# them in /run/opengl-driver/lib. This creates symlinks in
# /run/opengl-driver/lib to make those libraries available where Nix consumers
# expect them.
{ ... }:
{
  config.runpod.startHooks = [ ''
    mkdir -p /run/opengl-driver/lib
    for src in /usr/lib/x86_64-linux-gnu /usr/lib64; do
      [ -d "$src" ] || continue
      for f in "$src"/*; do
        [ -e "$f" ] || continue
        ln -sf "$f" "/run/opengl-driver/lib/''${f##*/}"
      done
    done
  '' ];
}
