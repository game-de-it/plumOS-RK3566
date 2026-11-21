#!/bin/sh
set -eu

if [ "$#" -ne 3 ]; then
    printf 'Usage: %s stock-rg353m.dtb diagnostic-extlinux.conf output-directory\n' "$0" >&2
    exit 2
fi

source_dtb=$1
source_config=$2
output=$3
tf1=/dwmmc@fe2b0000
dtb=rk3566-rg353m-tf1-poll.dtb
[ "$(fdtget -t s "$source_dtb" / model)" = 'Anbernic RG353M' ]
[ "$(fdtget -t s "$source_dtb" /aliases mmc1)" = "$tf1" ]
[ "$(fdtget -t s "$source_dtb" "$tf1" status)" = okay ]

config=$(awk -v dtb="$dtb" '
    $1 == "FDT" || $1 == "FDTDIR" { entries++ }
    $1 == "FDTDIR" && $2 == "/" { $0 = "  FDT /" dtb; changed++ }
    { print }
    END { if (entries != 1 || changed != 1) exit 1 }
' "$source_config")

mkdir -p "$output"
cp "$source_dtb" "$output/$dtb"
fdtput "$output/$dtb" "$tf1" broken-cd
printf '%s\n' "$config" > "$output/extlinux.tf1-poll"
