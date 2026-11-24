#!/bin/bash
set -euo pipefail

if [ "$#" -ne 5 ]; then
    echo "Usage: $0 KERNEL_SUPPORT_SYSTEM BUBBLE_GIT STATIC_ADBD OUTPUT_DIRECTORY EMULATOR_RUNTIME" >&2
    exit 2
fi

prototype=$(cd "$(dirname "$0")" && pwd)
stock=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
bubble=$2
adbd=$3
runtime=$(cd "$5" && pwd)
python3 - "$runtime/bin/plumos-retroarch-launch" <<'PY_DRM_AUDIO'
from pathlib import Path
import sys

launcher = Path(sys.argv[1]).read_text()
drm = launcher.split('video_driver = "drm"', 1)[1].split('esac', 1)[0]
assert 'video_threaded = "true"' in drm
assert 'video_threaded = "false"' not in drm
PY_DRM_AUDIO
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
git -C "$bubble" archive "$revision" src/frontend src/services/plumos_bubble_volume_keys.c \
    package/frontend-bubble/plumos \
    package/network-services-bubble/plumos/bin/plumos-network-services \
    scripts/generate-bubble-runtime-coverage.py scripts/build-bubble-update-package.py \
    scripts/build-network-busybox-bubble.sh \
    rootfs/bubble-minimal/usr/share/udhcpc/default.script rootfs/bubble-minimal/etc/shadow LICENSE |
    tar -xf - -C "$stage/source"
if ! docker image inspect "$image" >/dev/null 2>&1; then
    git -C "$bubble" show "$revision:docker/bubble-tools/Dockerfile" |
        docker build --platform linux/arm64 -t "$image" -
fi
patch -d "$stage/source" -p1 < "$prototype/patches/rg353m-start-menu.patch"
patch -d "$stage/source" -p1 < "$prototype/patches/rg353m-start-helpers.patch"
patch -d "$stage/source" -p1 < "$prototype/patches/rg353m-audio.patch"
patch -d "$stage/source" -p1 < "$prototype/patches/rg353m-power-overlay-drm.patch"
patch -d "$stage/source" -p1 < "$prototype/patches/rg353m-power-overlay-input.patch"
patch -d "$stage/source" -p1 < "$prototype/patches/rg353m-brightness-keys.patch"
python3 "$prototype/emulators/set-volume-curve.py" \
    "$stage/source/package/frontend-bubble/plumos/bin/plumos-volume-control"
python3 "$prototype/emulators/enable-frontend-builtins.py" "$stage/source/src/frontend"
python3 "$prototype/brand-rk3566-frontend.py" "$stage/source"
patch -d "$stage/source" -p1 < "$prototype/patches/rk3566-square-layout.patch"
patch -d "$stage/source" -p1 < "$prototype/patches/rk3566-settings-footer-fit.patch"
"$prototype/build-frontend-docker.sh" "$stage" "$stage/source/src/frontend"

layer=$stage/layer
payload=$layer/usr/lib/plumos-353m
mkdir -p "$payload/frontend/bin"
frontend=$stage/source/package/frontend-bubble/plumos
cp -R "$frontend"/{config,factory-defaults,fonts,share,themes} "$payload/frontend/"
install -m 755 "$stage/compiled/"{plumos-controller-ui,plumos-library-scan,plumos-text-ui,plumos-frontend} "$payload/frontend/bin/"
install -m 755 "$prototype/system/usr/lib/plumos-353m/"{start-frontend,start-adb,mount-frontend,runtime-quiesce} "$payload/"
install -m 755 "$prototype/boot-system/manage-sd2" "$payload/"
install -m 755 "$frontend/bin/"{plumos-bubble-mount-sd2,plumos-library-index-media,plumos-factory-reset,plumos-time-sync,plumos-display-control} \
    "$payload/frontend/bin/"
install -m 755 "$frontend/bin/plumos-storage-health" "$payload/frontend/bin/plumos-storage-health-bubble"
install -m 755 "$stage/source/package/network-services-bubble/plumos/bin/plumos-network-services" \
    "$payload/frontend/bin/"
