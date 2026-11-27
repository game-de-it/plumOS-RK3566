#!/bin/bash
set -euo pipefail

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 JELOS_SYSTEM ROOTFS_DIRECTORY" >&2
    exit 2
fi

kernel=4.19.172
module=usr/lib/kernel-overlays/base/lib/modules/$kernel/kernel/drivers/net/wireless/rockchip_wlan/rtl8723ds/8723ds.ko
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
unsquashfs -no-progress -d "$work" "$1" "$module"
source=$work/$module
test "$(modinfo -F vermagic "$source")" = "$kernel SMP mod_unload aarch64"
test -z "$(modinfo -F depends "$source")"
modinfo -F alias "$source" | grep -Fx 'sdio:c*v024CdD723*'
readelf -Ws "$source" | awk '
    $8 == "array_mp_8723d_fw_nic" && $3 > 0 && $4 == "OBJECT" { found=1 }
    END { exit !found }
'

# Keep the module outside kmod's global SDIO aliases. The network wrapper
# loads it only when the RGB10 Max 3 and its Realtek SDIO device are present.
install -D -m644 "$source" "$2/usr/lib/plumos-353m/hardware/rgb10max3/8723ds.ko"
