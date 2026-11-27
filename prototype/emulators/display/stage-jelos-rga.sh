#!/bin/bash
set -euo pipefail

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 JELOS_SYSTEM OUTPUT_DIRECTORY" >&2
    exit 2
fi
stock=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
test "$(shasum -a 256 "$stock" | cut -d ' ' -f 1)" = b0028dc48926ad49ab2d0156fec2c64f16f406e2f463ded4cc84eb8dcaac4a83
mkdir -p "$2"
destination=$(cd "$2" && pwd)
docker run --rm --platform linux/arm64 -v "$stock:/stock:ro" -v "$destination:/out" \
    plumos-rk3566-bubble-tools:ec81d42 bash -euc '
        unsquashfs -no-progress -d /tmp/root /stock usr/lib/librga.so.2.1.0
        install -m644 /tmp/root/usr/lib/librga.so.2.1.0 /out/librga.so.2
'
