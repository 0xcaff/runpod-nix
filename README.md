# runpod-nix

tools for building images for runpod with nix

## motivation

nix is a tool for defining the entire software environment for a workload in
one place. from the application to the runtime level dependencies (python
packages or node packages) to native libraries to helper binaries (like ffmpeg
or protoc). where tools like docker trade off composibility for isolation and tools like uv miss parts of the build graph nix encodes the whole thing.

runpod has built a great platform for renting GPUs. its very cheap, containers start up fast. there are APIs. the web ui make sense.

these are tools for packaging your nix applications into runpod images.

## usage

todo: add an example of building a runpod image with my application's entryoint

todo: add an example of using the interactive image to do some development (hmm, maybe we should just point folks to gchr.io/0xcaff/runpod-nix-interactive:latest) for starters.

## features

todo: include a list of features