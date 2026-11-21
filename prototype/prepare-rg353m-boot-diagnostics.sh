#!/bin/sh
set -eu

if [ "$#" -ne 1 ]; then
    printf 'Usage: %s extlinux.conf\n' "$0" >&2
    exit 2
fi

# This is the TF1 device path measured on the RG353M. Keep storage on its
# original UUID so a different card cannot be selected by device number.
config=$(awk '
    $1 == "APPEND" { append_lines++ }
    $1 == "APPEND" && / boot=UUID=0602-1646 / && / quiet / && / loglevel=0 / {
        sub(/ boot=UUID=0602-1646 /, " boot=/dev/mmcblk1p3 ")
        sub(/ quiet /, " debugging nopkmute ")
        sub(/ loglevel=0 /, " loglevel=4 ")
        changed++
    }
    { print }
    END { if (append_lines != 1 || changed != 1) exit 1 }
' "$1") || {
    printf '%s\n' 'Expected the original JELOS boot entry; no diagnostic config generated.' >&2
    exit 1
}
printf '%s\n' "$config"
