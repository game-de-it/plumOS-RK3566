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
patch -s -d "$destination" -p1 < "$scripts/../patches/rk3566-rgb10max3-panel.patch"
cp "$scripts/rg353m-retroarch-drm.patch" "$destination/patches/retroarch/021-rg353m-drm.patch"
cp "$scripts/retroarch-select-b-menu.patch" "$destination/patches/retroarch/022-plumos-select-b-menu.patch"
cp "$scripts/rk3566-retroarch-rgb10max3-panel.patch" "$destination/patches/retroarch/023-rk3566-rgb10max3-panel.patch"
patch -s -d "$destination" -p1 < "$scripts/rk2023-retroarch-renderer.patch"
cp "$scripts/rg353m-picoarch-audio.patch" "$destination/package/picoarch-bubble/patches/rg353m-audio.patch"
cp "$scripts/rg353m-picoarch-evdev.patch" "$destination/package/picoarch-bubble/patches/rg353m-evdev.patch"
cp "$scripts/rk3566-picoarch-display.patch" "$destination/package/picoarch-bubble/patches/rk3566-display.patch"
cp "$scripts/rg353m-drastic-input.patch" "$destination/package/standalone-bubble/patches/drastic/rg353m-input.patch"
cp "$scripts/rgb30-drastic-menu.patch" "$destination/package/standalone-bubble/patches/drastic/rgb30-menu.patch"
cp "$scripts/rk3566-drastic-display.patch" "$destination/package/standalone-bubble/patches/drastic/rk3566-display.patch"
cp "$scripts/rk3566-drastic-frame-pacing.patch" "$destination/package/standalone-bubble/patches/drastic/rk3566-frame-pacing.patch"
cp "$scripts/rk3566-drastic-menu-render.patch" "$destination/package/standalone-bubble/patches/drastic/rk3566-menu-render.patch"
cp "$scripts/rk3566-drastic-fps-overlay.patch" "$destination/package/standalone-bubble/patches/drastic/rk3566-fps-overlay.patch"
cp "$scripts/rk3566-drastic-render-queue.patch" "$destination/package/standalone-bubble/patches/drastic/rk3566-render-queue.patch"
cp "$scripts/rk3566-drastic-os-cpu-policy.patch" "$destination/package/standalone-bubble/patches/drastic/rk3566-os-cpu-policy.patch"
cp "$scripts/rk3566-drastic-rgb10max3-panel.patch" "$destination/package/standalone-bubble/patches/drastic/rk3566-rgb10max3-panel.patch"
cp "$scripts/rg353m-openbor-input.patch" "$destination/package/standalone-bubble/patches/openbor/rg353m-input.patch"
cp "$scripts/quicknes-rg353m.patch" "$destination/patches/libretro-cores-bubble/"
cp "$scripts/atari800-caverns-cartridge.patch" "$destination/patches/libretro-cores-bubble/"
patch -s -d "$destination" -p1 < "$scripts/rg353m-standalone.patch"
patch -s -d "$destination" -p1 < "$scripts/rg353m-drastic-cleanup.patch"
mkdir -p "$destination/display"
cp "$scripts/display/rk3566-kms-panel.h" "$destination/display/"
"$scripts/display/fetch-rga-headers.sh" "$destination/display/plumos-rga"
cp "$scripts/display/retroarch-rgb10max3-kms.patch" "$destination/patches/retroarch/024-rk3566-rgb10max3-kms.patch"
patch -s -d "$destination" -p1 < "$scripts/display/pyxel-rgb10max3-drawable.patch"
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
pcsx_patch = "package/standalone-bubble/patches/pcsx-rearmed-bubble-kmsdrm.patch"
replace(pcsx_patch, "SDLK_WORLD_17", "SDLK_WORLD_10", 2)
# retrogame_joypad reports B as SDL button 0 and A as button 1.
# Change the menu bindings independently of the emulated PSX buttons.
replace(pcsx_patch,
        '@@ -121,6 +139,13 @@ const struct menu_keymap in_sdl_joy_map[] =\n'
        '   { SDLK_WORLD_1, PBTN_MBACK },\n',
        '@@ -120,7 +138,14 @@ const struct menu_keymap in_sdl_joy_map[] =\n'
        '-  { SDLK_WORLD_0, PBTN_MOK },\n'
        '-  { SDLK_WORLD_1, PBTN_MBACK },\n'
        '+  { SDLK_WORLD_0, PBTN_MBACK },\n'
        '+  { SDLK_WORLD_1, PBTN_MOK },\n', 1)
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
# The SDL 1.2 shim loads the bundled SDL2 privately. Preloading SDL2 resolves
# PCSX's SDL_PeepEvents to the incompatible SDL2 ABI.
replace(standalone_launcher,
        'LD_PRELOAD="$drm_share_preload" \\\nSDL_VIDEODRIVER=kmsdrm',
        'LD_PRELOAD="$mali_preload" \\\n'
        'SDL_VIDEO_EGL_DRIVER="$PLUMOS_ROOT/emulator/lib/libmali.so.1" \\\n'
        'SDL_VIDEO_GL_DRIVER="$PLUMOS_ROOT/emulator/lib/libmali.so.1" \\\n'
        'SDL_VIDEODRIVER=kmsdrm', 1)
