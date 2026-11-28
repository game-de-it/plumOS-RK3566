#!/bin/bash
# Prepare the pinned frontend sources for the common RK3566 runtime.
set -euo pipefail

prototype=$(cd "$(dirname "$0")" && pwd)
source=$1
patch -d "$source" -p1 < "$prototype/patches/rg353m-start-menu.patch"
patch -d "$source" -p1 < "$prototype/patches/rg353m-start-helpers.patch"
patch -d "$source" -p1 < "$prototype/patches/rg353m-audio.patch"
patch -d "$source" -p1 < "$prototype/patches/rk3566-rgb10max3-panel.patch"
patch -d "$source" -p1 < "$prototype/patches/rg353m-power-overlay-drm.patch"
patch -d "$source" -p1 < "$prototype/patches/rg353m-power-overlay-input.patch"
patch -d "$source" -p1 < "$prototype/patches/rg353m-brightness-keys.patch"
python3 "$prototype/emulators/enable-frontend-builtins.py" "$source/src/frontend"
python3 "$prototype/brand-rk3566-frontend.py" "$source"
patch -d "$source" -p1 < "$prototype/patches/rk3566-square-layout.patch"
patch -d "$source" -p1 < "$prototype/patches/rk3566-gallery-layout.patch"
patch -d "$source" -p1 < "$prototype/patches/rk3566-settings-footer-fit.patch"
patch -d "$source" -p1 < "$prototype/patches/rk3566-fe-scroll.patch"
patch -d "$source" -p1 < "$prototype/patches/rk3566-ppsspp-label.patch"
patch -d "$source" -p1 < "$prototype/patches/rk3566-psp-eboot-title.patch"
