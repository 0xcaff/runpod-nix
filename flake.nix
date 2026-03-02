{
  description = "a minimal, runpod base image built with nix";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
  };

  outputs = { self, nixpkgs }:
    let
      supportedSystems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;

      pkgs-linux = import nixpkgs { system = "x86_64-linux"; };

      sshd_config = pkgs-linux.writeText "sshd_config" ''
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

      startScript = pkgs-linux.writeShellApplication {
        name = "start.sh";
        runtimeInputs = with pkgs-linux; [ coreutils gnugrep gawk bash procps ];
        text = ''
          echo "Pod Started"

          if [[ -n "''${PUBLIC_KEY:-}" ]]; then
              echo "Setting up SSH..."
              mkdir -p ~/.ssh
              echo "$PUBLIC_KEY" >> ~/.ssh/authorized_keys
              chmod 700 -R ~/.ssh
              ${pkgs-linux.openssh}/bin/ssh-keygen -A >/dev/null 2>&1 || true
              ${pkgs-linux.openssh}/bin/sshd -e -f ${sshd_config}
          fi

          echo "Exporting environment variables..."
          while IFS='=' read -r -d "" name value; do
              # Don't export PATH directly to avoid clobbering nix shell paths
              if [[ "$name" != "PATH" ]]; then
                  printf "export %s=%q\n" "$name" "$value"
              fi
          done < <(env -0) > /etc/rp_environment

          # Create system-wide profile
          cat << 'EOF' > /etc/profile
          # Load RunPod environment variables
          if [ -f /etc/rp_environment ]; then
              . /etc/rp_environment
          fi

          # Ensure the persistent Nix profile is on the PATH
          export PATH="/workspace/nix-profiles/profile/bin:/nix/var/nix/profiles/default/bin:$PATH"

          # Globally allow unfree packages (like CUDA)
          export NIXPKGS_ALLOW_UNFREE=1

          # Expose RunPod NVIDIA drivers to Nix packages
          export LD_LIBRARY_PATH="/usr/lib64:$LD_LIBRARY_PATH"
          EOF

          # Ensure all bash shells (login and non-login) load the profile
          echo ". /etc/profile" > /root/.bashrc
          echo ". /etc/profile" > /root/.profile

          echo "Setting up persistent Nix profile..."
          mkdir -p /workspace/nix-profiles
          mkdir -p /nix/var/nix/profiles/per-user
          rm -f /nix/var/nix/profiles/per-user/root
          ln -s /workspace/nix-profiles /nix/var/nix/profiles/per-user/root

          # Configure max-jobs dynamically based on RunPod CPU limits
          if [[ -n "''${RUNPOD_CPU_COUNT:-}" ]]; then
              echo "max-jobs = $RUNPOD_CPU_COUNT" >> /etc/nix/nix.conf
              echo "cores = $RUNPOD_CPU_COUNT" >> /etc/nix/nix.conf
          fi

          echo "Start script(s) finished, Pod is ready to use."
          
          exec sleep infinity
        '';
      };

      image = pkgs-linux.dockerTools.buildLayeredImage {
        name = "ghcr.io/0xcaff/runpod-nix";
        tag = "latest";
        
        contents = with pkgs-linux; [
          bashInteractive
          coreutils
          openssh
          gnugrep
          gawk
          procps
          curl
          jq
          nix
          cacert
        ];

        config = {
          Cmd = [ "${startScript}/bin/start.sh" ]; 
          Env = [
            "USER=root"
            "HOME=/root"
            "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
            "RP_WORKSPACE=/workspace"
            "NIX_PAGER=cat"
            "SSL_CERT_FILE=${pkgs-linux.cacert}/etc/ssl/certs/ca-bundle.crt"
            "NIX_SSL_CERT_FILE=${pkgs-linux.cacert}/etc/ssl/certs/ca-bundle.crt"
          ];
          ExposedPorts = { "22/tcp" = {}; };
          WorkingDir = "/workspace";
        };

        extraCommands = ''
          mkdir -p root etc/ssh etc/nix var/empty var/run/sshd usr/sbin bin tmp
          chmod 755 var/empty var/run/sshd
          chmod 1777 tmp

          # Configure Nix to run properly in a single-user Docker environment
          echo "experimental-features = nix-command flakes" > etc/nix/nix.conf
          echo "build-users-group =" >> etc/nix/nix.conf
          
          # Add CUDA Cachix globally
          echo "extra-substituters = https://cuda-maintainers.cachix.org" >> etc/nix/nix.conf
          echo "extra-trusted-public-keys = cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUPwNQQq2x2PuC1tGi7C8Y=" >> etc/nix/nix.conf

          echo "hosts: files dns" > etc/nsswitch.conf
          
          echo "root:x:0:0:root:/root:/bin/bash" > etc/passwd
          echo "sshd:x:100:65534:Privilege-separated SSH:/var/empty:/sbin/nologin" >> etc/passwd
          echo "root:x:0:" > etc/group
          echo "sshd:x:100:" >> etc/group
        '';
      };

    in {
      packages = forAllSystems (system: {
        default = image;
      });

      apps = forAllSystems (system: 
        let 
          pkgs = import nixpkgs { inherit system; };
        in {
          deploy = {
            type = "app";
            program = "${pkgs.writeShellScript "deploy" ''
              set -e
              echo "Pushing image to ghcr.io/0xcaff/runpod-nix:latest..."
              ${pkgs.skopeo}/bin/skopeo copy docker-archive:${image} docker://ghcr.io/0xcaff/runpod-nix:latest
            ''}";
          };
        }
      );
    };
}
