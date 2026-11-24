#!/bin/sh
set -eu

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 STOCK_RGB30_DTB OUTPUT_DTB" >&2
    exit 2
fi

source_dtb=$1
output=$2
node=/i2c@fdd40000/tcs4525@1c
replacement=/i2c@fdd40000/fan53555@40

test "$(fdtget -t s "$source_dtb" / model)" = 'Powkiddy RGB30'
test "$(fdtget -t s "$source_dtb" "$node" compatible)" = tcs,tcs452x
test "$(fdtget -t x "$source_dtb" "$node" reg)" = 1c
test "$(fdtget -t x "$source_dtb" "$node" phandle)" = "$(fdtget -t x "$source_dtb" /cpus/cpu@0 cpu-supply)"
test "$(fdtget -t s "$source_dtb" /__symbols__ vdd_cpu)" = "$node"
test -z "$(fdtget -l "$source_dtb" /i2c@fdd40000 | sed -n '/@40$/p')"

work=$(mktemp -d "$(dirname "$output")/.rgb30-cpu-dtb.XXXXXX")
trap 'rm -rf "$work"' EXIT
dtc -q -I dtb -O dts -o "$work/stock.dts" "$source_dtb"
sed '
    /tcs4525@1c {/,/regulator-state-mem {/ {
        s/tcs4525@1c {/fan53555@40 {/
        s/"tcs,tcs452x"/"fcs,fan53555"/
        s/reg = <0x1c>;/reg = <0x40>;/
        s/regulator-min-microvolt = <0xadf34>;/regulator-min-microvolt = <720000>;/
        s/regulator-max-microvolt = <0x1535b0>;/regulator-max-microvolt = <1230000>;/
    }
    s|"/i2c@fdd40000/tcs4525@1c"|"/i2c@fdd40000/fan53555@40"|
' "$work/stock.dts" > "$work/fan53555.dts"
dtc -q -I dts -O dtb -o "$work/result.dtb" "$work/fan53555.dts"
test "$(fdtget -t s "$work/result.dtb" "$replacement" compatible)" = fcs,fan53555
test "$(fdtget -t x "$work/result.dtb" "$replacement" reg)" = 40
test "$(fdtget -t u "$work/result.dtb" "$replacement" regulator-min-microvolt)" = 720000
test "$(fdtget -t u "$work/result.dtb" "$replacement" regulator-max-microvolt)" = 1230000
test "$(fdtget -t x "$work/result.dtb" "$replacement" phandle)" = "$(fdtget -t x "$source_dtb" "$node" phandle)"
test "$(fdtget -t s "$work/result.dtb" /__symbols__ vdd_cpu)" = "$replacement"
mv "$work/result.dtb" "$output"
