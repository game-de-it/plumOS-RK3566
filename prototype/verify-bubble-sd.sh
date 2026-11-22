#!/bin/bash
set -euo pipefail

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 PLUMOS.img" >&2
    exit 2
fi
image=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
test -f "$image"
docker run --rm -i --privileged --user 0 --platform linux/arm64 \
    --mount "type=bind,source=$image,target=/image,readonly" \
    plumos-rk3566-bubble-tools:ec81d42 bash -s <<'TEST'
set -euo pipefail
work=$(mktemp -d)
root="$work/root"
loop=
cleanup() {
    for target in "$root/sysroot" "$root/storage/user" "$root/storage" "$root/flash" "$root/proc" "$root/sys" "$root/dev"; do
        if mountpoint -q "$target"; then umount "$target"; fi
    done
    if [ -n "$loop" ]; then losetup -d "$loop"; fi
}
trap cleanup EXIT

node() {
    local path=$1 part=$2 info
    info=$(cat "/sys/class/block/${loop##*/}p$part/dev")
    mknod "$path" b "${info%:*}" "${info#*:}"
}
prefix() { dd if="$work/card.img" bs=512 skip=34 count=32734 status=none | sha256sum; }
cp --sparse=always /image "$work/card.img"
expected=$(prefix)
sfdisk --json "$work/card.img" > "$work/before.json"
truncate -s 8G "$work/card.img"
loop=$(losetup --find --show --partscan "$work/card.img")
mkdir "$work/flash"
node "$work/p3" 3
mount -o ro "$work/p3" "$work/flash"
test -r "$work/flash/post-sysroot.sh"
test -x "$work/flash/plumos-splash/boot-splash"
test "$(stat -c %s "$work/flash/plumos-splash/boot-splash.xrgb")" = 1228800
unsquashfs -no-progress -d "$root" "$work/flash/SYSTEM"
umount "$work/flash"
mkdir -p "$root/flash" "$root/storage" "$root/dev" "$root/proc" "$root/sys" "$root/sysroot"
mount --bind /dev "$root/dev"
mount --bind /proc "$root/proc"
mount --bind /sys "$root/sys"

mount_card() {
    local part
    for part in 3 4 5; do
        if [ -e "/sys/class/block/${loop##*/}p$part/dev" ]; then
            rm -f "${loop}p$part"
            node "${loop}p$part" "$part"
        fi
    done
    mount -o ro "${loop}p3" "$root/flash"
    mount "${loop}p4" "$root/storage"
}
detach_card() {
    umount "$root/storage"
    umount "$root/flash"
    losetup -d "$loop"
    loop=
}
provision() { chroot "$root" /bin/sh /storage/plumos-rk3566/provision/provision-storage "$loop"; }

mount_card
test ! -e "$root/storage/.please_resize_me"
test ! -e "/sys/class/block/${loop##*/}p5"
result=0
provision || result=$?
test "$result" = 75
detach_card
loop=$(losetup --find --show --partscan "$work/card.img")
mount_card
test -b "${loop}p5"
test "$(cat "/sys/class/block/${loop##*/}p4/size")" = 8388608
# A recognized foreign filesystem must survive a provisioning attempt.
mkfs.ext4 -q -F "${loop}p5"
if provision; then exit 1; fi
test "$(blkid -p -s TYPE -o value "${loop}p5")" = ext4
wipefs -a "${loop}p5"
provision
test -d "$root/storage/user/Roms" -a -d "$root/storage/user/BIOS" -a -d "$root/storage/user/Images"
printf '%s\n' retained > "$root/storage/user/Roms/provision-test.txt"
umount "$root/storage/user"
provision
grep -qx retained "$root/storage/user/Roms/provision-test.txt"
umount "$root/storage/user"

# Verify that the shipped SYSTEM can be used as recovery independently of p4's selected update.
cp "$root/flash/SYSTEM" "$root/storage/plumos-rk3566/system/SYSTEM.partial"
digest=$(sha256sum "$root/flash/SYSTEM" | cut -d ' ' -f 1)
chroot "$root" /bin/sh -s -- "$digest" <<'UPDATE'
set -eu
state=/storage/plumos-rk3566/system
"$state/boot-system" publish "$1"
"$state/boot-system" trial "$1"
mount -o ro,loop /flash/SYSTEM /sysroot
mount_part() { test "$1" = mock && test "$2" = /storage; }
disk=mock
. /flash/mount-storage.sh
test "$(cat /dev/plumos-system-active)" = "$1"
test "$(cat "$state/pending")" = "$1"
test ! -e "$state/next"
test -x /sysroot/usr/lib/plumos-353m/adbd
test -x /sysroot/usr/lib/plumos-353m/start-frontend
umount /sysroot
rm /dev/plumos-system-active
"$state/boot-system" stock
mount -o ro,loop /flash/SYSTEM /sysroot
. /flash/mount-storage.sh
test ! -e /dev/plumos-system-active
test -L /sysroot/usr/lib/systemd/system/jelos.target.wants/plumos-usb-adb.service
umount /sysroot
UPDATE
detach_card
test "$(prefix)" = "$expected"
sfdisk --verify "$work/card.img"
sfdisk --json "$work/card.img" > "$work/after.json"
python3 - "$work" <<'PY'
import json
from pathlib import Path
import sys

work = Path(sys.argv[1])
before, after = [json.loads((work / f'{name}.json').read_text())['partitiontable'] for name in ('before', 'after')]
assert before['id'] == after['id']
assert before['partitions'][:3] == after['partitions'][:3]
assert after['partitions'][3] == {**before['partitions'][3], 'size': 8388608}
assert after['partitions'][4]['start'] == 12615680
PY
echo 'First boot, reboot continuation, existing user data, SYSTEM update and recovery verified.'
TEST
