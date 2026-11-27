#!/bin/bash
# Repack a tested RK3566 SYSTEM with the current frontend and runtime names.
set -euo pipefail

if [ "$#" -lt 4 ] || [ "$#" -gt 5 ]; then
    echo "Usage: $0 BASE_SYSTEM BUBBLE_GIT RELEASE_VERSION NEW_OUTPUT_DIRECTORY [REBUILT_RETROARCH]" >&2
    exit 2
fi
prototype=$(cd "$(dirname "$0")" && pwd)
base=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
upstream=$2
version=$3
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || exit 2
mkdir "$4"
out=$(cd "$4" && pwd)
work=$(mktemp -d "$out/work.XXXXXXXX")
trap 'rm -rf "$work"' EXIT
revision=ec81d42c0c2c39e7a32973bfe4df9b3027512a5d
if [ "$#" -eq 5 ]; then
    install -m755 "$5" "$work/retroarch"
fi
mkdir "$work/source"
git -C "$upstream" archive "$revision" src/frontend src/services/plumos_bubble_volume_keys.c \
    package/frontend-bubble/plumos \
    package/network-services-bubble/plumos/bin/plumos-network-services \
    scripts/build-bubble-update-package.py | tar -xf - -C "$work/source"
"$prototype/prepare-rk3566-frontend.sh" "$work/source"
"$prototype/build-frontend-docker.sh" "$work" "$work/source/src/frontend"
sed -f "$prototype/update/configure-rk3566-update.sed" \
    "$work/source/scripts/build-bubble-update-package.py" > "$out/build-runtime-update.py"
chmod 755 "$out/build-runtime-update.py"

docker run --rm -i --platform linux/arm64 \
    -v "$base:/base:ro" -v "$prototype:/prototype:ro" \
    -v "$work:/build:ro" -v "$out:/out" \
    plumos-rk3566-runtime-tools:ec81d42 bash -s -- "$version" <<'BUILD'
set -euo pipefail
root=$(mktemp -d)
unsquashfs -quiet -no-progress -d "$root" /base
payload=$root/usr/lib/plumos-353m
frontend=$payload/frontend
grep -qx 'plumOS-RK3566 native userspace' "$payload/native-system"
for program in plumos-controller-ui plumos-library-scan plumos-text-ui plumos-frontend; do
    install -m755 "/build/compiled/$program" "$frontend/bin/$program"
done
install -m644 /build/source/package/frontend-bubble/plumos/share/frontend/lang/*.lang \
    "$frontend/share/frontend/lang/"
if [ -f /build/retroarch ]; then
    install -m755 /build/retroarch "$frontend/bin/retroarch"
    digest=$(sha256sum /build/retroarch | cut -d ' ' -f 1)
    sed -i "s|^[[:xdigit:]]\{64\}  bin/retroarch\$|$digest  bin/retroarch|" \
        "$frontend/components/retroarch/checksums.sha256"
fi
install -m755 /prototype/system/usr/lib/plumos-353m/mount-frontend "$payload/mount-frontend"
python3 /prototype/normalize-rk3566-runtime.py "$payload"
for file in "$frontend/VERSION" "$root/etc/plumos-system-version"; do
    printf '%s\n' "$1" > "$file"
done
python3 /prototype/emulators/verify-release-runtime.py "$frontend"
chroot "$root" /usr/lib/plumos-353m/frontend/bin/plumos-controller-ui --help >/dev/null
chroot "$root" /usr/lib/plumos-353m/frontend/bin/plumos-library-scan --help >/dev/null
mksquashfs "$root" /out/SYSTEM.partial -noappend -all-root -comp lzo -b 524288 -no-xattrs -no-progress
chmod 644 /out/SYSTEM.partial
mv /out/SYSTEM.partial /out/SYSTEM
BUILD
(cd "$out" && shasum -a 256 SYSTEM > SHA256SUMS)
