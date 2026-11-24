#!/bin/bash
# Assemble the device userspace independently of the boot image.
set -euo pipefail
if [ "$#" -ne 4 ]; then
    echo "Usage: $0 KERNEL_SUPPORT_SYSTEM PLUMOS_LAYER OUTPUT_SYSTEM BUBBLE_SHADOW" >&2
    exit 2
fi

prototype=$(cd "$(dirname "$0")" && pwd)
support=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
layer=$(cd "$2" && pwd)
out=$(cd "$(dirname "$3")" && pwd)
name=$(basename "$3")
shadow=$(cd "$(dirname "$4")" && pwd)/$(basename "$4")
test -s "$support"
test -s "$shadow"
test -x "$layer/usr/lib/plumos-353m/start-frontend"
test ! -e "$out/$name"
test ! -e "$out/$name.partial"
image=plumos-rk3566-runtime-tools:ec81d42
docker build --platform linux/arm64 -t "$image" - < "$prototype/runtime-tools.Dockerfile"
docker run --rm -i --platform linux/arm64 \
    -v "$support:/support:ro" -v "$shadow:/bubble-shadow:ro" \
    -v "$layer:/layer:ro" -v "$prototype:/prototype:ro" \
    -v "$out:/out" "$image" bash -s -- "$name" <<'BUILD'
set -euo pipefail
root=$(mktemp -d)
kernel=4.19.172
modules=usr/lib/kernel-overlays/base/lib/modules/$kernel
firmware=usr/lib/kernel-overlays/base/lib/firmware
driver=$modules/kernel/drivers/net/wireless/rockchip_wlan/rtl8821cs/8821cs.ko
mkdir -p "$root"/{dev,etc,flash,proc,run,storage,sys,tmp,var,usr/bin,usr/sbin,usr/lib/systemd,usr/share}
chmod 1777 "$root/tmp"
ln -s usr/bin "$root/bin"
ln -s usr/sbin "$root/sbin"
ln -s usr/lib "$root/lib"
install -m755 /bin/busybox "$root/usr/bin/busybox"
while read -r applet; do
    case "$applet" in */*|'['|'[['|busybox|init|linuxrc) continue ;; esac
    ln -s busybox "$root/usr/bin/$applet"
done < <(/bin/busybox --list)

copy_libraries() {
    ldd "$1" | awk '
        /not found/ { print > "/dev/stderr"; failed=1 }
        /=> \// {print $3}
        /^[[:space:]]*\// {print $1}
        END {exit failed}
    ' | while read -r library; do
        install -D -m755 "$library" "$root$library"
    done
}
copy_binary() {
    local binary dest
    binary=$(command -v "$1")
    dest="$root/usr/bin/$1"
    rm -f "$dest"
    install -m755 "$binary" "$dest"
    copy_libraries "$binary"
}

for command in amixer aplay alsactl bash blkid depmod dropbear dropbearkey e2fsck \
    findmnt flock fsck.vfat lsblk mkfs.vfat modprobe mount openssl resize2fs sfdisk smbd stdbuf \
    umount unzip wpa_cli wpa_supplicant; do
    copy_binary "$command"
done
install -D -m755 /usr/lib/openssh/sftp-server "$root/usr/lib/openssh/sftp-server.real"
copy_libraries /usr/lib/openssh/sftp-server
install -m755 /prototype/system/usr/lib/plumos-353m/sftp-server "$root/usr/lib/openssh/sftp-server"
ln -s openssh/sftp-server "$root/usr/lib/sftp-server"
mkdir -p "$root/usr/lib/aarch64-linux-gnu"
cp -a /usr/lib/aarch64-linux-gnu/samba "$root/usr/lib/aarch64-linux-gnu/"
cp -a /usr/lib/aarch64-linux-gnu/gconv "$root/usr/lib/aarch64-linux-gnu/"
for worker in /usr/libexec/samba/samba-dcerpcd /usr/libexec/samba/rpcd_*; do
    install -D -m755 "$worker" "$root$worker"
    copy_libraries "$worker"
done

# Resolve ARM64 SONAMEs supplied by the toolchain for Bubble's executable payloads.
# Private dependencies remain beside the corresponding component in the app layer.
mkdir -p "$root/usr/lib/aarch64-linux-gnu"
for soname in libasound.so.2 libboost_atomic.so.1.74.0 libboost_chrono.so.1.74.0 \
    libboost_date_time.so.1.74.0 libboost_filesystem.so.1.74.0 libboost_locale.so.1.74.0 \
    libboost_system.so.1.74.0 libboost_thread.so.1.74.0 libcurl.so.4 libdrm.so.2 \
    libexpat.so.1 libfmt.so.9 libfreetype.so.6 libgbm.so.1 libgif.so.7 libglib-2.0.so.0 \
    libgomp.so.1 libjpeg.so.62 libluajit-5.1.so.2 libmodplug.so.1 libnsl.so.2 libopenal.so.1 \
    libpng16.so.16 libSDL-1.2.so.0 libSDL2-2.0.so.0 libSDL2_gfx-1.0.so.0 \
    libSDL2_image-2.0.so.0 libSDL2_ttf-2.0.so.0 libsndfile.so.1 libspeexdsp.so.1 \
    libsqlite3.so.0 libstdc++.so.6 libudev.so.1 libxmp.so.4; do
    library=/usr/lib/aarch64-linux-gnu/$soname
    install -m755 "$library" "$root$library"
    copy_libraries "$library"
done
for soname in libSDL2-2.0.so.0 libasound.so.2; do
    ln -s "aarch64-linux-gnu/$soname" "$root/usr/lib/$soname"
done
cp -a /usr/share/alsa /usr/share/zoneinfo "$root/usr/share/"
install -D -m644 /etc/ssl/certs/ca-certificates.crt "$root/etc/ssl/certs/ca-certificates.crt"
printf 'root:x:0:0:root:/storage:/bin/sh\n' > "$root/etc/passwd"
install -m600 /dev/null "$root/etc/shadow"
# Keep the same root credential as the pinned Bubble SYSTEM build.
awk -F: '$1 == "root" {print}' /bubble-shadow > "$root/etc/shadow"
test "$(wc -l < "$root/etc/shadow")" -eq 1
cut -d: -f2 "$root/etc/shadow" | grep -Eq '^\$6\$[./a-zA-Z0-9-]{1,16}\$[./a-zA-Z0-9]{86}$'
printf 'root:x:0:\naudio:x:29:\ninput:x:104:\nvideo:x:44:\n' > "$root/etc/group"
printf 'hosts: files dns\n' > "$root/etc/nsswitch.conf"
printf '127.0.0.1 localhost\n' > "$root/etc/hosts"
ln -s /run/resolv.conf "$root/etc/resolv.conf"
printf 'NAME="plumOS"\nID=plumos\nPRETTY_NAME="plumOS-RK3566"\n' > "$root/etc/os-release"
install -m644 /layer/usr/lib/plumos-353m/frontend/VERSION "$root/etc/plumos-system-version"

# Keep the 4.19 hardware ABI used by the preserved boot kernel. Only board support
# files are read from the reference image, plus the matching vendor Mali driver.
hardware=$(mktemp -d)
unsquashfs -no-progress -d "$hardware" /support "$driver" \
    "$firmware/rtl8821c_config" "$firmware/rtl8821c_fw" usr/lib/libmali.so.1.9.0
install -D -m644 "$hardware/$driver" "$root/usr/lib/modules/$kernel/${driver##*/}"
touch "$root/usr/lib/modules/$kernel/"{modules.order,modules.builtin,modules.builtin.modinfo}
depmod -b "$root" "$kernel"
mkdir -p "$root/${modules%/*}"
ln -s "../../../../modules/$kernel" "$root/$modules"
install -D -m644 "$hardware/$firmware/rtl8821c_config" "$root/usr/lib/firmware/rtl8821c_config"
install -D -m644 "$hardware/$firmware/rtl8821c_fw" "$root/usr/lib/firmware/rtl8821c_fw"
install -m644 "$hardware/usr/lib/libmali.so.1.9.0" "$root/usr/lib/"
for library in libmali.so.1 libEGL.so.1 libGLESv1_CM.so.1 libGLESv2.so.2; do
    ln -s libmali.so.1.9.0 "$root/usr/lib/$library"
