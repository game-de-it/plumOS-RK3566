#!/bin/bash
# Input is a decompressed copy of JELOS-RK3566.aarch64-20240206.img.
set -euo pipefail
if [ "$#" -ne 3 ]; then
    printf 'Usage: %s JELOS.img BUILD_WORK OUTPUT.img\n' "$0" >&2
    exit 2
fi
prototype=$(cd "$(dirname "$0")" && pwd)
source_img=$1
work=$2
output=$3
[ ! -e "$output" ] && [ ! -e "$output.part" ]
tools=$work/tools
squash=$tools/squashfs-tools/squashfs-tools
fat=$tools/mtools-4.0.49
mini=$work/refs/mini-PLUS
source_version=baa7143a0bddb1aef5ebc8ee0c8c3358a6aa8d35
[ "$(git -C "$mini" rev-parse HEAD)" = "$source_version" ]

stage=$(mktemp -d "$work/stage.XXXXXXXX")
cp -RP "$prototype/system/." "$stage/"
payload=$stage/usr/lib/plumos-353m
upstream=$mini/package/frontend-mini-plus/plumos
frontend=$payload/frontend
mkdir -p "$frontend/bin" "$frontend/config"
cp -RP "$upstream"/{factory-defaults,fonts,themes} "$frontend/"
cp -RP "$upstream/config/frontend" "$frontend/config/"
mkdir -p "$frontend/share/frontend" "$frontend/share/doc"
cp -RP "$upstream/share/frontend/lang" "$frontend/share/frontend/"
cp -RP "$upstream/share/doc/plumos-frontend" "$frontend/share/doc/"
git -C "$mini" show HEAD:LICENSE > "$frontend/share/doc/plumos-frontend/LICENSE"
install -m 755 "$work/compiled/plumos-controller-ui" "$work/compiled/plumos-library-scan" "$frontend/bin/"
install -m 755 "$tools/adbd-36.0.1-linux-aarch64-static" "$payload/adbd"
cp -RP "$work/compiled/boot-splash" "$payload/boot-splash"
printf '%s\n' "$source_version" > "$payload/frontend-source"

offset=16777216
volume="$source_img@@$offset"
"$fat/mcopy" -i "$volume" ::/SYSTEM "$stage/JELOS-SYSTEM"
test "$(md5 -q "$stage/JELOS-SYSTEM")" = 44d5c32ff0154fa8375ed45eff14a9c5
"$squash/unsquashfs" -processors 6 -no-progress -pf "$stage/JELOS.pseudo" "$stage/JELOS-SYSTEM"
stage_system="$stage/SYSTEM"
python3 - "$stage" > "$stage/353m.pseudo" <<'PY'
import os
from pathlib import Path
import shlex
import shutil
import stat
import sys

stage = Path(sys.argv[1])
base = stage / "JELOS.pseudo"
rewritten = stage / "JELOS.pseudo.new"
issue = shlex.quote(str(stage / "etc/issue"))
# Keep the pseudo data offsets relative to the original data section.
# Replace the existing inode definition before merging the additions.
replaced = 0
with base.open("rb") as source, rewritten.open("wb") as target:
    for entry in source:
        if entry.startswith(b"etc/issue R "):
            entry = f"etc/issue f 644 0 0 cat {issue}\n".encode()
            replaced += 1
        target.write(entry)
        if entry == b"# START OF DATA - DO NOT MODIFY\n":
            shutil.copyfileobj(source, target, length=8 * 1024 * 1024)
            break
    else:
        raise SystemExit("JELOS SquashFS pseudo data marker missing")
if replaced != 1:
    raise SystemExit("Expected exactly one /etc/issue in JELOS SYSTEM")
rewritten.replace(base)

# These paths already exist in JELOS and retain their original inode metadata.
existing = {"usr", "usr/lib", "usr/lib/systemd", "usr/lib/systemd/system",
            "usr/lib/systemd/system/jelos.target.wants"}

for path in sorted((stage / "usr").rglob("*")):
    relative = path.relative_to(stage).as_posix()
    if relative in existing:
        continue
    mode = stat.S_IMODE(path.lstat().st_mode)
    if path.is_symlink():
        print(f"{relative} s 777 0 0 {os.readlink(path)}")
    elif path.is_dir():
        print(f"{relative} d {mode:o} 0 0")
    else:
        print(f"{relative} f {mode:o} 0 0 cat {shlex.quote(str(path))}")
PY
"$squash/mksquashfs" - "$stage_system" -no-progress -processors 8 -comp lzo -b 524288 \
    -no-xattrs -pf "$stage/JELOS.pseudo" -pf "$stage/353m.pseudo"
"$squash/unsquashfs" -lln "$stage_system" \
    usr/lib/plumos-353m/adbd usr/lib/plumos-353m/frontend/bin/plumos-controller-ui \
    usr/lib/systemd/system/emustation.service.d/plumos-353m.conf \
    usr/lib/systemd/system/jelos.target.wants/plumos-usb-adb.service \
    usr/lib/kernel-overlays/base/lib/modules/4.19.172 > "$stage/system-content.txt"
for required in plumos-353m/adbd frontend/bin/plumos-controller-ui emustation.service.d/plumos-353m.conf 'jelos.target.wants/plumos-usb-adb.service' kernel-overlays/base/lib/modules/4.19.172; do
    grep -Fq "$required" "$stage/system-content.txt"
done

cp -c "$source_img" "$output.part"
volume="$output.part@@$offset"
printf '%s  target/SYSTEM\n' "$(md5 -q "$stage_system")" > "$stage/SYSTEM.md5"
cat > "$stage/post-sysroot.sh" <<'HOOK'
# plumOS-353M boot overlay
plumos_splash_dir=/sysroot/usr/lib/plumos-353m/boot-splash
. "$plumos_splash_dir/boot-splash.sh"
HOOK
"$fat/mcopy" -o -i "$volume" "$stage_system" ::/SYSTEM
"$fat/mcopy" -o -i "$volume" "$stage/SYSTEM.md5" ::/SYSTEM.md5
"$fat/mcopy" -i "$volume" "$stage/post-sysroot.sh" ::/post-sysroot.sh
"$fat/mtype" -i "$volume" ::/post-sysroot.sh | cmp - "$stage/post-sysroot.sh"
"$fat/mcopy" -i "$volume" ::/SYSTEM "$stage/SYSTEM.readback"
cmp "$stage_system" "$stage/SYSTEM.readback"
"$squash/unsquashfs" -cat "$stage/SYSTEM.readback" etc/issue | cmp - "$stage/etc/issue"
for file in KERNEL rk3566-rg353m-linux.dtb extlinux/extlinux.conf; do
    "$fat/mtype" -i "$source_img@@$offset" "::/$file" > "$stage/before"
    "$fat/mtype" -i "$volume" "::/$file" > "$stage/after"
    cmp "$stage/before" "$stage/after"
done
# Only the FAT32 boot partition may differ, including its directory/FAT metadata.
python3 - "$source_img" "$output.part" <<'PY'
import sys

with open(sys.argv[1], "rb") as original, open(sys.argv[2], "rb") as candidate:
    assert original.read(32768 * 512) == candidate.read(32768 * 512)
    for f in (original, candidate):
        f.seek(4227072 * 512)
    assert original.read() == candidate.read()
PY
mv "$output.part" "$output"
(cd "$(dirname "$output")" && shasum -a 256 "$(basename "$output")" > "$(basename "$output").sha256")
printf 'Verified image: %s\nWorking evidence: %s\n' "$output" "$stage"
