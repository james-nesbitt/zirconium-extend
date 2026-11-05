# Justfile for zirconium-extend
#
# The image is built by mkosi from the pinned upstream/ submodule, using
# upstream's own profiles plus ours. Note what is NOT in the profile list:
# `brew` — upstream builds with it, we don't (empty Cellar, 6 enabled units,
# ~180 MB).

image_name := env("IMAGE_NAME", "zirconium-extend")
image := env("IMAGE_FULL", "localhost/" + image_name + ":latest")
profiles := "base,base-desktop,bootc-ostree,zirconium-bootc-ostree,jnesbitt"

# Copy our profile into the upstream checkout and keep the submodule clean.
sync:
    #!/usr/bin/env bash
    set -euo pipefail
    rm -rf upstream/mkosi.profiles/jnesbitt
    cp -a mkosi.profiles/jnesbitt upstream/mkosi.profiles/jnesbitt
    # Keep `git status` in the submodule quiet about a directory we inject.
    exclude="$(git rev-parse --git-dir)/modules/upstream/info/exclude"
    mkdir -p "$(dirname "$exclude")"
    grep -qxF 'mkosi.profiles/jnesbitt' "$exclude" 2>/dev/null \
        || echo 'mkosi.profiles/jnesbitt' >> "$exclude"

# Confirms the profile merged: our RemovePackages= list and added packages.
cat-config: sync
    mkosi -C upstream --profile={{profiles}} cat-config --debug

# Full image build. sudo resets PATH via secure_path, so a user-local mkosi
# (uv tool install) is not found by a bare `sudo mkosi`; resolve it first.
build: sync
    sudo "$(command -v mkosi)" -C upstream -B -ff --debug --profile={{profiles}}

# Load the built OCI directory into podman as {{image}}.
load:
    env IMAGE_FULL="{{image}}" just -f upstream/Justfile -d upstream load

# Re-layer the image so bootc upgrades pull small deltas.
rechunk:
    env IMAGE_FULL="{{image}}" just -f upstream/Justfile -d upstream rechunk

# bootc container lint.
lint:
    env IMAGE_FULL="{{image}}" just -f upstream/Justfile -d upstream lint

# Everything CI does, locally.
all: build load rechunk lint

clean:
    rm -rf upstream/mkosi.profiles/jnesbitt
    just -f upstream/Justfile -d upstream clean
