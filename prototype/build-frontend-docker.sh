#!/bin/bash
# Reuse the pinned Bubble ARM64 toolchain to build the RG353M frontend.
set -euo pipefail

if [ "$#" -ne 2 ]; then
    printf 'Usage: %s BUILD_WORK JELOS_SYSTEM\n' "$0" >&2
    exit 2
fi
if ! command -v docker >/dev/null || ! docker info >/dev/null 2>&1; then
    echo 'The Bubble toolchain build requires a running Docker engine.' >&2
    exit 1
fi

work=$(cd "$1" && pwd)
system=$(cd "$(dirname "$2")" && pwd)/$(basename "$2")
bubble=$work/refs/Bubble
source=$work/refs/mini-PLUS/src/frontend
revision=ec81d42c0c2c39e7a32973bfe4df9b3027512a5c8
image=plumos-rk3566-bubble-tools:ec81d42
test -f "$system"
test -f "$source/plumos_controller_ui.c"
mkdir -p "$work/compiled"
if ! docker image inspect "$image" >/dev/null 2>&1; then
    git -C "$bubble" show "$revision:docker/bubble-tools/Dockerfile" |
        docker build --platform linux/arm64 -t "$image" -
fi

docker run --rm -i --platform linux/arm64 --user "$(id -u):$(id -g)" \
    -v "$source:/src:ro" -v "$system:/jelos-system:ro" \
    -v "$work/compiled:/out" "$image" bash -s <<'BUILD'
set -euo pipefail
build=$(mktemp -d)
unsquashfs -processors 4 -no-progress -d "$build/root" /jelos-system \
    'usr/lib/libpng*' 'usr/lib/libfreetype*' 'usr/lib/libdrm.so*'
lib=$build/root/usr/lib
flags=(-std=gnu99 -O2 -D_GNU_SOURCE)
cc "${flags[@]}" -DPLUMOS_MINI_PLUS_INPUT=1 -DPLUMOS_ENABLE_FBDEV_RENDERER=1 \
    -DPLUMOS_FBDEV_ENABLE_PNG=1 -DPLUMOS_FBDEV_ENABLE_FREETYPE=1 \
    -DPLUMOS_FBDEV_ENABLE_DRM=1 $(pkg-config --cflags libpng freetype2 libdrm) \
    -Wl,--allow-shlib-undefined /src/plumos_controller_ui.c \
    "$lib/libpng16.so.16" "$lib/libfreetype.so.6" "$lib/libdrm.so.2" -lm \
    -o "$build/plumos-controller-ui"
cc "${flags[@]}" /src/plumos_library_scan.c -o "$build/plumos-library-scan"
install -m 755 "$build/plumos-controller-ui" "$build/plumos-library-scan" /out/
BUILD
