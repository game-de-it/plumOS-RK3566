#!/bin/bash
set -euo pipefail

if [ "$#" -ne 1 ]; then
    echo "usage: $0 FRONTEND_DIRECTORY" >&2
    exit 2
fi
script=$(cd "$(dirname "$0")" && pwd)
frontend=$1
mkdir -p "$frontend/lib/alsa-lib" "$frontend/lib/alsa-lib-armhf" "$frontend/licenses"
docker run --rm --platform linux/arm64 \
    -v "$script/audio-router:/source:ro" \
    -v "$frontend/lib/alsa-lib:/destination" \
    plumos-rk3566-bubble-tools:ec81d42 sh -eu -c \
    'cc -O2 -DPIC -fPIC -Wall -Wextra -shared -Wl,-z,relro,-z,now \
         -o /destination/libasound_module_pcm_plumos_hotplug.so \
         /source/plumos_hotplug.c -lasound; \
     strip --strip-unneeded /destination/libasound_module_pcm_plumos_hotplug.so'
armhf_image=plumos-rk3566-audio-armhf:bookworm
if ! docker image inspect "$armhf_image" >/dev/null 2>&1; then
    docker build --platform linux/arm64 -t "$armhf_image" \
        -f "$script/audio-router/Dockerfile.armhf" "$script/audio-router"
fi
docker run --rm --platform linux/arm64 \
    -v "$script/audio-router:/source:ro" \
    -v "$frontend/lib/alsa-lib-armhf:/destination" \
    "$armhf_image" sh -eu -c \
    'arm-linux-gnueabihf-gcc -O2 -DPIC -fPIC -Wall -Wextra -shared \
         -Wl,-z,relro,-z,now -idirafter /usr/include \
         -o /destination/libasound_module_pcm_plumos_hotplug.so \
         /source/plumos_hotplug.c -L/usr/lib/arm-linux-gnueabihf -lasound; \
     arm-linux-gnueabihf-strip --strip-unneeded /destination/libasound_module_pcm_plumos_hotplug.so'
install -m 644 "$script/audio-router/LICENSE" \
    "$frontend/licenses/plumos-audio-router-MIT.txt"
