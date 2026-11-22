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
git -C "$bubble" archive "$revision" src/frontend package/frontend-bubble/plumos \
    scripts/generate-bubble-runtime-coverage.py scripts/build-bubble-update-package.py \
    rootfs/bubble-minimal/usr/share/udhcpc/default.script LICENSE |
    tar -xf - -C "$stage/source"
if ! docker image inspect "$image" >/dev/null 2>&1; then
    git -C "$bubble" show "$revision:docker/bubble-tools/Dockerfile" |
        docker build --platform linux/arm64 -t "$image" -
fi
python3 "$prototype/emulators/enable-frontend-builtins.py" "$stage/source/src/frontend"
"$prototype/build-frontend-docker.sh" "$stage" "$stage/source/src/frontend"

layer=$stage/layer
payload=$layer/usr/lib/plumos-353m
mkdir -p "$payload/frontend/bin"
frontend=$stage/source/package/frontend-bubble/plumos
cp -R "$frontend"/{config,factory-defaults,fonts,share,themes} "$payload/frontend/"
install -m 755 "$stage/compiled/"{plumos-controller-ui,plumos-library-scan,plumos-text-ui,plumos-frontend} "$payload/frontend/bin/"
install -m 755 "$prototype/system/usr/lib/plumos-353m/"{start-frontend,start-adb,mount-frontend} "$payload/"
install -m 755 "$prototype/boot-system/manage-sd2" "$payload/"
install -m 755 "$frontend/bin/"{plumos-bubble-mount-sd2,plumos-storage-health,plumos-library-index-media} \
    "$payload/frontend/bin/"
install -m 755 "$prototype/system/usr/lib/plumos-353m/frontend/bin/plumos-safe-shutdown" "$payload/frontend/bin/"
install -m 755 "$adbd" "$payload/adbd"
cp -R "$runtime/." "$payload/frontend/"
"$prototype/stage-bubble-apps.sh" "$bubble" "$revision" "$image" "$stage/apps-source" \
    "$payload/frontend"
install -m 755 "$prototype/system/usr/lib/plumos-353m/frontend/bin/plumos-network-control" \
    "$payload/frontend/bin/"
sed 's/udhcpc -q -n/udhcpc -n -R/' "$frontend/bin/plumos-network-control" \
    > "$payload/frontend/bin/plumos-network-control-bubble"
install -m 755 "$stage/source/rootfs/bubble-minimal/usr/share/udhcpc/default.script" \
    "$payload/frontend/bin/plumos-wifi-dhcp"
chmod 755 "$payload/frontend/bin/"{plumos-network-control-bubble,plumos-wifi-dhcp}
docker run --rm -i --platform linux/arm64 -v "$payload/frontend:/runtime" "$image" sh -se <<'BUILD'
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
catalog="$payload/frontend/config/frontend"
python3 - "$catalog/systems.json" <<'PY'
import json
from pathlib import Path
import sys

path = Path(sys.argv[1])
catalog = json.loads(path.read_text())
systems = {system["id"]: system for system in catalog["systems"]}
systems["nes"]["default_cpu_policy"] = "performance"
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

"$prototype/build-runtime-system.sh" "$stock" "$layer" "$out/SYSTEM"

(cd "$out" && shasum -a 256 SYSTEM bubble-userland.squashfs > SHA256SUMS)
