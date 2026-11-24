#!/bin/bash
set -euo pipefail

if [ "$#" -ne 3 ]; then
    echo "Usage: $0 JELOS_UBOOT_CHECKOUT RK3568_BL31_ELF OUTPUT.itb" >&2
    exit 2
fi

prototype=$(cd "$(dirname "$0")" && pwd)
source=$(cd "$1" && pwd)
bl31=$(cd "$(dirname "$2")" && pwd)/$(basename "$2")
out_dir=$(cd "$(dirname "$3")" && pwd)
name=$(basename "$3")
revision=97c658238f7ccd436fbdede451bfd7488514a5c8
image=plumos-rk3566-uboot-tools:ec81d42
test "$(git -C "$source" rev-parse "$revision^{commit}")" = "$revision"
test "$(shasum -a 256 "$bl31" | cut -d ' ' -f 1)" = b2eabb56105e2b6f6c63a2aa8eca9408263f08fb68cf3f0b27c2419ad21a9963
test ! -e "$out_dir/$name"

if ! docker image inspect "$image" >/dev/null 2>&1; then
    docker build --platform linux/arm64 -t "$image" - < "$prototype/uboot-tools.Dockerfile"
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
git -C "$source" archive -o "$work/source.tar" "$revision"
docker run --rm -i --platform linux/arm64 \
    -v "$work/source.tar:/source.tar:ro" -v "$bl31:/bl31.elf:ro" \
    -v "$prototype/patches:/patches:ro" -v "$out_dir:/output" \
    "$image" bash -s -- "$name" <<'BUILD'
set -euo pipefail
mkdir /tmp/uboot
cd /tmp/uboot
tar -xf /source.tar
patch -p1 < /patches/rk3566-uboot-rgb30-regulator.patch
mkdir /tmp/bin
ln -s "$(command -v python3)" /tmp/bin/python
export PATH="/tmp/bin:$PATH"
export SOURCE_DATE_EPOCH=1705747971
export CROSS_COMPILE=aarch64-linux-gnu-
make rk3568_defconfig
grep -qx 'CONFIG_DM_I2C=y' .config
grep -qx 'CONFIG_USING_KERNEL_DTB=y' .config
make -j4 HOSTCC=gcc HOSTSTRIP=true PYTHON=python3 u-boot.dtb
make -j4 HOSTCC=gcc HOSTSTRIP=true PYTHON=python3 BL31=/bl31.elf \
    CONFIG_MKIMAGE_DTC_PATH=scripts/dtc/dtc u-boot.itb
tools/dumpimage -l u-boot.itb
test "$(stat -c %s u-boot.itb)" -le 4194304
for segment in atf-{1..6}; do
    test "$(fdtget -t s u-boot.itb "/images/$segment" type)" = firmware
done
strings u-boot.itb > /tmp/fit-strings
grep -Fx 'rk3566-rgb30r2-linux.dtb' /tmp/fit-strings
install -m 644 u-boot.itb "/output/$1.partial"
mv -T "/output/$1.partial" "/output/$1"
BUILD