install -m 755 "$prototype/system/usr/lib/plumos-353m/frontend/bin/plumos-safe-shutdown" "$payload/frontend/bin/"
install -m 755 "$prototype/system/usr/lib/plumos-353m/frontend/bin/plumos-power-menu-overlay" "$payload/frontend/bin/"
install -m 755 "$adbd" "$payload/adbd"
cp -R "$runtime/." "$payload/frontend/"
install -m755 "$prototype/emulators/plumos-rk3566-audio-route" "$payload/frontend/bin/"
install -m755 "$frontend/bin/"{plumos-audio-output,plumos-volume-control} "$payload/frontend/bin/"
install -m755 "$prototype/emulators/plumos-rk3566-audio-output" "$payload/frontend/bin/plumos-audio-output"
"$prototype/emulators/build-audio-router.sh" "$payload/frontend"
sed 's|/run/plumos/audio/asound.conf|${PLUMOS_RUNTIME_ROOT:-/run/plumos}/audio/asound.conf|' \
    "$runtime/bin/plumos-pyxel-bubble-launch" >"$payload/frontend/bin/plumos-pyxel-bubble-launch"
python3 - "$payload/frontend" <<'PY_PYXEL_CHECKSUM'
import hashlib
from pathlib import Path
import sys

root = Path(sys.argv[1])
relative = "bin/plumos-pyxel-bubble-launch"
checksums = root / "components/pyxel/checksums.sha256"
lines = checksums.read_text().splitlines()
matches = [i for i, line in enumerate(lines) if line.endswith("  " + relative)]
assert len(matches) == 1
lines[matches[0]] = hashlib.sha256((root / relative).read_bytes()).hexdigest() + "  " + relative
checksums.write_text("\n".join(lines) + "\n")
PY_PYXEL_CHECKSUM
"$prototype/stage-bubble-apps.sh" "$bubble" "$revision" "$image" "$stage/apps-source" \
    "$payload/frontend"
install -m 755 "$prototype/system/usr/lib/plumos-353m/frontend/bin/"{plumos-network-control,plumos-storage-health} \
    "$payload/frontend/bin/"
sed 's/udhcpc -q -n/udhcpc -n -R/' "$frontend/bin/plumos-network-control" \
    > "$payload/frontend/bin/plumos-network-control-bubble"
install -m 755 "$stage/source/rootfs/bubble-minimal/usr/share/udhcpc/default.script" \
    "$payload/frontend/bin/plumos-wifi-dhcp"
chmod 755 "$payload/frontend/bin/"{plumos-network-control-bubble,plumos-wifi-dhcp}
docker run --rm -i --platform linux/arm64 -v "$payload/frontend:/runtime" \
    -v "$stage/source/src/services:/services:ro" "$image" sh -se <<'BUILD'
    cc -O2 -Wall -Wextra -o /runtime/bin/plumos-volume-keys /services/plumos_bubble_volume_keys.c
    install -m 755 /bin/busybox /runtime/bin/busybox
    /runtime/bin/busybox --list | grep -qx grep
    /runtime/bin/busybox --list | grep -qx taskset
    /runtime/bin/busybox --list | grep -qx udhcpc
    install -m 644 /usr/share/doc/busybox-static/copyright /runtime/licenses/busybox-static-copyright
    cd "$(mktemp -d)"
    curl -fsSLo wpa_supplicant-2.10.tar.gz https://w1.fi/releases/wpa_supplicant-2.10.tar.gz
    printf '%s  %s\n' 20df7ae5154b3830355f8ab4269123a87affdea59fe74fe9292a91d0d7e17b2f \
        wpa_supplicant-2.10.tar.gz | sha256sum -c -
    tar -xf wpa_supplicant-2.10.tar.gz
    cd wpa_supplicant-2.10
    printf '%s\n' CONFIG_CTRL_IFACE=y > wpa_supplicant/.config
    make -C wpa_supplicant -j4 wpa_cli
    install -m 755 wpa_supplicant/wpa_cli /runtime/bin/wpa_cli
    install -m 644 COPYING /runtime/licenses/wpa_cli-COPYING
    /runtime/bin/wpa_cli -v
BUILD
# Bubble's static network BusyBox supplies the service and clock applets.
network_builder=$stage/source/scripts/build-network-busybox-bubble.sh
python3 - "$network_builder" <<'PY_CONFIG'
from pathlib import Path
import sys
path = Path(sys.argv[1])
text = path.read_text()
line = "    -e 's/^# CONFIG_STATIC is not set$/CONFIG_STATIC=y/' " + chr(92)
assert text.count(line) == 1
path.write_text(text.replace(line, line + "\n    -e 's/^# CONFIG_NTPD is not set$/CONFIG_NTPD=y/' " + chr(92)))
PY_CONFIG
PLUMOS_BUBBLE_TOOLS_IMAGE="$image" "$network_builder"
mkdir -p "$payload/frontend/network-services/bin"
install -m755 "$stage/source/output/network-busybox/bubble/busybox" \
    "$payload/frontend/network-services/bin/busybox"
