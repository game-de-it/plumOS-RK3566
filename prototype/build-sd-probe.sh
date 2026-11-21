#!/bin/bash
set -euo pipefail

if [ "$#" -ne 2 ]; then
    printf 'Usage: %s original-extlinux.conf output-directory\n' "$0" >&2
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
(
    cd "$work"
    printf '%s\n' rg353m-sd-probe | cpio -o -H newc | gzip -n > plumos-sd-probe.cpio.gz
)
mkdir -p "$2"
install -m 644 "$work/extlinux.probe" "$work/plumos-sd-probe.cpio.gz" "$2/"
