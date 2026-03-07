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
