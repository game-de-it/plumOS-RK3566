#!/bin/sh
set -eu

package=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
root=/storage/plumos-rk3566/frontend
public_key=$root/share/update/plumos-bubble-update-public.pem
factory_hash=82fa1071f07d066e89742e5c0bb7b06092f83fb39c5d75bfce1be41d2cdce269
release_hash=ffd8ac7879b6cdf9432f423c5670336709ffa802e2c63df89c891ac6ec8243a1

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
[ -f "$package/rk3566-update-public.pem" ] || fail 'Extract both migration files.'
printf '%s  %s\n' "$release_hash" "$package/rk3566-update-public.pem" | sha256sum -c
if cmp -s "$package/rk3566-update-public.pem" "$public_key"; then
    printf 'OK: The RK3566 release key is already installed.\n'
    exit 0
fi
[ "$(cat "$root/VERSION")" = 0.1.1 ] || fail 'Start the released v0.1.1 runtime first.'
printf '%s  %s\n' "$factory_hash" "$public_key" | sha256sum -c ||
    fail 'The installed key is not the v0.1.1 factory key.'

temporary_key=$(mktemp "$public_key.XXXXXXXX")
trap 'unlink "$temporary_key" 2>/dev/null || :' EXIT
cp "$package/rk3566-update-public.pem" "$temporary_key"
chmod 644 "$temporary_key"
mv "$temporary_key" "$public_key"
sync
printf 'OK: The RK3566 release key is installed.\n'