replace(standalone_launcher,
        '        export ALSA_PLUGIN_DIR="$PLUMOS_ROOT/lib/alsa-lib-armhf"',
        '        export ALSA_CONFIG_PATH="$RUNTIME_ROOT/audio/asound-armhf.conf"\n'
        '        # DraStic writes audio synchronously from the emulation thread.\n'
        '        export PLUMOS_AUDIO_SHORT_PERIOD=1\n'
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
        'git -C "$SRC" apply /work/package/picoarch-bubble/patches/rg353m-evdev.patch\n'
        'git -C "$SRC" apply /work/package/picoarch-bubble/patches/rk3566-display.patch', 1)
replace("scripts/build-picoarch-bubble.sh",
        'bubble-evdev-hotplug:$BUBBLE_EVDEV_HOTPLUG_PATCH_SHA256 ',
        'bubble-evdev-hotplug:$BUBBLE_EVDEV_HOTPLUG_PATCH_SHA256 '
        'rg353m-evdev:$(sha256sum "$ROOT_DIR/package/picoarch-bubble/patches/rg353m-evdev.patch" | cut -d " " -f 1) '
        'rk3566-display:$(sha256sum "$ROOT_DIR/package/picoarch-bubble/patches/rk3566-display.patch" | cut -d " " -f 1) ', 1)
replace("scripts/build-pyxel-bubble.sh", "guide:b17", "guide:b10", 1)
retroarch = "scripts/build-bubble-retroarch.sh"
clean = 'git -C "$work" clean -fdx --quiet\n'
replace(retroarch, clean,
        clean + 'cp "$repo_root/display/rk3566-kms-panel.h" "$work/gfx/drivers_context/"\n'
        'cp -R "$repo_root/display/plumos-rga" "$work/gfx/drivers_context/"\n', 1)

replace("scripts/build-portmaster-bubble.sh",
        'ZIP_VERSION="3.0-13"', 'ZIP_VERSION="3.0-13+deb12u1"', 1)
replace("scripts/build-drastic-bubble.sh",
        'git -C "$SOURCE_DIR" apply --ignore-space-change --ignore-whitespace "$PATCH"',
        'git -C "$SOURCE_DIR" apply --ignore-space-change --ignore-whitespace "$PATCH"\n'
        '    git -C "$SOURCE_DIR" apply "$ROOT_DIR/package/standalone-bubble/patches/drastic/rg353m-input.patch"\n'
        '    git -C "$SOURCE_DIR" apply "$ROOT_DIR/package/standalone-bubble/patches/drastic/rgb30-menu.patch"\n'
        '    git -C "$SOURCE_DIR" apply "$ROOT_DIR/package/standalone-bubble/patches/drastic/rk3566-display.patch"\n'
        '    git -C "$SOURCE_DIR" apply "$ROOT_DIR/package/standalone-bubble/patches/drastic/rk3566-frame-pacing.patch"\n'
        '    git -C "$SOURCE_DIR" apply "$ROOT_DIR/package/standalone-bubble/patches/drastic/rk3566-menu-render.patch"\n'
        '    git -C "$SOURCE_DIR" apply "$ROOT_DIR/package/standalone-bubble/patches/drastic/rk3566-fps-overlay.patch"\n'
        '    git -C "$SOURCE_DIR" apply "$ROOT_DIR/package/standalone-bubble/patches/drastic/rk3566-render-queue.patch"\n'
        '    git -C "$SOURCE_DIR" apply "$ROOT_DIR/package/standalone-bubble/patches/drastic/rk3566-os-cpu-policy.patch"\n'
        '    git -C "$SOURCE_DIR" apply "$ROOT_DIR/package/standalone-bubble/patches/drastic/rk3566-rgb10max3-panel.patch"', 1)
replace("scripts/build-drastic-bubble.sh",
        '    SDL2_SHA256="$(sha256sum "$SOURCE_LIB_ROOT/libSDL2-2.0.so.0" | awk \'{ print $1 }\')"',
        '    SDL2_SHA256="$(sha256sum "$SOURCE_LIB_ROOT/libSDL2-2.0.so.0" | awk \'{ print $1 }\')"\n'
        '    RUNNER_SHA256="$(sha256sum "$SOURCE_DIR/drastic/runner" | awk \'{ print $1 }\')"', 1)
