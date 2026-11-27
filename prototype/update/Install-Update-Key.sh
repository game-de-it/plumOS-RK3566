#!/bin/sh
set -eu

package=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
root=/storage/plumos-rk3566/frontend
public_key=$root/share/update/plumos-bubble-update-public.pem
engine=$root/share/update/plumos-system-update.py
factory_hash=82fa1071f07d066e89742e5c0bb7b06092f83fb39c5d75bfce1be41d2cdce269
release_hash=ffd8ac7879b6cdf9432f423c5670336709ffa802e2c63df89c891ac6ec8243a1
original_engine_hash=9db1cfd58ef3fa8f50fef2e55af79541afe2dcf765df6039b1e3cd27743f0cef
updated_engine_hash=fecdb11837562f45e7615493d2056bada4653f399e1da426ce3054ec5764b958

fail() {
    printf 'ERROR: %s\n' "$1"
    exit 1
}

exec 9>/run/plumos-system-update.lock
flock -n 9 || fail 'A system update is already running.'
exec >"$package/Update-Key.log" 2>&1

[ -e /dev/plumos-native-init ] && [ -x "$root/bin/plumos-system-update" ] ||
    fail 'This migration requires plumOS-RK3566.'
grep -qs " $root overlay " /proc/mounts ||
    fail 'The plumOS runtime layer is not mounted.'
for pending in request.json runtime-pending.json; do
    [ ! -e "$root/update-state/$pending" ] ||
        fail 'Finish the pending system update before installing the key.'
done
[ -f "$package/rk3566-update-public.pem" ] && [ -f "$package/update-filename.sed" ] ||
    fail 'Extract all files from the updated RK3566 migration ZIP.'
printf '%s  %s\n' "$release_hash" "$package/rk3566-update-public.pem" | sha256sum -c

version=$(cat "$root/VERSION")
key_hash=$(sha256sum "$public_key")
case "$version:${key_hash%% *}" in
    "0.1.1:$factory_hash"|"0.1.1:$release_hash"|"0.1.2:$release_hash") ;;
    *) fail 'Start the released RK3566 v0.1.1 or v0.1.2 runtime with its expected update key.' ;;
esac

temporary_key=
temporary_engine=
cleanup() {
    [ -z "$temporary_engine" ] || rm -f "$temporary_engine"
    [ -z "$temporary_key" ] || rm -f "$temporary_key"
}
trap cleanup EXIT

engine_hash=$(sha256sum "$engine")
case "${engine_hash%% *}" in
    "$updated_engine_hash") ;;
    "$original_engine_hash")
        temporary_engine=$(mktemp "$engine.XXXXXXXX")
        sed -f "$package/update-filename.sed" "$engine" >"$temporary_engine"
        printf '%s  %s\n' "$updated_engine_hash" "$temporary_engine" | sha256sum -c ||
            fail 'The updated System Update program failed verification.'
        chmod 644 "$temporary_engine"
        ;;
    *) fail 'The installed System Update program differs from the release.' ;;
esac
if [ "${key_hash%% *}" = "$factory_hash" ]; then
    temporary_key=$(mktemp "$public_key.XXXXXXXX")
    cp "$package/rk3566-update-public.pem" "$temporary_key"
    chmod 644 "$temporary_key"
fi

[ -z "$temporary_engine" ] || mv -f "$temporary_engine" "$engine"
[ -z "$temporary_key" ] || mv -f "$temporary_key" "$public_key"
sync
printf 'OK: The RK3566 release key is installed.\n'
printf 'OK: System Update recognizes plumos-rk3566-runtime packages.\n'
