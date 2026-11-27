#!/bin/bash
# Exercise the packaged frontend and updater using a disposable image mount.
set -euo pipefail

if [ "$#" -ne 3 ]; then
    echo "Usage: $0 TEST_IMAGE RUNTIME_PACKAGE_BUILDER RK3566_SIGNING_KEY" >&2
    exit 2
fi
prototype=$(cd "$(dirname "$0")" && pwd)
absolute_file() {
    printf '%s/%s\n' "$(cd "$(dirname "$1")" && pwd)" "$(basename "$1")"
}
image=$(absolute_file "$1")
builder=$(absolute_file "$2")
key=$(absolute_file "$3")
test -f "$image" -a -f "$builder" -a -f "$key"

docker run --rm -i --privileged --network none --platform linux/arm64 \
    --tmpfs /overlay-test:exec,size=256m \
    -v "$image:/image:ro" -v "$builder:/builder:ro" -v "$key:/signing-key:ro" \
    -v "$prototype/update/rk3566-update-public.pem:/expected-public-key:ro" \
    plumos-rk3566-runtime-tools:ec81d42 bash -s <<'TEST'
set -euo pipefail
work=$(mktemp -d)
root=$work/root
flash=$work/flash
runtime=/storage/plumos-rk3566/frontend
template=$root/usr/lib/plumos-353m/frontend
inbox=/storage/user/updates
key=share/update/plumos-rk3566-update-public.pem
archive=plumos-rk3566-runtime-0.2.1-qa.tar.gz
mkdir "$flash"
loop=
cleanup() {
    umount "$root$runtime" "$root/storage/plumos-rk3566" \
        "$root/proc" "$root/dev/null" "$flash" 2>/dev/null || :
    if [ -n "$loop" ]; then losetup -d "$loop"; fi
    rm -rf "$work"
}
trap cleanup EXIT
read -r first size < <(sfdisk --json /image | python3 -c '
import json, sys
table = json.load(sys.stdin)["partitiontable"]
assert table["sectorsize"] == 512
partition = table["partitions"][2]
print(partition["start"], partition["size"])')
loop=$(losetup --find --show --read-only --offset "$((first * 512))" --sizelimit "$((size * 512))" /image)
mount -o ro "$loop" "$flash"
unsquashfs -quiet -no-progress -d "$root" "$flash/SYSTEM"
grep -qx '0.2.0' "$root/etc/plumos-system-version"
grep -qx '0.2.0' "$template/VERSION"
cmp /expected-public-key "$template/$key"
openssl pkey -in /signing-key -pubout | cmp "$template/$key" -
test ! -e "$template/share/update/plumos-bubble-update-public.pem"
test ! -e "$root$runtime/$key"

mkdir -p "$root"/{proc,dev,run/plumos-353m,storage/plumos-rk3566} "$root$inbox"
touch "$root/dev/null"
mount --bind /dev/null "$root/dev/null"
mount --bind /proc "$root/proc"
mount --bind /overlay-test "$root/storage/plumos-rk3566"
chroot "$root" /usr/lib/plumos-353m/mount-frontend
chroot "$root" /bin/grep -qs " $runtime overlay " /proc/mounts
cmp "$template/$key" "$root$runtime/$key"

run() {
    chroot "$root" /bin/busybox env \
        PLUMOS_ROOT="$runtime" PLUMOS_USERDATA_ROOT=/storage/user PLUMOS_SDCARD_ROOT=/storage/user \
        PLUMOS_RUNTIME_ROOT=/run/plumos-353m PLUMOS_SYSTEM_ROOT=/ \
        PLUMOS_BUSYBOX=/bin/busybox PLUMOS_DEVICE_ID=rg353m PLUMOS_DEVICE_NAME=RK3566 \
        PLUMOS_UPDATE_PROGRESS=0 PLUMOS_CONTROLLER_POWER_DRY_RUN=1 "$@"
}
update() { run "$runtime/bin/plumos-system-update" "$@"; }
menu() { run "$runtime/bin/plumos-controller-ui" --renderer text --no-clear --script "$1"; }

cp -al "$template" "$work/target"
rm "$work/target/VERSION"
printf '%s\n' 0.2.1-qa > "$work/target/VERSION"
printf '%s\n' 'Verified runtime payload' > "$work/target/share/update/qa-payload.txt"
pack() {
    python3 /builder --type runtime --input "$work/target" --base-dir "$template" \
        --base-version 0.2.0 --version 0.2.1-qa --signing-key "$1" --output-dir "$2"
}
openssl genpkey -algorithm ED25519 -out "$work/untrusted-key"
pack "$work/untrusted-key" "$root$inbox"
if update request-latest > "$work/untrusted.log" 2>&1; then
    echo 'System Update accepted an untrusted package.' >&2
    exit 1
fi
update scan | grep -F 'package signature verification failed'

pack /signing-key "$root$inbox"
(cd "$root$inbox" && sha256sum -c "$archive.sha256")
mv "$root$inbox/$archive" "$root$inbox/plumos-bubble-runtime-0.2.1-qa.tar.gz"
test -z "$(update scan)"
mv "$root$inbox/plumos-bubble-runtime-0.2.1-qa.tar.gz" "$root$inbox/$archive"
update scan | grep -F "$archive"
# START, System Settings, then down to the System Update row.
actions=start,down,a,down,down,down,down,down,down,down,down
menu "$actions" > "$work/menu.log"
if ! grep -E '^>.*System Update' "$work/menu.log" | tail -n 1; then
    tail -100 "$work/menu.log"
    exit 1
fi
menu "$actions,a" > "$work/submit.log"
grep -F 'Update verified; restarting safely' "$work/submit.log"
grep -F "$archive" "$root$runtime/logs/frontend-system-update.log"
grep -F "$archive" "$root$runtime/update-state/request.json"

update apply-pending
grep -qx '0.2.1-qa' "$root$runtime/VERSION"
grep -qx 'Verified runtime payload' "$root$runtime/share/update/qa-payload.txt"
update apply-pending
grep -qx '0.2.0' "$root$runtime/VERSION"
test ! -e "$root$runtime/share/update/qa-payload.txt"
grep -F '"result": "rolled_back"' "$root$runtime/update-state/last-result.json"
update request-latest >/dev/null
update apply-pending
update mark-healthy
update apply-pending
grep -qx '0.2.1-qa' "$root$runtime/VERSION"
grep -qx 'Verified runtime payload' "$root$runtime/share/update/qa-payload.txt"
grep -F '"result": "runtime_healthy"' "$root$runtime/update-state/last-result.json"
cmp "$template/$key" "$root$runtime/$key"
echo 'PASS: the shipped key and standard System Update menu applied and confirmed a signed RK3566 package.'
TEST
