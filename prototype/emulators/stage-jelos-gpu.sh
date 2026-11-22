#!/bin/bash
set -euo pipefail

stock=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
image=plumos-rk3566-bubble-tools:ec81d42
test "$(shasum -a 256 "$stock" | cut -d ' ' -f 1)" = b0028dc48926ad49ab2d0156fec2c64f16f406e2f463ded4cc84eb8dcaac4a83
mkdir -p "$2"
directory=$(cd "$2" && pwd)
docker run --rm --platform linux/arm64 -v "$stock:/stock:ro" -v "$directory:/out" "$image" bash -euc '
    unsquashfs -no-progress -d /tmp/root /stock usr/lib/libmali.so.1.9.0 usr/lib32/libmali.so.1.9.0
    install -m 644 /tmp/root/usr/lib/libmali.so.1.9.0 /out/libmali-aarch64.so.1.9.0
    install -m 644 /tmp/root/usr/lib32/libmali.so.1.9.0 /out/libmali-armhf.so.1.9.0
'
