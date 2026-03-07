{ pkgs, ... }:
let
  sshdConfig = pkgs.writeText "sshd_config" ''
    Port 22
    PermitRootLogin yes
    PubkeyAuthentication yes
    AuthorizedKeysFile .ssh/authorized_keys
    PasswordAuthentication no
    ChallengeResponseAuthentication no
    UsePAM no
    Subsystem sftp internal-sftp
    HostKey /etc/ssh/ssh_host_rsa_key
    HostKey /etc/ssh/ssh_host_ed25519_key
  '';

  passwdFile = pkgs.writeTextDir "etc/passwd" ''
    root:x:0:0:root:/root:/bin/bash
    sshd:x:100:65534:Privilege-separated SSH:/var/empty:/sbin/nologin
  '';

  groupFile = pkgs.writeTextDir "etc/group" ''
    root:x:0:
    sshd:x:100:
  '';
in {
  config.runpod = {
    contents = [
      pkgs.openssh
      passwdFile
      groupFile
    ];

    exposedPorts = [ "22/tcp" ];

    startHooks = [ ''
      if [[ -n "''${PUBLIC_KEY:-}" ]]; then
        echo "Setting up SSH..."
        mkdir -p /root/.ssh
        printf '%s\n' "$PUBLIC_KEY" >> /root/.ssh/authorized_keys
        chmod 700 /root/.ssh
        chmod 600 /root/.ssh/authorized_keys
        ${pkgs.openssh}/bin/ssh-keygen -A >/dev/null 2>&1 || true
        ${pkgs.openssh}/bin/sshd -e -f ${sshdConfig}
      fi
    '' ];

    extraCommands = [
      ''
        mkdir -p etc/ssh var/empty var/run/sshd
        chmod 755 var/empty var/run/sshd
      ''
    ];
  };
}
