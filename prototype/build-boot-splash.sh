#!/bin/bash
set -euo pipefail
if [ "$#" -ne 1 ]; then
    printf 'Usage: %s BUILD_WORK\n' "$0" >&2
    exit 2
fi
prototype=$(cd "$(dirname "$0")" && pwd)
work=$1
zig=$work/tools/zig-aarch64-macos-0.15.2/zig
# This pinned mini PLUS asset is byte-identical to Bubble's boot-splash.png.
image=$work/refs/mini-PLUS/package/frontend-mini-plus/plumos/config/frontend/boot-splash.png
printf '%s  %s\n' f55f1ad088fe842217f4d62153978c5227c470807303d266ecd6badcba7a553d "$image" | shasum -a 256 -c -
stage=$(mktemp -d "$work/splash.XXXXXXXX")
sips -s format bmp "$image" --out "$stage/splash.bmp" >/dev/null
python3 - "$stage" <<'PY'
from pathlib import Path
import struct
import sys

stage = Path(sys.argv[1])
bmp = (stage / "splash.bmp").read_bytes()
offset, = struct.unpack_from("<I", bmp, 10)
size, width, height, planes, bpp, compression = struct.unpack_from("<IiiHHI", bmp, 14)
masks = struct.unpack_from("<IIII", bmp, 54)
if (bmp[:2] != b"BM" or size < 56 or offset < 14 + size
        or (width, height, planes, bpp, compression) != (640, -480, 1, 32, 3)
        or masks != (0xff0000, 0xff00, 0xff, 0xff000000)):
    raise SystemExit("Expected top-down 640x480 BGRA bitmap")
pixels = bmp[offset:]
if len(pixels) != 640 * 480 * 4 or pixels[3::4] != b"\xff" * (640 * 480):
    raise SystemExit("The boot image must have 640x480 opaque pixels")
(stage / "boot-splash.xrgb").write_bytes(pixels)
PY
"$zig" cc -target aarch64-linux-musl -static -Os -s -Wall -Wextra \
    "$prototype/boot-splash.c" -o "$stage/boot-splash"
mkdir -p "$work/compiled/boot-splash"
install -m 755 "$stage/boot-splash" "$work/compiled/boot-splash/"
install -m 644 "$stage/boot-splash.xrgb" "$prototype/boot-splash.sh" "$work/compiled/boot-splash/"
