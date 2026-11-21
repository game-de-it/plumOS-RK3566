#!/bin/bash
set -euo pipefail

if [ "$#" -ne 2 ] && [ "$#" -ne 4 ]; then
    printf 'Usage: %s original-extlinux.conf output-directory [aarch64-adbd aarch64-busybox-static]\n' "$0" >&2
    exit 2
fi

prototype=$(cd "$(dirname "$0")" && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
awk '
    $1 == "INITRD" { initrd++ }
    $1 == "APPEND" { append_lines++ }
    $1 == "APPEND" && / boot=UUID=0602-1646 / && !/rdinit=/ {
        print "  INITRD /plumos-sd-probe.cpio.gz"
        $0 = $0 " rdinit=/rg353m-sd-probe"
        changed++
    }
    { print }
    END { if (initrd || append_lines != 1 || changed != 1) exit 1 }
' "$1" > "$work/extlinux.probe"

install -m 755 "$prototype/rg353m-sd-probe" "$work/rg353m-sd-probe"
install -m 644 "$prototype/rg353m-boot-trace" "$work/rg353m-boot-trace"
if [ "$#" -eq 4 ]; then
    mkdir -p "$work/plumos-recovery/bin"
    install -m 755 "$3" "$work/plumos-recovery/adbd"
    install -m 755 "$4" "$work/plumos-recovery/bin/busybox"
    for applet in cat ln mkdir mount rm rmdir sleep tr umount; do
        ln -s busybox "$work/plumos-recovery/bin/$applet"
    done
    install -m 755 "$prototype/system/usr/lib/plumos-353m/start-adb" \
        "$work/plumos-recovery/start-adb"
fi
(
    cd "$work"
    set -- rg353m-sd-probe rg353m-boot-trace
    if [ -d plumos-recovery ]; then set -- "$@" plumos-recovery; fi
    find "$@" -print | cpio -o -H newc | gzip -n > plumos-sd-probe.cpio.gz
)
mkdir -p "$2"
install -m 644 "$work/extlinux.probe" "$work/plumos-sd-probe.cpio.gz" "$2/"
