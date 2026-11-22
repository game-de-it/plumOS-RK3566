#!/bin/bash
set -euo pipefail

if [ "$#" -lt 4 ] || [ "$#" -gt 5 ]; then
    echo "Usage: $0 STOCK_SYSTEM BUBBLE_GIT STATIC_ADBD OUTPUT_DIRECTORY [EMULATOR_RUNTIME]" >&2
    exit 2
fi

prototype=$(cd "$(dirname "$0")" && pwd)
stock=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
bubble=$2
adbd=$3
mkdir -p "$4"
out=$(cd "$4" && pwd)
revision=ec81d42c0c2c39e7a32973bfe4df9b3027512a5d
image=plumos-rk3566-bubble-tools:ec81d42
expected=b0028dc48926ad49ab2d0156fec2c64f16f406e2f463ded4cc84eb8dcaac4a83
test "$(shasum -a 256 "$stock" | cut -d ' ' -f 1)" = "$expected"
test -x "$adbd"
test ! -e "$out/SYSTEM"
test ! -e "$out/bubble-userland.squashfs"

stage=$(mktemp -d "$out/build.XXXXXXXX")
mkdir "$stage/source"
git -C "$bubble" archive "$revision" src/frontend package/frontend-bubble/plumos LICENSE |
    tar -xf - -C "$stage/source"
if ! docker image inspect "$image" >/dev/null 2>&1; then
    git -C "$bubble" show "$revision:docker/bubble-tools/Dockerfile" |
        docker build --platform linux/arm64 -t "$image" -
fi
"$prototype/build-frontend-docker.sh" "$stage" "$stock" "$stage/source/src/frontend"

layer=$stage/layer
payload=$layer/usr/lib/plumos-353m
mkdir -p "$payload/frontend/bin" "$layer/usr/lib/systemd/system/jelos.target.wants"
frontend=$stage/source/package/frontend-bubble/plumos
cp -R "$frontend"/{config,factory-defaults,fonts,share,themes} "$payload/frontend/"
install -m 755 "$stage/compiled/"{plumos-controller-ui,plumos-library-scan,plumos-text-ui,plumos-frontend} "$payload/frontend/bin/"
install -m 755 "$prototype/system/usr/lib/plumos-353m/"{start-frontend,start-adb} "$payload/"
install -m 755 "$prototype/boot-system/manage-sd2" "$payload/"
git -C "$bubble" show "$revision:package/frontend-bubble/plumos/bin/plumos-bubble-mount-sd2" \
    > "$payload/frontend/bin/plumos-bubble-mount-sd2"
chmod 755 "$payload/frontend/bin/plumos-bubble-mount-sd2"
install -m 755 "$prototype/system/usr/lib/plumos-353m/frontend/bin/plumos-safe-shutdown" "$payload/frontend/bin/"
install -m 755 "$adbd" "$payload/adbd"
if [ "$#" -eq 5 ]; then
    runtime=$(cd "$5" && pwd)
    test -x "$runtime/bin/retroarch"
    test -x "$runtime/picoarch/bin/picoarch"
    test -x "$runtime/emulator/standalone/pcsx_rearmed/bin/pcsx" ||
        test -x "$runtime/emulator/standalone/pcsx_rearmed/pcsx"
    cp -R "$runtime/." "$payload/frontend/"
    docker run --rm --platform linux/arm64 -v "$payload/frontend:/runtime" "$image" sh -ec '
        install -m 755 /bin/busybox /runtime/bin/busybox
        /runtime/bin/busybox --list | grep -qx grep
        /runtime/bin/busybox --list | grep -qx taskset
        install -m 644 /usr/share/doc/busybox-static/copyright /runtime/licenses/busybox-static-copyright
    '
    python3 - "$payload/frontend/config/frontend/systems.json" <<'PY'
import json
from pathlib import Path
import sys

path = Path(sys.argv[1])
catalog = json.loads(path.read_text())
nes = next(system for system in catalog["systems"] if system["id"] == "nes")
nes["default_cpu_policy"] = "performance"
path.write_text(json.dumps(catalog, indent=2, ensure_ascii=False) + "\n")
PY
fi
install -m 644 "$stage/source/LICENSE" "$payload/frontend/LICENSE"
printf 'plumOS-Bubble %s\n' "$revision" > "$payload/frontend-source"
cp -R "$prototype/system/usr/lib/systemd/system/"{emustation.service.d,plumos-usb-adb.service} "$layer/usr/lib/systemd/system/"
ln -s ../plumos-usb-adb.service "$layer/usr/lib/systemd/system/jelos.target.wants/plumos-usb-adb.service"

docker run --rm -i --platform linux/arm64 \
    -v "$stock:/stock:ro" -v "$layer:/layer:ro" -v "$out:/out" "$image" bash -s <<'BUILD'
set -euo pipefail
mksquashfs /layer /out/bubble-userland.squashfs.partial -noappend -all-root -comp lzo -no-progress
chmod 644 /out/bubble-userland.squashfs.partial
mv /out/bubble-userland.squashfs.partial /out/bubble-userland.squashfs
unsquashfs -no-progress -d /tmp/system /stock
cp -a /layer/. /tmp/system/
mksquashfs /tmp/system /out/SYSTEM.partial -noappend -comp lzo -b 524288 -no-xattrs -no-progress
chmod 644 /out/SYSTEM.partial
mv /out/SYSTEM.partial /out/SYSTEM
BUILD

(cd "$out" && shasum -a 256 SYSTEM bubble-userland.squashfs > SHA256SUMS)
