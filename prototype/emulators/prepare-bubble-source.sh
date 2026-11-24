#!/bin/bash
set -euo pipefail

# Apply only the device-specific parts of the Bubble input mappings before
# running its Docker builders against this archived source tree.
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 BUBBLE_GIT NEW_SOURCE_DIRECTORY" >&2
    exit 2
fi
scripts=$(cd "$(dirname "$0")" && pwd)
source=$1
destination=$2
revision=ec81d42c0c2c39e7a32973bfe4df9b3027512a5d
mkdir "$destination"
git -C "$source" archive "$revision" | tar -xf - -C "$destination"
git -C "$source" show -s --format=%ct "$revision" > "$destination/source-date-epoch"
cp "$scripts/rg353m-retroarch-drm.patch" "$destination/patches/retroarch/021-rg353m-drm.patch"
cp "$scripts/rg353m-picoarch-audio.patch" "$destination/package/picoarch-bubble/patches/rg353m-audio.patch"
cp "$scripts/rg353m-picoarch-evdev.patch" "$destination/package/picoarch-bubble/patches/rg353m-evdev.patch"
cp "$scripts/rg353m-drastic-input.patch" "$destination/package/standalone-bubble/patches/drastic/rg353m-input.patch"
cp "$scripts/rg353m-openbor-input.patch" "$destination/package/standalone-bubble/patches/openbor/rg353m-input.patch"
cp "$scripts/quicknes-nes2-header.patch" "$destination/patches/libretro-cores-bubble/"
patch -s -d "$destination" -p1 < "$scripts/rg353m-standalone.patch"
patch -s -d "$destination" -p1 < "$scripts/rg353m-drastic-cleanup.patch"
python3 - "$destination" <<'PY'
from pathlib import Path
import sys

root = Path(sys.argv[1])

def replace(path, before, after, expected):
    file = root / path
    original = file.read_text()
    assert original.count(before) == expected, path
    file.write_text(original.replace(before, after))

replace("package/picoarch-bubble/patches/picoarch-bubble-physical-input.patch",
        "+\t{ BTN_TRIGGER_HAPPY1,", "+\t{ BTN_MODE,   ", 2)
replace("package/standalone-bubble/patches/pcsx-rearmed-bubble-kmsdrm.patch",
        "SDLK_WORLD_17", "SDLK_WORLD_10", 2)
standalone_launcher = "package/standalone-bubble/plumos/bin/plumos-standalone-launch"
replace(standalone_launcher, "guide:b17", "guide:b10", 4)
replace(standalone_launcher,
        'drm_share_preload="${PLUMOS_DRM_SHARE_LIBRARY:-}"',
        'drm_share_preload="${PLUMOS_DRM_SHARE_LIBRARY:-}"\n'
        '# Reuse the SDL built for the Mali KMSDRM and GLES stack.\n'
        'kms_sdl2="$PLUMOS_ROOT/apps/pyxel/lib/libSDL2-2.0.so.0"', 1)
replace(standalone_launcher,
        'LD_PRELOAD="/usr/lib/libSDL2-2.0.so.0:$PLUMOS_ROOT/emulator/lib/libmali.so.1:$drm_share_preload"',
        'LD_PRELOAD="$kms_sdl2:$PLUMOS_ROOT/emulator/lib/libmali.so.1:$drm_share_preload"', 1)
replace(standalone_launcher,
        'LD_PRELOAD="$drm_share_preload" \\\nSDL_VIDEODRIVER=kmsdrm',
        'LD_PRELOAD="$kms_sdl2:$mali_preload" \\\n'
        'SDL_VIDEO_EGL_DRIVER="$PLUMOS_ROOT/emulator/lib/libmali.so.1" \\\n'
        'SDL_VIDEO_GL_DRIVER="$PLUMOS_ROOT/emulator/lib/libmali.so.1" \\\n'
        'SDL_VIDEODRIVER=kmsdrm', 1)
replace(standalone_launcher,
        '        export ALSA_PLUGIN_DIR="$PLUMOS_ROOT/lib/alsa-lib-armhf"',
        '        export ALSA_CONFIG_PATH="$RUNTIME_ROOT/audio/asound-armhf.conf"\n'
        '        export ALSA_PLUGIN_DIR="$PLUMOS_ROOT/lib/alsa-lib-armhf"', 1)
replace("package/standalone-bubble/patches/yabasanshiro/yabasanshiro-2.10.4-bubble-input.patch",
        'mapInput("select", Input(joyId, TYPE_BUTTON, 17, 1, true))',
        'mapInput("select", Input(joyId, TYPE_BUTTON, 10, 1, true))', 1)
replace("package/standalone-bubble/plumos/factory-defaults/standalone/yabasanshiro/keymapv2.json",
        '"select": {"type": "button", "id": 17, "value": 1}',
        '"select": {"type": "button", "id": 10, "value": 1}', 1)
