# runpod-nix

tools for building images for [runpod] with nix

## motivation

nix is a tool for defining the entire software environment for a workload in
one place. from the application to the runtime level dependencies (python
packages or node packages) to native libraries to helper binaries (like ffmpeg
or protoc). where tools like docker trade off composibility for isolation and tools like uv miss parts of the build graph nix encodes the whole thing.

runpod has built a great platform for renting GPUs. its very cheap, containers start up fast. there are APIs. the web interface make sense and things just work.

these are tools for packaging your nix applications into runpod images.

## usage

### building an image for your app

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    runpod-nix.url = "github:0xcaff/runpod-nix";
  };

  outputs = { self, nixpkgs, runpod-nix }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
      mkImage = runpod-nix.lib.mkImage { inherit pkgs; };
      modules = runpod-nix.lib.modulePaths;
      app = pkgs.writeShellApplication {
        name = "my-app";
        text = ''
          exec python -m http.server 3000
        '';
      };
    in {
      packages.${system}.app = mkImage {
        name = "ghcr.io/example/my-app";
        tag = "latest";
        modules = [
          modules.base # use modules.interactive for additional tools
          ({ ... }: {
            config.runpod = {
              contents = [ app pkgs.python311 ];
              exposedPorts = [ "3000/tcp" ];
              startHooks = [ ''
                ${app}/bin/my-app &
              '' ];
            };
          })
        ];
      };
    };
}
```

build it with:

```bash
nix build .#packages.x86_64-linux.app
```

then push the resulting image archive to a registry:

```bash
skopeo copy --insecure-policy docker-archive:./result docker://ghcr.io/example/my-app:latest
```

to launch it on runpod:

- create a pod template with container image `ghcr.io/example/my-app:latest`
- expose HTTP port `3000`, since the example app listens on `0.0.0.0:3000`
- attach a network if you have state which you'd like to survive restarts
- deploy a pod from that template
- open the app at `https://<pod-id>-3000.proxy.runpod.net`

see runpod docs for [custom templates](https://docs.runpod.io/pods/templates/create-custom-template)
and [exposing ports](https://docs.runpod.io/pods/configuration/expose-ports).

### using the interactive image for development

if you just want a shell on a gpu machine, start from
`ghcr.io/0xcaff/runpod-nix:interactive`.

to launch it on runpod:

- create a pod or pod template with image `ghcr.io/0xcaff/runpod-nix-interactive`
- expose TCP port `22` if you want direct SSH access
- add a volume you want the `/workspace` folder and `nix profile add` installs to persist across reboots
- once the pod is running, open the web terminal from the connect menu or use
  the SSH command shown there

see runpod docs for [SSH access](https://docs.runpod.io/pods/configuration/use-ssh),
[connection options](https://docs.runpod.io/pods/connect-to-a-pod), and
[pod environment variables](https://docs.runpod.io/pods/templates/environment-variables).

it includes `nix`, `git`, basic shell tooling, ssh support, `nvidia-smi` and friends, and gotty support
for the runpod web terminal.

typical workflow:

```bash
nix profile add nixpkgs#python311 nixpkgs#tmux nixpkgs#uv
git clone https://github.com/your-org/your-repo
cd your-repo
nix develop
```

profile installs go into `$RP_WORKSPACE/nix-profiles` when `RP_WORKSPACE` is
set. otherwise they fall back to `/root/nix-profiles`.

[runpod]: https://runpod.io/