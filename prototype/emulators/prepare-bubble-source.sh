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
cp "$scripts/rg353m-drastic-input.patch" "$destination/package/standalone-bubble/patches/drastic/rg353m-input.patch"
cp "$scripts/rg353m-openbor-input.patch" "$destination/package/standalone-bubble/patches/openbor/rg353m-input.patch"
patch -s -d "$destination" -p1 < "$scripts/rg353m-standalone.patch"
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
replace("package/standalone-bubble/plumos/bin/plumos-standalone-launch",
        "guide:b17", "guide:b10", 4)
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
        'git -C "$SRC" apply /work/package/picoarch-bubble/patches/rg353m-audio.patch', 1)
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
