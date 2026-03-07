# runpod-nix

<p>
  <a href="https://console.runpod.io/deploy?template=d5w42uggft&ref=zchz96mv">
    <img alt="Runpod NVIDIA template" src="https://img.shields.io/badge/Runpod%20NVIDIA-Deploy-76B900?logo=nvidia&logoColor=white">
  </a>
  <a href="https://console.runpod.io/deploy?template=cuyqr7ggld&ref=zchz96mv">
    <img alt="Runpod CPU template" src="https://img.shields.io/badge/Runpod%20CPU-Deploy-0F62FE?logo=linux&logoColor=white">
  </a>
</p>

tools for building images for [runpod] with nix

> ghcr.io/0xcaff/runpod-nix:latest

## usage

### development

- launch from one of the templates
  - [Runpod Launch Instance - Nix - Nvidia GPU](https://console.runpod.io/deploy?template=d5w42uggft&ref=zchz96mv)
  - [Runpod Launch Instance - Nix - CPU](https://console.runpod.io/deploy?template=cuyqr7ggld&ref=zchz96mv)
- add volume storage if you want `/workspace` and nix profile to persist across reboots

includes `nix`, `git`, basic shell tooling, `nvidia-smi` and friends, and gotty support
for the runpod web terminal.

```bash
nix profile add nixpkgs#python311 nixpkgs#tmux nixpkgs#uv
git clone https://github.com/your-org/your-repo
cd your-repo
nix develop
```

### deployment

once you've got your application working and are ready to go deploy for production here's how you can do it.

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

build with

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

## motivation

nix is a tool for defining the entire software environment for a workload in
one place. from the application to the runtime level dependencies (python
packages or node packages) to native libraries to helper binaries (like ffmpeg
or protoc). where tools like docker trade off composibility for isolation and tools like uv miss parts of the build graph, nix encodes the whole thing.

runpod has built a great platform for renting GPUs. its cheap, containers start up fast. there are APIs. the web interface make sense and things just work.

these are tools for packaging your nix applications into runpod images.

[runpod]: https://runpod.io/
