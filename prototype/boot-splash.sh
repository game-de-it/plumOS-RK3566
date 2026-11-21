#!/bin/sh
# Sourced by JELOS post-sysroot.sh, before its call to load_splash.
load_splash() {
    if "$plumos_splash_dir/boot-splash" "$plumos_splash_dir/boot-splash.xrgb"; then
        printf '%s\n' 'framebuffer: 640x480 XRGB8888' >/dev/plumos-boot-splash
    else
        printf '\033[1000H\033[2K==> Loading, please wait...' >/dev/console
        printf '%s\n' 'framebuffer unavailable' >/dev/plumos-boot-splash
    fi
}