replace("scripts/build-drastic-bubble.sh",
        "    's/^controls_b\\[CONTROL_INDEX_MENU\\] = 1154$/controls_b[CONTROL_INDEX_MENU] = 1041/' \\\n",
        "    -e 's/^controls_b\\[CONTROL_INDEX_MENU\\] = 1154$/controls_b[CONTROL_INDEX_MENU] = 1041/' \\\n"
        "    -e 's/^frameskip_type = 2$/frameskip_type = 0/' \\\n", 1)
replace("scripts/build-drastic-bubble.sh",
        'install -m 0644 "$SOURCE_LIB_ROOT/libcommon.so" "$OUT_ROOT/lib/libcommon.so"',
        'grep -Fqx \'frameskip_type = 0\' "$OUT_ROOT/config/drastic.cfg" || {\n'
        '    printf \'error: DraStic frame skip factory setting was not applied\\n\' >&2\n'
        '    exit 1\n'
        '}\n'
        'install -m 0644 "$SOURCE_LIB_ROOT/libcommon.so" "$OUT_ROOT/lib/libcommon.so"', 1)
replace("scripts/build-openbor-bubble.sh", 'git -C "$SOURCE_ROOT" apply "$PATCH_FILE"',
        'git -C "$SOURCE_ROOT" apply "$PATCH_FILE"\n'
        'git -C "$SOURCE_ROOT" apply "$ROOT_DIR/package/standalone-bubble/patches/openbor/rg353m-input.patch"', 1)
openbor_patch = "package/standalone-bubble/patches/openbor/openbor-v6391-bubble.patch"
replace(openbor_patch, '@@ -159,6 +159,11 @@', '@@ -159,6 +159,13 @@', 1)
replace(openbor_patch, '+\tsavedata.stretch = 1;\n',
        '+\tSDL_DisplayMode mode;\n'
        '+\tsavedata.stretch = SDL_GetCurrentDisplayMode(0, &mode) != 0 ||\n'
        '+\t                  mode.w != mode.h;\n', 1)
replace("scripts/build-libretro-cores-bubble.sh",
        '    build_dir="$work_dir"\n',
        '    case "$id" in\n'
        '        quicknes) core_patch=quicknes-rg353m.patch ;;\n'
        '        atari800) core_patch=atari800-caverns-cartridge.patch ;;\n'
        '        *) core_patch= ;;\n'
        '    esac\n'
        '    if [ -n "$core_patch" ]; then\n'
        '        git -C "$work_dir" apply "$ROOT_DIR/patches/libretro-cores-bubble/$core_patch"\n'
        '    fi\n'
        '    build_dir="$work_dir"\n', 1)
replace("scripts/build-bubble-quicknes.sh",
        'git -C "$work" clean -fdx --quiet\n',
        'git -C "$work" clean -fdx --quiet\n'
        'patch_file="$repo_root/patches/libretro-cores-bubble/quicknes-rg353m.patch"\n'
        'git -C "$work" apply "$patch_file"\n'
        'patch_sha256=$(sha256sum "$patch_file" | cut -d " " -f 1)\n', 1)
replace("scripts/build-bubble-quicknes.sh",
        '  "source_commit": "$ref",\n',
        '  "source_commit": "$ref",\n  "patch_sha256": "$patch_sha256",\n', 1)
replace("scripts/lib/bubble-libretro-package-metadata.sh",
        '        bluemsx) printf \'%s\\n\' bluemsx-cbios-safe-default-v3 ;;',
        '        atari800) printf \'%s\\n\' atari800-cart-crc-v1 ;;\n'
        '        bluemsx) printf \'%s\\n\' bluemsx-cbios-safe-default-v3 ;;', 1)
replace("scripts/lib/bubble-libretro-package-metadata.sh",
        '        bluemsx) patch=bluemsx-cbios-safe-default.patch ;;',
        '        quicknes) patch=quicknes-rg353m.patch ;;\n'
        '        atari800) patch=atari800-caverns-cartridge.patch ;;\n'
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
patch -s -d "$destination" -p1 < "$scripts/rk3566-ppsspp-malisx2.patch"
cp "$scripts/rk3566-ppsspp-vulkan-only.patch" "$destination/package/standalone-bubble/patches/ppsspp/"
cp "$scripts/rk3566-ppsspp-rgb10max3-panel.patch" "$destination/package/standalone-bubble/patches/ppsspp/"
cp "$scripts/stage-ppsspp-malisx2.sh" "$destination/scripts/"
