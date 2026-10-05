#!/usr/bin/env bash
# Sets up the west workspace around this repository and the Zephyr SDK, all pinned:
# Zephyr v4.4.2 and its modules from west.yml, the Python tools from requirements.txt, and
# Zephyr SDK 1.0.1 (the minimal bundle plus the arm-zephyr-eabi toolchain), each download
# checked against its SHA-256. The pins are rollcall's (scripts/regen-fixtures.sh there).
#
# Usage: scripts/setup-sdk.sh
#
# The workspace topdir is the directory holding this repository (a T2 west workspace), unless
# EXAMPLE_WORKSPACE names another one that holds it. The SDK goes in
# $ZEPHYR_SDK_INSTALL_DIR (default <topdir>/.zephyr-sdk-1.0.1), the Python tools in
# <topdir>/.venv. Every step is skipped when already done, so a CI cache of the topdir works.
#
# Writes <topdir>/.example-env (`source` it, or let scripts/build.sh do it); under GitHub
# Actions it also exports the same to the following steps. Needs git, curl, tar, xz,
# python3 (3.10+, with venv), cmake (3.20+) and ninja. Needs the network on first run.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
TOPDIR="${EXAMPLE_WORKSPACE:-$(dirname "$REPO")}"
TOPDIR="$(cd "$TOPDIR" && pwd)"

ZEPHYR_COMMIT=dccb09599635bdff17633fa7e9dab014b91dce90 # v4.4.2, as west.yml
SDK_VERSION=1.0.1
SDK_URL_BASE="https://github.com/zephyrproject-rtos/sdk-ng/releases/download/v${SDK_VERSION}"
SDK="${ZEPHYR_SDK_INSTALL_DIR:-$TOPDIR/.zephyr-sdk-$SDK_VERSION}"

die() {
    echo "setup-sdk: $*" >&2
    exit 2
}

# SHA-256 of zephyr-sdk-1.0.1_<host>_minimal.tar.xz (sdk-ng release sha256.sum).
sdk_minimal_sha256() {
    case "$1" in
        linux-x86_64) echo ca9bc0ff66fafca1dac9d592a36d953cf16d096a9d09b1c0357f021cf9f6a7eb ;;
        linux-aarch64) echo d79c5bfc68e679488659bea289a4026e52a64f03338875c8c9c850fff13cee30 ;;
        macos-aarch64) echo 867063901f39528a6175a80ebc20367bd6cb440593e7e2650eda30392f1f6b65 ;;
        *) return 1 ;;
    esac
}

# SHA-256 of toolchain_gnu_<host>_arm-zephyr-eabi.tar.xz (sdk-ng release sha256.sum).
sdk_arm_sha256() {
    case "$1" in
        linux-x86_64) echo 21b85981cb5a1818d9bc53d82af80f208946ec038b982ff1907287572ed3a634 ;;
        linux-aarch64) echo b9805b691f2f0a8926c92694cae378d05ba07b76abca745e216fcc52753cc4d6 ;;
        macos-aarch64) echo 4008edb5d4840cd994aedd7f1309bfb63e7243729d57839ebf1cc83c1f17c886 ;;
        *) return 1 ;;
    esac
}

for tool in git curl tar xz python3 cmake ninja; do
    command -v "$tool" >/dev/null 2>&1 || die "$tool is required"
done

case "$(uname -s)/$(uname -m)" in
    Linux/x86_64 | Linux/amd64) host=linux-x86_64 ;;
    Linux/aarch64 | Linux/arm64) host=linux-aarch64 ;;
    Darwin/arm64 | Darwin/aarch64) host=macos-aarch64 ;;
    *) die "no pinned Zephyr SDK for $(uname -s)/$(uname -m)" ;;
esac

sha256_of() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | cut -d' ' -f1
    else
        shasum -a 256 "$1" | cut -d' ' -f1
    fi
}

# download <url> <dest> <sha256>
download() {
    local tmp got
    tmp="$(mktemp "$(dirname "$2")/.download.XXXXXX")"
    curl -fsSL --retry 3 -o "$tmp" "$1" || { rm -f "$tmp"; die "download failed: $1"; }
    got="$(sha256_of "$tmp")"
    [[ "$got" == "$3" ]] || { rm -f "$tmp"; die "sha256 mismatch for $1: expected $3, got $got"; }
    mv "$tmp" "$2"
}

