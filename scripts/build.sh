#!/usr/bin/env bash
# Builds the application and MCUboot with sysbuild for the nRF52840 DK, ready for rollcall:
#
#   1. west spdx --init on each image's build directory (Zephyr v4.4 needs it before the
#      build, so the CMake file-API query exists when CMake first runs);
#   2. west build --sysbuild into build/ (the application image is build/app, MCUboot
#      build/mcuboot);
#   3. west spdx on each image (SPDX 2.3; a fixed hash seed so its output is stable);
#   4. west list into build/west-list.txt, where rollcall looks for it.
#
# Usage: scripts/build.sh            (after scripts/setup-sdk.sh)
#
# Then: rollcall generate build --identify -o sbom.cdx.json
# (or the Action with build-dir: build). Exits with the first failing command's code.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
TOPDIR="${EXAMPLE_WORKSPACE:-$(dirname "$REPO")}"
BOARD="${BOARD:-nrf52840dk/nrf52840}"

if [[ -f "$TOPDIR/.example-env" ]]; then
    # shellcheck source=/dev/null
    source "$TOPDIR/.example-env"
fi
command -v west >/dev/null 2>&1 || {
    echo "build: west not found; run scripts/setup-sdk.sh first" >&2
    exit 2
}

cd "$REPO"
rm -rf build
west spdx --init -d build/app
west spdx --init -d build/mcuboot
west build -b "$BOARD" --sysbuild -d build app
for image in app mcuboot; do
    PYTHONHASHSEED=0 west spdx -d "build/$image" --spdx-version 2.3
done
west list -f '{name} {path} {revision} {url}' >build/west-list.txt
echo "build: ready for rollcall: $REPO/build (images app and mcuboot, west-list.txt)"
