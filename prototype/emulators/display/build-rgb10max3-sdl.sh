#!/bin/bash
set -euo pipefail

if [ "$#" -ne 3 ]; then
    echo "Usage: $0 SDL2_ARCHIVE RGA_HEADERS DESTINATION_LIBRARY" >&2
    exit 2
fi
display=$(cd "$(dirname "$0")" && pwd)
archive=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
headers=$(cd "$2" && pwd)
mkdir -p "$(dirname "$3")"
destination=$(cd "$(dirname "$3")" && pwd)
image=${PLUMOS_BUBBLE_TOOLS_IMAGE:-plumos-rk3566-bubble-tools:ec81d42}

docker run --rm -i --platform linux/arm64 -v "$display:/display:ro" \
    -v "$archive:/sdl.tar.gz:ro" -v "$headers:/headers:ro" \
    -v "$destination:/out" "$image" bash -es -- "$(basename "$3")" <<'DOCKER'
set -euo pipefail
export LC_ALL=C
printf '%s  %s\n' f5c2b52498785858f3de1e2996eba3c1b805d08fe168a47ea527c7fc339072d0 /sdl.tar.gz |
    sha256sum -c -
mkdir -p /tmp/sdl/source /tmp/sdl/build
tar -xf /sdl.tar.gz --strip-components=1 -C /tmp/sdl/source
cd /tmp/sdl/source
cp /display/rk3566-kms-panel.h src/video/kmsdrm/
mkdir src/video/kmsdrm/plumos-rga
cp /headers/{RgaApi.h,drmrga.h,rga.h} src/video/kmsdrm/plumos-rga/
patch --batch -p1 </display/sdl2-rgb10max3-kms.patch
cd /tmp/sdl/build
../source/configure --prefix=/usr --disable-video-x11 --disable-video-wayland \
    --disable-video-opengl --enable-video-opengles --enable-video-kmsdrm \
    --enable-alsa --disable-pulseaudio --disable-jack --disable-sndio --disable-static
grep -q '^#define SDL_VIDEO_DRIVER_KMSDRM 1$' include/SDL_config.h
make -j"${PLUMOS_BUILD_JOBS:-6}"
strip --strip-unneeded build/.libs/libSDL2-2.0.so.0
install -m644 build/.libs/libSDL2-2.0.so.0 "/out/$1"
DOCKER