# --- Python tools -----------------------------------------------------------------------------
if [[ ! -x "$TOPDIR/.venv/bin/python" ]]; then
    echo "setup-sdk: creating $TOPDIR/.venv"
    python3 -m venv "$TOPDIR/.venv"
fi
"$TOPDIR/.venv/bin/python" -m pip install -q --disable-pip-version-check -r "$REPO/requirements.txt"
export PATH="$TOPDIR/.venv/bin:$PATH"

# --- West workspace ---------------------------------------------------------------------------
if [[ ! -d "$TOPDIR/.west" ]]; then
    echo "setup-sdk: west init -l $REPO"
    (cd "$TOPDIR" && west init -l "$REPO")
fi
(cd "$TOPDIR" && west update --narrow -o=--depth=1)
head="$(git -C "$TOPDIR/zephyr" rev-parse 'HEAD^{commit}')"
[[ "$head" == "$ZEPHYR_COMMIT" ]] || die "zephyr is at $head, expected $ZEPHYR_COMMIT (v4.4.2)"
"$TOPDIR/.venv/bin/python" -m pip install -q --disable-pip-version-check \
    -r "$REPO/requirements.txt" \
    -r "$TOPDIR/zephyr/scripts/requirements-base.txt" \
    -r "$TOPDIR/bootloader/mcuboot/zephyr/requirements.txt"

# --- Zephyr SDK -------------------------------------------------------------------------------
marker="$SDK/.example-sdk-$SDK_VERSION-$host"
if [[ ! -f "$marker" ]]; then
    echo "setup-sdk: installing Zephyr SDK $SDK_VERSION ($host) into $SDK"
    mkdir -p "$SDK"
    minimal="zephyr-sdk-${SDK_VERSION}_${host}_minimal.tar.xz"
    arm="toolchain_gnu_${host}_arm-zephyr-eabi.tar.xz"
    download "$SDK_URL_BASE/$minimal" "$SDK/$minimal" "$(sdk_minimal_sha256 "$host")"
    download "$SDK_URL_BASE/$arm" "$SDK/$arm" "$(sdk_arm_sha256 "$host")"
    # Host tools (QEMU, OpenOCD, ...) are not needed to build.
    tar -xJf "$SDK/$minimal" -C "$SDK" --strip-components=1 \
        --exclude="zephyr-sdk-$SDK_VERSION/hosttools" \
        --exclude="zephyr-sdk-$SDK_VERSION/hosttools/*"
    # SDK 1.x: the GNU toolchain goes under <sdk>/gnu.
    mkdir -p "$SDK/gnu"
    tar -xJf "$SDK/$arm" -C "$SDK/gnu"
    rm -f "$SDK/$minimal" "$SDK/$arm"
    touch "$marker"
fi
[[ "$(cat "$SDK/sdk_version")" == "$SDK_VERSION" ]] || die "$SDK/sdk_version is not $SDK_VERSION"
[[ -x "$SDK/gnu/arm-zephyr-eabi/bin/arm-zephyr-eabi-gcc" ]] ||
    die "arm-zephyr-eabi toolchain missing under $SDK/gnu"

# --- Environment ------------------------------------------------------------------------------
cat >"$TOPDIR/.example-env" <<ENV
export PATH="$TOPDIR/.venv/bin:\$PATH"
export ZEPHYR_BASE="$TOPDIR/zephyr"
export ZEPHYR_SDK_INSTALL_DIR="$SDK"
export ZEPHYR_TOOLCHAIN_VARIANT=zephyr
ENV
if [[ -n "${GITHUB_ENV:-}" ]]; then
    echo "$TOPDIR/.venv/bin" >>"$GITHUB_PATH"
    {
        echo "ZEPHYR_BASE=$TOPDIR/zephyr"
        echo "ZEPHYR_SDK_INSTALL_DIR=$SDK"
        echo "ZEPHYR_TOOLCHAIN_VARIANT=zephyr"
    } >>"$GITHUB_ENV"
fi
echo "setup-sdk: ready (workspace $TOPDIR, SDK $SDK); source $TOPDIR/.example-env"
