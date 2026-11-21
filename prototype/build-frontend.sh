#!/bin/bash
# Cross-build the mini PLUS frontend against the libraries from the JELOS SYSTEM.
set -euo pipefail
if [ "$#" -ne 2 ]; then
    printf 'Usage: %s BUILD_WORK JELOS_SYSTEM\n' "$0" >&2
    exit 2
fi
work=$1
base_system=$2
zig=$work/tools/zig-aarch64-macos-0.15.2/zig
unsquashfs=$work/tools/squashfs-tools/squashfs-tools/unsquashfs
src=$work/refs/mini-PLUS/src/frontend
inc=$work/debian/sysroot/usr/include
out=$work/compiled
build=$(mktemp -d "$work/frontend.XXXXXXXX")
"$unsquashfs" -processors 4 -no-progress -d "$build/runtime" "$base_system" \
    'usr/lib/libpng*' 'usr/lib/libfreetype*' 'usr/lib/libdrm.so*'
lib=$build/runtime/usr/lib
flags=(-target aarch64-linux-gnu.2.38 -std=gnu99 -O2 -D_GNU_SOURCE)
"$zig" cc "${flags[@]}" \
    -DPLUMOS_ENABLE_FBDEV_RENDERER=1 -DPLUMOS_FBDEV_ENABLE_PNG=1 \
    -DPLUMOS_FBDEV_ENABLE_FREETYPE=1 -DPLUMOS_FBDEV_ENABLE_DRM=1 \
    -I"$inc" -I"$inc/freetype2" -I"$inc/libdrm" -Wl,--allow-shlib-undefined \
    "$src/plumos_controller_ui.c" "$lib/libpng16.so.16" \
    "$lib/libfreetype.so.6" "$lib/libdrm.so.2" -lm -o "$build/plumos-controller-ui"
"$zig" cc "${flags[@]}" "$src/plumos_library_scan.c" -o "$build/plumos-library-scan"
mkdir -p "$out"
install -m 755 "$build/plumos-controller-ui" "$build/plumos-library-scan" "$out/"
