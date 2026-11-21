#!/bin/bash
# Install the r3 branding and tested controller UI on an existing prototype SD.
set -euo pipefail

if [ "$#" -ne 1 ] || [ ! -f "$1" ]; then
    printf 'Usage: %s path/to/corrected/plumos-controller-ui\n' "$0" >&2
    exit 2
fi
prototype=$(cd "$(dirname "$0")" && pwd)
adb=${ADB:-"$prototype/../output/adb"}
if [ ! -x "$adb" ]; then
    adb=$(command -v adb)
fi
if [ "$("$adb" shell 'tr -d "\000" </proc/device-tree/model')" != 'Anbernic RG353M' ]; then
    echo 'Select an Anbernic RG353M via ANDROID_SERIAL.' >&2
    exit 1
fi
"$adb" shell 'test -r /usr/lib/plumos-353m/frontend-source'

local_stage=$(mktemp -d)
remote_stage=
cleanup() {
    if [ -n "$remote_stage" ]; then
        "$adb" shell "rm -rf '$remote_stage'" || true
    fi
    rm -rf "$local_stage"
}
trap cleanup EXIT

cp "$prototype/system/etc/issue" "$local_stage/issue"
cp "$1" "$local_stage/plumos-controller-ui"
(cd "$local_stage" && shasum -a 256 issue plumos-controller-ui > SHA256SUMS)
remote_stage=$("$adb" shell 'mktemp -d /storage/.plumos-353m-deploy.XXXXXXXX')
case "$remote_stage" in
    /storage/.plumos-353m-deploy.*) ;;
    *) remote_stage=; echo 'Unexpected staging directory.' >&2; exit 1 ;;
esac
"$adb" push "$local_stage/issue" "$local_stage/plumos-controller-ui" "$local_stage/SHA256SUMS" "$remote_stage/"
"$adb" shell -T "sh -s -- '$remote_stage'" <<'REMOTE'
set -eu
cd "$1"
sha256sum -c SHA256SUMS
hook=/flash/post-sysroot.sh
tag='# plumOS-353M boot overlay'
if [ -e "$hook" ] && [ "$(head -n 1 "$hook")" != "$tag" ]; then
    echo 'An existing post-sysroot.sh must be reviewed before installing.' >&2
    exit 1
fi
mount -o remount,rw /flash
trap 'sync; mount -o remount,ro /flash' EXIT
slot=$(mktemp -d /flash/plumos-353m-live.XXXXXXXX)
cp issue plumos-controller-ui SHA256SUMS "$slot/"
(cd "$slot" && sha256sum -c SHA256SUMS)
{
    printf '%s\n' "$tag"
    printf "(\nplumos_assets='%s'\n" "$slot"
    cat <<'HOOK'
    cd "$plumos_assets" || exit 0
    /usr/bin/busybox sha256sum -c SHA256SUMS >/dev/null 2>&1 || exit 0
    /usr/bin/busybox mount -o bind "$plumos_assets/issue" /sysroot/etc/issue || :
    /usr/bin/busybox mount -o bind "$plumos_assets/plumos-controller-ui" \
        /sysroot/usr/lib/plumos-353m/frontend/bin/plumos-controller-ui || :
)
HOOK
} > "$slot/post-sysroot.sh"
sh -n "$slot/post-sysroot.sh"
if [ -f "$hook" ]; then
    cp "$hook" /flash/post-sysroot.sh.previous
fi
sync
mv "$slot/post-sysroot.sh" "$hook"
sync
printf 'Staged boot overlay in %s\n' "$slot"
REMOTE
