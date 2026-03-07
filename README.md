# RunPod Nix Base Image

A minimal, high-performance RunPod base image built entirely with Nix Flakes. This image provides a "Nix-native" environment for RunPod while maintaining full compatibility with NVIDIA drivers and persistent storage.

## Core Features

- **Lean & Fast:** Built using `dockerTools.buildLayeredImage` for minimal overhead and fast startup.
- **Composable Modules:** Features are split into reusable modules and composed with `lib.evalModules`.
- **Persistent Nix Environment:** Automatically persists your Nix user profile (`nix profile install`) in `/workspace/nix-profiles`, so your tools survive Pod restarts.
- **Dynamic Resource Optimization:** Automatically configures Nix `max-jobs` and `cores` based on your Pod's `RUNPOD_CPU_COUNT`.
- **Automatic SSH Setup:** Seamlessly installs your `PUBLIC_KEY` and starts `sshd` on boot.
- **Robust Environment Management:** Consolidates all environment variables (including RunPod UI variables and Nix paths) into `/etc/profile`, ensuring a consistent experience across all shell types (login, interactive, and `nix shell`).
- **NVIDIA Compatibility:** Pre-configured with the necessary `LD_LIBRARY_PATH` and `/run/opengl-driver` hooks to ensure PyTorch and other CUDA applications can find the host's drivers.
- **CUDA Cache:** Built-in support for the `cuda-maintainers` Cachix binary cache to speed up GPU-related installations.

## Module Layout

- `modules/base/options.nix`: Module schema (`runpod.contents`, `runpod.env`, `runpod.startHooks`, `runpod.extraCommands`, etc.)
- `modules/base/default.nix`: Base composition module (imports `base/options`, `base/env`, `base/host-libs`, and `base/patched-bin`)
- `modules/base/patched-bin.nix`: Patched-bin setup and ELF patching hook for `/usr/bin`
- `modules/base/env.nix`: RunPod env export and `/etc/profile` integration
- `modules/base/host-libs.nix`: Host driver library mirror hook
- `modules/ssh.nix`: SSH setup and `PUBLIC_KEY` handling
- `modules/nix-runtime.nix`: Nix config, registry, GC root, and persistent profiles
- `modules/gotty.nix`: Gotty compatibility hook
- `modules/tools.nix`: Extra CLI tooling (`gnugrep`, `gawk`, `procps`, `curl`, `jq`) used only in full images
- `lib/mk-image.nix`: Builder function that evaluates modules and emits the OCI image derivation
- `flake.nix`: Defines inline module compositions for `full` and `minimal` images

## Usage

### SSH Into Your Pod
Provide your SSH public key via the `PUBLIC_KEY` environment variable. 

**Note:** Pods launched via the RunPod Web UI automatically inherit your account's SSH keys. However, pods started via the **API or CLI** do not inherit these keys automatically; you must explicitly provide the `PUBLIC_KEY` variable during launch.

Once the Pod is started, you can connect via:
```bash
ssh root@<pod-ip> -p <port>
```

### Install Packages
Install any Nix package permanently into your workspace:
```bash
nix profile add nixpkgs#htop
```
The binary will be available in your `PATH` immediately and will persist after a Pod restart.

## Build and Deployment

To build the image locally:
```bash
nix build .#
```

To build the minimal profile:
```bash
nix build .#minimal
```

To push the image to a registry (requires `skopeo`):
```bash
nix run .#deploy
```

To create a custom image, call `mkImage` from your own flake and pass a module list.

## Architecture Notes: The Glibc Unity Rule

This image is designed to solve the "Glibc Version Split" common in Nix containers on non-NixOS hosts. It provides a stable FHS-compliant environment by symlinking the Nix-provided Glibc into standard paths (`/lib64`, `/usr/lib/x86_64-linux-gnu`). This ensures that the host's NVIDIA drivers and your Nix-packaged applications share the exact same core system libraries, preventing "Device Unavailable" (Error 999) crashes.

## Feasibility Note

This project is currently considered a proof-of-concept and highlights the significant challenges of running Nix on ephemeral, heterogeneous GPU infrastructure.

### The "Library Soup" Problem
During development, we encountered several critical failure points that make this approach fragile:

1.  **Glibc Fragmentation:** The modern NVIDIA drivers provided by RunPod hosts (e.g., version 575.57) require specific versions of the GNU C Library. If your Nix environment uses a different version (even if it's newer), the driver will detect a "tainted" environment and return **Error 999 (Device Unavailable)**. In any single process, there can be only one "king" Glibc; Nix's strict isolation makes this unity extremely difficult to achieve when loading host-provided drivers.
2.  **Infrastructure Inconsistency:** As per the [RunPod Partner Requirements](https://docs.runpod.io/hosting/partner-requirements#operating-system), host nodes are not strictly consistent. One node might provide Glibc 2.35 while another provides 2.42. A Nix environment pinned to a specific Glibc will break the moment it is deployed to a node that doesn't match its expectations.
3.  **The Wrapper Conflict:** Nix-packaged applications use wrapper scripts to manage `LD_LIBRARY_PATH`. These wrappers often conflict with RunPod's host-mounted drivers, leading to a "library soup" where the application finds partial symbols from the Nix store and partial symbols from the host, resulting in immediate crashes or silent failures.
4.  **Environment Clobbering:** We found that standard interactive login shells often scrub the environment or source files in an order that clobbers Nix's carefully constructed paths with RunPod's system-level exports, requiring complex workarounds in `/etc/profile`.

Ultimately, while the FHS symlink shims implemented here provide a temporary bridge, the fundamental conflict between Nix's desire for total hermeticism and the NVIDIA driver's requirement for host-level integration makes this project a challenging long-term maintenance target on inconsistent cloud infrastructure.
