{ pkgs, ... }:
let
  profileFile = pkgs.writeTextDir "etc/profile" ''
    if [ -f /etc/rp_environment ]; then
      . /etc/rp_environment
    fi

    if [ -d /etc/profile.d ]; then
      for f in /etc/profile.d/*.sh; do
        [ -r "$f" ] || continue
        . "$f"
      done
    fi
  '';

  rootBashrc = pkgs.writeTextDir "root/.bashrc" ''
    [ -f /etc/profile ] && . /etc/profile
  '';

  rootProfile = pkgs.writeTextDir "root/.profile" ''
    [ -f /etc/profile ] && . /etc/profile
  '';
in {
  config.runpod = {
    contents = [
      profileFile
      rootBashrc
      rootProfile
    ];

    startHooks = [ ''
      echo "Exporting environment variables..."
      while IFS='=' read -r -d $'\0' name value; do
        if [[ "$name" != "PATH" ]]; then
          printf "export %s=%q\n" "$name" "$value"
        fi
      done < <(env -0) > /etc/rp_environment
    '' ];
  };
}
