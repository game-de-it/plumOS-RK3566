#!/bin/sh
set -eu

package=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
state=/storage/plumos-rk3566/system
boot_system=$state/boot-system
source_hash=00077569e177dbc16ae429002532f882358f17aca74573b5fa58fd7efdf2c43e
target_hash=1d3b99b4faaa1248cdd74f4eea53a39fd9326a81ebe74c53b217e18a7b2ad706
candidate=$state/$target_hash.squashfs
transfer=$state/.sd-update-v0.1.1.partial

fail() {
    printf 'ERROR: %s\n' "$1"
    exit 1
}

exec 9>/run/plumos-sd-update.lock
flock -n 9 || fail 'Another SD update is running.'
exec >"$package/Update.log" 2>&1

[ -e /dev/plumos-native-init ] && [ -x "$boot_system" ] ||
    fail 'This update requires a running plumOS-RK3566 system.'
grep -qs ' /storage ext4 ' /proc/mounts ||
    fail 'The TF1 update partition is not mounted.'
grep -qs ' /storage/user vfat ' /proc/mounts ||
    fail 'The TF1 PLUMOS user partition is not mounted.'
version=$(cat /etc/plumos-system-version)
active=$(cat /dev/plumos-system-active 2>/dev/null || :)
if [ "$active" = "$target_hash" ]; then
    [ "$version" = 0.1.1 ] || fail 'Unexpected version in the active SYSTEM.'
    [ -s /run/plumos-353m/boot-ready ] || fail 'Wait for Bubble to finish starting.'
    [ ! -e "$state/next" ] || fail 'Another trial is already scheduled.'
    "$boot_system" keep
    printf 'OK: v0.1.1 is the default SYSTEM.\n'
    exit 0
fi

[ "$version" = 0.1.0 ] && { [ -z "$active" ] || [ "$active" = "$source_hash" ]; } ||
    fail 'Start the original v0.1.0 SYSTEM before applying this update.'
default=$(cat "$state/default" 2>/dev/null || :)
[ ! -e "$state/pending" ] && { [ -z "$default" ] || [ "$default" = "$source_hash" ]; } ||
    fail 'A different SYSTEM selection or unfinished trial needs attention.'
if [ -e "$state/next" ]; then
    [ "$(cat "$state/next")" = "$target_hash" ] ||
        fail 'Another trial is already scheduled.'
else
    if [ "$transfer" -ef "$state/SYSTEM.partial" ]; then
        rm "$state/SYSTEM.partial"
    fi
    rm -f "$transfer"
    if [ -f "$candidate" ]; then
        printf '%s  %s\n' "$target_hash" "$candidate" | sha256sum -c
    else
        [ ! -e "$state/SYSTEM.partial" ] || fail 'A SYSTEM transfer already exists.'
        [ -f "$package/SYSTEM" ] || fail 'Extract the entire update folder to TF1.'
        cp "$package/SYSTEM" "$transfer"
        ln "$transfer" "$state/SYSTEM.partial"
        if ! "$boot_system" publish "$target_hash"; then
            rm -f "$state/SYSTEM.partial" "$transfer"
            fail 'The staged SYSTEM could not be published.'
        fi
        rm "$transfer"
    fi
    "$boot_system" trial "$target_hash"
fi
printf 'OK: v0.1.1 trial scheduled. Reboot from Bubble, then run this script again.\n'
