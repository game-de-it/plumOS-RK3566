#!/bin/bash
# Reuse the pinned Bubble ARM64 toolchain to build the RG353M frontend.
set -euo pipefail

if [ "$#" -lt 2 ] || [ "$#" -gt 3 ]; then
    printf 'Usage: %s BUILD_WORK BUBBLE_FRONTEND_SOURCE\n' "$0" >&2
    exit 2
fi
if ! command -v docker >/dev/null; then
    for cli_dir in "$HOME/.docker/bin" /Applications/Docker.app/Contents/Resources/bin; do
        [ -x "$cli_dir/docker" ] || continue
        export PATH="$cli_dir:$PATH"
        break
    done
fi
if ! command -v docker >/dev/null || ! docker info >/dev/null 2>&1; then
    echo 'The Bubble toolchain build requires a running Docker engine.' >&2
    exit 1
fi

work=$(cd "$1" && pwd)
bubble=$work/refs/Bubble
input_define=PLUMOS_BUBBLE_INPUT
if [ "$#" -eq 3 ]; then
    source=$3
elif [ -d "$2" ]; then
    source=$2
else
    source=$work/refs/mini-PLUS/src/frontend
    input_define=PLUMOS_MINI_PLUS_INPUT
fi
source=$(cd "$source" && pwd)
revision=ec81d42c0c2c39e7a32973bfe4df9b3027512a5d
image=plumos-rk3566-bubble-tools:ec81d42
test -f "$source/plumos_controller_ui.c"
mkdir -p "$work/compiled"
if ! docker image inspect "$image" >/dev/null 2>&1; then
    dockerfile=$(git -C "$bubble" show "$revision:docker/bubble-tools/Dockerfile")
    printf '%s\n' "$dockerfile" |
        docker build --platform linux/arm64 -t "$image" -
fi

docker run --rm -i --platform linux/arm64 --user "$(id -u):$(id -g)" \
    -e "INPUT_DEFINE=$input_define" \
    -v "$source:/src:ro" \
    -v "$work/compiled:/out" "$image" bash -s <<'BUILD'
set -euo pipefail
build=$(mktemp -d)
flags=(-std=gnu99 -O2 -D_GNU_SOURCE)
cc "${flags[@]}" "-D$INPUT_DEFINE=1" -DPLUMOS_ENABLE_FBDEV_RENDERER=1 \
    -DPLUMOS_FBDEV_ENABLE_PNG=1 -DPLUMOS_FBDEV_ENABLE_FREETYPE=1 \
    -DPLUMOS_FBDEV_ENABLE_DRM=1 $(pkg-config --cflags libpng freetype2 libdrm) \
    /src/plumos_controller_ui.c $(pkg-config --libs libpng freetype2 libdrm) -lm \
    -o "$build/plumos-controller-ui"
cc "${flags[@]}" /src/plumos_library_scan.c -o "$build/plumos-library-scan"
install -m 755 "$build/plumos-controller-ui" "$build/plumos-library-scan" /out/
if [ "$INPUT_DEFINE" = PLUMOS_BUBBLE_INPUT ]; then
    for name in plumos_text_ui plumos_frontend; do
        cc "${flags[@]}" "/src/$name.c" -o "$build/${name//_/-}"
        install -m 755 "$build/${name//_/-}" /out/
    done
fi
BUILD
