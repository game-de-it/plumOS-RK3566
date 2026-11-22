# Sourced by the JELOS storage hook after the selected SYSTEM is mounted.
plumos_select_init() {
    local config
    config=/storage/plumos-rk3566/init
    if [ -f "$config/next" ]; then
        rm "$config/next" || return 1
    elif [ ! -f "$config/default" ] || [ -e "$config/pending" ]; then
        return 1
    fi

    if ! { [ -x "$config/entry" ] && [ -x "$config/init" ] && [ -x "$config/power" ]; }; then
        printf 'plumOS init: incomplete payload\n' > /dev/kmsg
        return 1
    fi
    : > "$config/pending" || return 1
    sync
    if ! mount -o bind "$config/entry" /sysroot/usr/lib/systemd/systemd; then
        printf 'plumOS init: entry bind failed\n' > /dev/kmsg
        return 1
    fi
    : > /dev/plumos-native-init || {
        umount /sysroot/usr/lib/systemd/systemd
        return 1
    }
}

if plumos_select_init; then
    # SYSTEM selection and rollback are managed by boot-system in native mode.
    check_update() { :; }
fi
