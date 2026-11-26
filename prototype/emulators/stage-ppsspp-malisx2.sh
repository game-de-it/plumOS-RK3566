#!/bin/bash
set -euo pipefail

destination=${1:?PPSSPP Vulkan runtime directory is required}
version=0.6.1
malisx2_ref=9fbc7da2900938df9d078f0ed0afa1e58a779c48
mesa_ref=b5f8787e44083b4840f605b595e79fcf61077175
loader_version=1.3.239.0-1
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

curl -fsSL --retry 3 -o "$work/malisx2.tar.gz" \
    "https://github.com/bmdhacks/malisx2/releases/download/v$version/malisx2-$version-aarch64.tar.gz"
printf '%s  %s\n' a73f1a32c931a535f2b0eb22dcd07bbaf248564bde7541be24b7333a56cfdd33 \
    "$work/malisx2.tar.gz" | sha256sum -c -
tar -xzf "$work/malisx2.tar.gz" -C "$work"
driver="$work/malisx2/$version"

# Keep the pinned Debian loader private to PPSSPP. Other emulators retain
# their current graphics libraries and Vulkan discovery behavior.
(
    cd "$work"
    apt-get update -qq
    apt-get download "libvulkan1=$loader_version"
    deb="libvulkan1_${loader_version}_arm64.deb"
    printf '%s  %s\n' 3a21d49fef3a9799a21ffd5faa5bd7a1bd35604417cd9f5cf74155afd3b5282e "$deb" |
        sha256sum -c -
    dpkg-deb -x "$deb" loader
)
install -d "$destination/licenses"
install -m 644 "$driver/libvulkan_malisx2.so" "$driver/MANIFEST.json" "$destination/"
install -m 644 "$work/loader/usr/lib/aarch64-linux-gnu/libvulkan.so.1.3.239" \
    "$destination/libvulkan.so.1"
install -m 644 "$work/loader/usr/share/doc/libvulkan1/copyright" \
    "$destination/licenses/libvulkan1-copyright"
install -m 644 /usr/share/common-licenses/Apache-2.0 "$destination/licenses/Apache-2.0"
curl -fsSL --retry 3 -o "$destination/licenses/MaliSX2-LICENSE" \
    "https://raw.githubusercontent.com/bmdhacks/malisx2/$malisx2_ref/LICENSE"
curl -fsSL --retry 3 -o "$destination/licenses/Mesa-license.rst" \
    "https://raw.githubusercontent.com/bmdhacks/armsx2-turnip/$mesa_ref/docs/license.rst"
python3 - "$driver/malisx2_icd.aarch64.json" "$destination/malisx2_icd.json" <<'PY'
import json
from pathlib import Path
import sys

source, destination = map(Path, sys.argv[1:])
manifest = json.loads(source.read_text())
manifest["ICD"]["library_path"] = "./libvulkan_malisx2.so"
destination.write_text(json.dumps(manifest, indent=2) + "\n")
PY