catalog="$payload/frontend/config/frontend"
python3 - "$catalog/systems.json" "$catalog/start-menu-coverage.json" <<'PY'
import json
from pathlib import Path
import sys

path = Path(sys.argv[1])
catalog = json.loads(path.read_text())
systems = {system["id"]: system for system in catalog["systems"]}
# DRM presentation runs on its own thread (see assemble-runtime.sh), so the
# low-load routes can keep Bubble's ondemand policy and gpSP default.
systems["pyxel"]["default_cpu_policy"] = "performance"
j2me = systems["j2me"]
assert j2me["launch_profiles"] == ["retroarch:squirreljme"]
j2me["launch_profiles"] = ["retroarch:freej2me_plus"]
j2me["default_launch_profile"] = "retroarch:freej2me_plus"
j2me.pop("support")
for system in systems.values():
    system["enabled"] = True
for system_id in ("2048", "mrboom"):
    system = systems[system_id]
    name = system["display_name"] + ".desktop"
    system["builtin_entry"] = name
    directory = path.parents[2] / "share" / "frontend-builtins"
    directory.mkdir(parents=True, exist_ok=True)
    (directory / name).write_text("[Desktop Entry]\nName=" + system["display_name"] + "\n")
path.write_text(json.dumps(catalog, indent=2, ensure_ascii=False) + "\n")

path = Path(sys.argv[2])
coverage = json.loads(path.read_text())
coverage["device"] = "rg353m"
coverage["unsupported_visible"] = [
    {"path": "system/lid-suspend", "reason": "no-lid-device"},
]
coverage["product_excluded"] = [
    item for item in coverage["product_excluded"] if item["path"] != "network/services/adb"
]
coverage["implemented_subroutes"].extend([
    {"path": "system/brightness", "backend": "RK3566 backlight"},
    {"path": "system/time", "backend": "NTP and RK817 RTC"},
    {"path": "system/storage-check", "backend": "read-only FAT32 check of active SD media"},
    {"path": "network/services/adb", "backend": "USB ADB policy applied on reboot"},
])
path.write_text(json.dumps(coverage, indent=2, ensure_ascii=False) + "\n")
PY
python3 "$stage/source/scripts/generate-bubble-runtime-coverage.py" \
    --systems "$catalog/systems.json" --app-root "$payload/frontend" \
    --output "$catalog/runtime-coverage.json"
python3 "$prototype/emulators/verify-release-runtime.py" "$payload/frontend"
install -m755 "$frontend/bin/plumos-system-update" "$payload/frontend/bin/"
for file in "$payload/frontend/share/update/plumos-system-update.py" \
    "$stage/source/scripts/build-bubble-update-package.py"; do
    sed -e 's/"gkd-bubble"/"rg353m"/' -e 's/"bubble-stockos-r1"/"rk3566-plumos-r1"/' \
        "$file" > "$file.rk3566"
    mv "$file.rk3566" "$file"
done
ln -s /usr/bin/openssl "$payload/frontend/bin/plumos-openssl"
printf '%s\n' "${PLUMOS_RUNTIME_VERSION:-0.1.0-dev}" > "$payload/frontend/VERSION"
printf '%s\n' rk3566-plumos-r1 > "$payload/frontend/COMPAT_VENDOR"
printf '%s\n' 1 > "$payload/frontend/RUNTIME_ABI"
install -m755 "$stage/source/scripts/build-bubble-update-package.py" "$out/build-runtime-update.py"
install -m 644 "$stage/source/LICENSE" "$payload/frontend/LICENSE"
printf 'plumOS-Bubble %s\n' "$revision" > "$payload/frontend-source"
docker run --rm -i --platform linux/arm64 \
    -v "$layer:/layer:ro" -v "$out:/out" "$image" bash -s <<'BUILD'
set -euo pipefail
mksquashfs /layer /out/bubble-userland.squashfs.partial -noappend -all-root -comp lzo -no-progress
chmod 644 /out/bubble-userland.squashfs.partial
mv /out/bubble-userland.squashfs.partial /out/bubble-userland.squashfs
BUILD

"$prototype/build-runtime-system.sh" "$stock" "$layer" "$out/SYSTEM" \
    "$stage/source/rootfs/bubble-minimal/etc/shadow"

(cd "$out" && shasum -a 256 SYSTEM bubble-userland.squashfs > SHA256SUMS)
