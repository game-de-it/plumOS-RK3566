#!/bin/sh
# Run in the Bubble ARM64 container on a private copy of the JELOS raw image.
set -eu

image=$1
gib=$2
test -f "$image"
test "$(stat -c %s "$image")" = 2198863872
runtime_start=4227072
runtime_sectors=16777216
user_start=$((runtime_start + runtime_sectors))
image_bytes=$((gib * 1024 * 1024 * 1024))
user_end=$((image_bytes / 512 - 2049))
test "$user_end" -gt "$user_start"

work=$(mktemp -d)
loop=
mkdir "$work/runtime" "$work/user"
cleanup() {
    umount "$work/user" 2>/dev/null || :
    umount "$work/runtime" 2>/dev/null || :
    if [ -n "$loop" ]; then losetup -d "$loop"; fi
    rm -f "$work/before.json" "$work/after.json" "$work/p4" "$work/p5"
    rmdir "$work/runtime" "$work/user" "$work"
}
trap cleanup EXIT

# Save the original partition identities before moving GPT's backup header.
sfdisk --json "$image" > "$work/before.json"
truncate -s "$image_bytes" "$image"
parted -sf "$image" print
parted -s "$image" unit s resizepart 4 "$((user_start - 1))s"
parted -s "$image" unit s mkpart userdata fat32 "${user_start}s" "${user_end}s"
parted -s "$image" set 5 msftdata on
sfdisk --verify "$image"
sfdisk --json "$image" > "$work/after.json"
python3 - "$work" "$runtime_start" "$runtime_sectors" "$user_start" "$user_end" <<'PY'
import json
from pathlib import Path
import sys

work = Path(sys.argv[1])
runtime_start, runtime_size, user_start, user_end = map(int, sys.argv[2:])
before, after = (json.loads((work / f'{name}.json').read_text())['partitiontable']
                 for name in ('before', 'after'))
original = before['partitions']
prepared = after['partitions']
assert before['label'] == after['label'] == 'gpt'
assert before['id'] == after['id']
assert len(original) == 4 and len(prepared) == 5
assert original[:3] == prepared[:3]
assert original[3]['start'] == runtime_start and original[3]['size'] == 65536
assert prepared[3] == {**original[3], 'size': runtime_size}
assert prepared[4]['start'] == user_start
assert prepared[4]['size'] == user_end - user_start + 1
assert prepared[4]['type'].upper() == 'EBD0A0A2-B9E5-4433-87C0-68B6B72699C7'
PY

loop=$(losetup --find --show --partscan "$image")
for number in 4 5; do
    device=$(cat "/sys/class/block/${loop##*/}p$number/dev")
    mknod "$work/p$number" b "${device%:*}" "${device#*:}"
done
runtime=$work/p4
user=$work/p5
runtime_uuid=b839c001-95ff-4847-9189-45670cde3fb8
test "$(blkid -s UUID -o value "$runtime")" = "$runtime_uuid"
# e2fsck returns 1 when it has successfully corrected the filesystem.
status=0
e2fsck -pf "$runtime" || status=$?
test "$status" -le 1
resize2fs "$runtime"
mkfs.vfat -F 32 -n PLUMOS "$user"

mount -t ext4 "$runtime" "$work/runtime"
mount -t vfat "$user" "$work/user"
test -f "$work/runtime/.please_resize_me"
mkdir "$work/runtime/user" "$work/user/Roms" "$work/user/BIOS" "$work/user/Images"
for directory in Roms BIOS Images; do
    ln -s "user/$directory" "$work/runtime/$directory"
done
blkid -s PARTUUID -o value "$user" > "$work/runtime/.plumos-user-layout"
test -s "$work/runtime/.plumos-user-layout"
rm "$work/runtime/.please_resize_me"
sync
umount "$work/user"
umount "$work/runtime"
e2fsck -fn "$runtime"
fsck.vfat -n "$user"
test "$(blkid -p -s UUID -o value "$runtime")" = "$runtime_uuid"
test "$(blkid -p -s LABEL -o value "$user")" = PLUMOS
