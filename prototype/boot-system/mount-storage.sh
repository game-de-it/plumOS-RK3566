# Sourced by JELOS initramfs after the stock SYSTEM is mounted at /sysroot.
mount_part "$disk" /storage rw,noatime

plumos_select_system() {
    local state hash image staged stock
    state=/storage/plumos-rk3566/system
    staged=/dev/plumos-system-stage
    stock=/dev/plumos-system-stock

    if [ -f "$state/next" ]; then
        read -r hash < "$state/next" || return 0
        rm "$state/next" || return 0
        sync
    elif [ -f "$state/default" ] && [ ! -e "$state/pending" ]; then
        read -r hash < "$state/default" || return 0
    else
        return 0
    fi

    case "$hash" in ''|*[!0123456789abcdef]*) return 0 ;; esac
    [ "${#hash}" -eq 64 ] || return 0
    image="$state/$hash.squashfs"
    [ -f "$image" ] || return 0

    printf '%s\n' "$hash" > "$state/pending.new" || return 0
    mv "$state/pending.new" "$state/pending" || return 0
    sync
    mkdir -p "$staged" "$stock" || return 0
    if ! mount -t squashfs -o ro,loop "$image" "$staged"; then
        return 0
    fi
    if [ ! -r "$staged/usr/lib/plumos-353m/native-system" ] ||
       [ ! -x "$staged/usr/lib/plumos-353m/init" ] ||
       [ ! -x "$staged/usr/lib/plumos-353m/start-frontend" ] ||
       [ ! -x "$staged/usr/lib/plumos-353m/adbd" ]; then
        umount "$staged"
        return 0
    fi

    # Keep the stock mount available until the candidate has taken its place.
    if ! mount --move /sysroot "$stock"; then
        umount "$staged"
        return 0
    fi
    if ! mount --move "$staged" /sysroot; then
        mount --move "$stock" /sysroot || mount_part /flash/SYSTEM /sysroot ro,loop
        umount "$staged"
        return 0
    fi
    if ! printf '%s\n' "$hash" > /dev/plumos-system-active; then
        umount /sysroot
        mount --move "$stock" /sysroot || mount_part /flash/SYSTEM /sysroot ro,loop
        return 0
    fi
    umount "$stock" || :
}

plumos_select_system

if [ -r /sysroot/usr/lib/plumos-353m/native-system ]; then
    check_update() { :; }
fi