replace("configs/retroarch/autoconfig/udev/gkd-bubble-retrogame-joypad.cfg",
        'input_menu_toggle_btn = "17"', 'input_menu_toggle_btn = "10"', 1)
replace("configs/retroarch/autoconfig/udev/gkd-bubble-retrogame-joypad.cfg",
        'input_screenshot_btn = "10"\n', "", 1)
replace("scripts/build-picoarch-bubble.sh",
        'git -C "$SRC" apply "$PLUMOS_BUBBLE_PICOARCH_FRAME_PROBE_PATCH"',
        'git -C "$SRC" apply "$PLUMOS_BUBBLE_PICOARCH_FRAME_PROBE_PATCH"\n'
        'git -C "$SRC" apply /work/package/picoarch-bubble/patches/rg353m-audio.patch\n'
        'git -C "$SRC" apply /work/package/picoarch-bubble/patches/rg353m-evdev.patch', 1)
replace("scripts/build-picoarch-bubble.sh",
        'bubble-evdev-hotplug:$BUBBLE_EVDEV_HOTPLUG_PATCH_SHA256 ',
        'bubble-evdev-hotplug:$BUBBLE_EVDEV_HOTPLUG_PATCH_SHA256 '
        'rg353m-evdev:$(sha256sum "$ROOT_DIR/package/picoarch-bubble/patches/rg353m-evdev.patch" | cut -d " " -f 1) ', 1)
replace("scripts/build-pyxel-bubble.sh", "guide:b17", "guide:b10", 1)
replace("scripts/build-portmaster-bubble.sh",
        'ZIP_VERSION="3.0-13"', 'ZIP_VERSION="3.0-13+deb12u1"', 1)
replace("scripts/build-drastic-bubble.sh",
        'git -C "$SOURCE_DIR" apply --ignore-space-change --ignore-whitespace "$PATCH"',
        'git -C "$SOURCE_DIR" apply --ignore-space-change --ignore-whitespace "$PATCH"\n'
        '    git -C "$SOURCE_DIR" apply "$ROOT_DIR/package/standalone-bubble/patches/drastic/rg353m-input.patch"', 1)
replace("scripts/build-openbor-bubble.sh", 'git -C "$SOURCE_ROOT" apply "$PATCH_FILE"',
        'git -C "$SOURCE_ROOT" apply "$PATCH_FILE"\n'
        'git -C "$SOURCE_ROOT" apply "$ROOT_DIR/package/standalone-bubble/patches/openbor/rg353m-input.patch"', 1)
replace("scripts/build-libretro-cores-bubble.sh",
        '    build_dir="$work_dir"\n',
        '    if [ "$id" = "quicknes" ]; then\n'
        '        git -C "$work_dir" apply "$ROOT_DIR/patches/libretro-cores-bubble/quicknes-nes2-header.patch"\n'
        '    fi\n'
        '    build_dir="$work_dir"\n', 1)
replace("scripts/build-bubble-quicknes.sh",
        'git -C "$work" clean -fdx --quiet\n',
        'git -C "$work" clean -fdx --quiet\n'
        'patch_file="$repo_root/patches/libretro-cores-bubble/quicknes-nes2-header.patch"\n'
        'git -C "$work" apply "$patch_file"\n'
        'patch_sha256=$(sha256sum "$patch_file" | cut -d " " -f 1)\n', 1)
replace("scripts/build-bubble-quicknes.sh",
        '  "source_commit": "$ref",\n',
        '  "source_commit": "$ref",\n  "patch_sha256": "$patch_sha256",\n', 1)
replace("scripts/lib/bubble-libretro-package-metadata.sh",
        '        bluemsx) patch=bluemsx-cbios-safe-default.patch ;;',
        '        quicknes) patch=quicknes-nes2-header.patch ;;\n'
        '        bluemsx) patch=bluemsx-cbios-safe-default.patch ;;', 1)
standalone = "scripts/build-standalone-bubble.sh"
replace(standalone, '"input": "/dev/input/event2",',
        '"input": "sysfs retrogame_joypad",', 1)
replace(standalone, '"menu": "function1-evdev-704-direct; function2-evdev-316-plus-start-simple-menu",',
        '"menu": "BTN_MODE (evdev 316)",', 1)
replace(standalone, "artifacts/vendor/bubble-stock-source/runtime/gpu", "build/rg353m-jelos-gpu", 1)
replace(standalone, '"source": "Bubble stockOS read-only capture",',
        '"source": "JELOS 20240206 RG353M SYSTEM",', 1)
replace(standalone, '    "distribution": "public-with-gkd-vendor-notice",\n    "release_eligible": true,\n', "", 1)
PY
