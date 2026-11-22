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
replace("configs/retroarch/autoconfig/udev/gkd-bubble-retrogame-joypad.cfg",
        'input_menu_toggle_btn = "17"', 'input_menu_toggle_btn = "10"', 1)
replace("configs/retroarch/autoconfig/udev/gkd-bubble-retrogame-joypad.cfg",
        'input_screenshot_btn = "10"\n', "", 1)
replace("scripts/build-picoarch-bubble.sh",
        'git -C "$SRC" apply "$PLUMOS_BUBBLE_PICOARCH_FRAME_PROBE_PATCH"',
        'git -C "$SRC" apply "$PLUMOS_BUBBLE_PICOARCH_FRAME_PROBE_PATCH"\n'
        'git -C "$SRC" apply /work/package/picoarch-bubble/patches/rg353m-audio.patch', 1)
replace("scripts/build-pyxel-bubble.sh", "fetch_sdl\nbuild_sdl\n",
        'fetch_sdl\nbuild_sdl\nif [ "${2:-}" = --sdl-only ]; then exit 0; fi\n', 1)
standalone = "scripts/build-standalone-bubble.sh"
replace(standalone, "artifacts/vendor/bubble-stock-source/runtime/gpu", "build/rg353m-jelos-gpu", 1)
replace(standalone, '"source": "Bubble stockOS read-only capture",',
        '"source": "JELOS 20240206 RG353M SYSTEM",', 1)
replace(standalone, '    "distribution": "public-with-gkd-vendor-notice",\n    "release_eligible": true,\n', "", 1)
PY
