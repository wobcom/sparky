#!/usr/bin/env bash
if [[ $# -ne 1 ]]; then
    echo "Usage: ./build-ztp-image.sh [hw-profile]"
    exit 1
fi

if [[ ! -f "ztp-image/sparky-ztp-image-${1}_${1}.nix" ]]; then
    echo "Unknown hardware profile: $1"
    exit 1
fi

if [[ $1 == "r2s-sd" ]]; then
    nix build .#nixosConfigurations.sparky-ztp-image-$1.config.system.build.sdImage
else
    nix build .#nixosConfigurations.sparky-ztp-image-$1.config.system.build.raw
fi