done

cp -a /layer/usr/lib/plumos-353m "$root/usr/lib/"
install -m644 /prototype/system/etc/issue "$root/etc/issue"
payload=$root/usr/lib/plumos-353m
install -m755 /prototype/boot-system/init "$payload/init"
cc -static -O2 -Wall -Wextra -o "$payload/power" /prototype/boot-system/power.c
cc -static -O2 -Wall -Wextra -o "$payload/rgb30-menu-chord" /prototype/emulators/rgb30-menu-chord.c
python3 /prototype/emulators/configure-retroarch-aspect.py "$payload/frontend"
python3 /prototype/emulators/configure-rgb30-menu-chords.py "$payload/frontend"
python3 /prototype/configure-ssh-auth.py "$payload/frontend"
# The preserved initramfs requires this pathname at check and switch_root.
ln -s ../plumos-353m/init "$root/usr/lib/systemd/systemd"
ln -s /usr/lib/plumos-353m/init "$root/sbin/init"
printf '%s\n' 'plumOS-RK3566 native userspace' > "$payload/native-system"

test -x "$root/usr/lib/systemd/systemd"
chroot "$root" /bin/sh -n /usr/lib/plumos-353m/init
chroot "$root" /usr/lib/plumos-353m/frontend/bin/plumos-controller-ui --help >/dev/null
chroot "$root" /usr/lib/plumos-353m/frontend/bin/plumos-library-scan --help >/dev/null
chroot "$root" /usr/bin/wpa_supplicant -v >/dev/null
chroot "$root" /usr/bin/smbd --version >/dev/null
network_applets=$(chroot "$root" /usr/lib/plumos-353m/frontend/network-services/bin/busybox --list)
for applet in ftpd ntpd tcpsvd; do
    grep -qx "$applet" <<< "$network_applets"
done
mksquashfs "$root" "/out/$1.partial" -noappend -all-root -comp lzo -b 524288 -no-xattrs -no-progress
chmod 644 "/out/$1.partial"
mv "/out/$1.partial" "/out/$1"
BUILD
