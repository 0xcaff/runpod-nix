# Runpod provides NVIDIA driver libraries such as libcuda.so in
# /usr/lib/x86_64-linux-gnu, while Nix CUDA consumers look for them in
# /run/opengl-driver/lib. This creates symlinks in /run/opengl-driver/lib to
# make those libraries available where Nix consumers expect them.
{ ... }:
{
  config.runpod.startHooks = [ ''
    mkdir -p /run/opengl-driver/lib
    if [ -d /usr/lib/x86_64-linux-gnu ]; then
      for f in /usr/lib/x86_64-linux-gnu/*; do
        [ -e "$f" ] || continue
        ln -sf "$f" "/run/opengl-driver/lib/$(basename "$f")"
      done
    fi
  '' ];
}
