#!/bin/bash
set -euo pipefail

if [ "$#" -ne 1 ]; then
    echo "usage: $0 FRONTEND_DIRECTORY" >&2
    exit 2
fi
script=$(cd "$(dirname "$0")" && pwd)
frontend=$1
mkdir -p "$frontend/lib/alsa-lib" "$frontend/licenses"
docker run --rm --platform linux/arm64 \
    -v "$script/audio-router:/source:ro" \
    -v "$frontend/lib/alsa-lib:/destination" \
    plumos-rk3566-bubble-tools:ec81d42 sh -eu -c \
    'cc -O2 -DPIC -fPIC -Wall -Wextra -shared -Wl,-z,relro,-z,now \
         -o /destination/libasound_module_pcm_plumos_hotplug.so \
         /source/plumos_hotplug.c -lasound; \
     strip --strip-unneeded /destination/libasound_module_pcm_plumos_hotplug.so'
install -m 644 "$script/audio-router/LICENSE" \
    "$frontend/licenses/plumos-audio-router-MIT.txt"
