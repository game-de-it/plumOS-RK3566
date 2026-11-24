#!/bin/sh
# Sourced by JELOS post-sysroot.sh, before its call to load_splash.
load_splash() {
    if "$plumos_splash_dir/boot-splash" "$plumos_splash_dir/boot-splash.xrgb" >/dev/plumos-boot-splash; then
        return 0
    else
        printf '\033[1000H\033[2K==> Loading, please wait...' >/dev/console
        printf '%s\n' 'framebuffer unavailable' >/dev/plumos-boot-splash
    fi
}
