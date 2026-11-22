#!/bin/bash
set -euo pipefail

if [ "$#" -ne 4 ]; then
    echo "Usage: $0 STOCK_JELOS_IMG BUILT_SYSTEM BOOT_SPLASH_DIRECTORY OUTPUT.img" >&2
    exit 2
fi

prototype=$(cd "$(dirname "$0")" && pwd)
absolute_file() { printf '%s/%s\n' "$(cd "$(dirname "$1")" && pwd)" "$(basename "$1")"; }
source=$(absolute_file "$1")
system=$(absolute_file "$2")
splash=$(cd "$3" && pwd)
output=$(absolute_file "$4")
out_dir=$(dirname "$output")
name=$(basename "$output")
image=plumos-rk3566-bubble-tools:ec81d42
test "$(shasum -a 256 "$source" | cut -d ' ' -f 1)" = 281bf1c1faf7f4c9d044f59677075fbb9af99d2a8d01f873c23c13587668c73f
test -f "$system"
test -x "$splash/boot-splash"
for file in "$output" "$output.partial" "$output.gz" "$output.gz.partial"; do test ! -e "$file"; done

docker run --rm -i --privileged --user 0 --platform linux/arm64 \
    -v "$source:/stock:ro" -v "$system:/system:ro" -v "$splash:/splash:ro" \
    -v "$prototype:/prototype:ro" -v "$out_dir:/output" "$image" bash -s -- "$name" <<'BUILD'
set -euo pipefail
image=/output/$1
partial=$image.partial
work=$(mktemp -d)
loop=
mkdir "$work/flash" "$work/storage"
cleanup() {
    umount "$work/storage" 2>/dev/null || :
    umount "$work/flash" 2>/dev/null || :
    if [ -n "$loop" ]; then losetup -d "$loop"; fi
}
trap cleanup EXIT

unsquashfs -cat /system usr/lib/plumos-353m/frontend-source
unsquashfs -cat /system usr/lib/plumos-353m/start-frontend >/dev/null
unsquashfs -cat /system usr/lib/plumos-353m/adbd >/dev/null
cp --sparse=always /stock "$partial"
loop=$(losetup --find --show --partscan "$partial")
for number in 3 4; do
    device=$(cat "/sys/class/block/${loop##*/}p$number/dev")
    mknod "$work/p$number" b "${device%:*}" "${device#*:}"
done
test "$(blkid -s UUID -o value "$work/p3")" = 2211-3302
test "$(blkid -s UUID -o value "$work/p4")" = 886d8592-40ad-4e4c-b9c4-fad8076d367a
mount "$work/p3" "$work/flash"
mount "$work/p4" "$work/storage"
(
    cd "$work/flash"
    sha256sum KERNEL KERNEL.md5 extlinux/extlinux.conf rk3566-*.dtb > "$work/boot.sha256"
    cp /system SYSTEM
    printf '%s  target/SYSTEM\n' "$(md5sum SYSTEM | cut -d ' ' -f 1)" > SYSTEM.md5
    cp /prototype/boot-system/mount-storage.sh .
    mkdir plumos-splash
    cp /splash/boot-splash /splash/boot-splash.xrgb /prototype/boot-splash.sh plumos-splash/
    cp /prototype/seed/post-sysroot.sh .
    cmp /splash/boot-splash plumos-splash/boot-splash
    cmp /splash/boot-splash.xrgb plumos-splash/boot-splash.xrgb
    sha256sum -c "$work/boot.sha256"
    cmp /system SYSTEM
    # Replacing the FAT file can leave original SYSTEM bytes in unused clusters.
    free_kib=$(df -Pk . | awk 'NR==2 {print $4}')
    dd if=/dev/zero of=free-space.tmp bs=1024 count="$((free_kib - 64))" status=none
    rm free-space.tmp
)

base="$work/storage/plumos-rk3566"
units="$work/storage/.config/system.d"
mkdir -p "$base/system" "$base/provision" "$units/emustation.service.d" \
    "$units/jelos.target.wants" "$units/multi-user.target.wants"
install -m 755 /prototype/boot-system/{boot-system,mark-good} "$base/system/"
install -m 755 /prototype/seed/{provision-storage,start-storage} /splash/boot-splash /usr/sbin/sfdisk "$base/provision/"
mkdir "$base/provision/lib"
for library in libfdisk.so.1 libsmartcols.so.1 libtinfo.so.6 libreadline.so.8 libuuid.so.1 libblkid.so.1; do
    cp -L "/lib/aarch64-linux-gnu/$library" "$base/provision/lib/$library"
done
mkdir "$base/provision/licenses"
for package in fdisk libfdisk1 libsmartcols1 libtinfo6 libreadline8 libuuid1 libblkid1; do
    cp -L "/usr/share/doc/$package/copyright" "$base/provision/licenses/$package.copyright"
done
install -m 644 /splash/provision-{start,error}.xrgb "$base/provision/"
printf '%s\n' 'plumOS-RK3566 storage v1' > "$base/provision/seed"
install -m 644 /prototype/seed/plumos-user-storage.service /prototype/boot-system/plumos-system-health.service "$units/"
install -m 644 /prototype/seed/95-plumos-storage.conf "$units/emustation.service.d/"
ln -s /usr/lib/systemd/system/emustation.service "$units/jelos.target.wants/emustation.service"
ln -s ../plumos-system-health.service "$units/multi-user.target.wants/plumos-system-health.service"
# JELOS's first-boot resize would otherwise claim all of the SD for p4.
test -f "$work/storage/.please_resize_me"
rm "$work/storage/.please_resize_me"
sync
umount "$work/storage"
umount "$work/flash"
e2fsck -fn "$work/p4"
fsck.vfat -n "$work/p3"
losetup -d "$loop"
loop=

sfdisk --verify "$partial"
python3 - "$partial" <<'PY'
from pathlib import Path
import struct
import sys

with open('/stock', 'rb') as original, Path(sys.argv[1]).open('rb') as candidate:
    assert original.read(16777216) == candidate.read(16777216)
    for file in (original, candidate):
        file.seek(512)
    primary = candidate.read(512)
    original_primary = original.read(512)
    assert primary == original_primary
    backup = struct.unpack_from('<Q', primary, 32)[0]
    for file in (original, candidate):
        file.seek((backup - 32) * 512)
    assert original.read() == candidate.read()
PY
mv -T "$partial" "$image"
gzip -n -1 -c "$image" > "$image.gz.partial"
gzip -t "$image.gz.partial"
mv -T "$image.gz.partial" "$image.gz"
(cd /output && sha256sum "$1" "$1.gz" > "$1.sha256")
BUILD
