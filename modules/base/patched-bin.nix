{ lib, pkgs, ... }:
let
  baseProfileEnv = pkgs.writeTextDir "etc/profile.d/base-runtime.sh" ''
    export PATH="/run/patched-bin:$PATH"
  '';
in {
  config.runpod = {
    contents = [
      pkgs.patchelf
      baseProfileEnv
    ];

    env = {
      PATH = "/run/patched-bin:/usr/bin:/sbin:/bin";
    };

    startHooks = lib.mkMerge [
      (lib.mkBefore [ ''
        rm -rf /etc/ld.so.conf.d/
        mkdir -p /run/patched-bin
        export PATH="/run/patched-bin:$PATH"
      '' ])
      (lib.mkAfter [ ''
        echo "Patching /usr/bin ELFs..."
        loader="${pkgs.glibc}/lib/ld-linux-x86-64.so.2"
        rpath="/usr/lib/x86_64-linux-gnu:/usr/lib64:/run/opengl-driver/lib"

        if [ -d /usr/bin ]; then
          for bin in /usr/bin/*; do
            [[ -f "$bin" && -x "$bin" ]] || continue
            if ${pkgs.patchelf}/bin/patchelf --print-interpreter "$bin" >/dev/null 2>&1; then
              if ! ${pkgs.patchelf}/bin/patchelf --set-interpreter "$loader" --set-rpath "$rpath" "$bin" 2>/dev/null; then
                patched="/run/patched-bin/$(basename "$bin")"
                if cp "$bin" "$patched" 2>/dev/null; then
                  chmod 0755 "$patched" || true
                  ${pkgs.patchelf}/bin/patchelf --set-interpreter "$loader" --set-rpath "$rpath" "$patched" 2>/dev/null || true
                fi
              fi
            fi
          done
        fi
      '' ])
    ];
  };
}
