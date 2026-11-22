#!/bin/bash
set -euo pipefail

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 PREPARED_BUBBLE_SOURCE NEW_RUNTIME_DIRECTORY" >&2
    exit 2
fi
scripts=$(cd "$(dirname "$0")" && pwd)
bubble=$(cd "$1" && pwd)
runtime=$2
for component in retroarch/bubble libretro-cores/bubble-all picoarch/bubble standalone/bubble; do
    test -d "$bubble/output/$component/plumos"
done
mkdir "$runtime"
for component in retroarch/bubble libretro-cores/bubble-all picoarch/bubble standalone/bubble; do
    cp -R "$bubble/output/$component/plumos/." "$runtime/"
done
# PCSX's SDL 1.2 shim loads the JELOS KMSDRM SDL2 used to validate this panel.
pcsx_sdl2="$runtime/emulator/standalone/pcsx_rearmed/lib/libSDL2-2.0.so.0"
test -f "$pcsx_sdl2"
rm "$pcsx_sdl2"
ln -s /usr/lib/libSDL2-2.0.so.0 "$pcsx_sdl2"
frontend=$bubble/package/frontend-bubble/plumos/bin
install -m 755 "$frontend"/{plumos-retroarch-launch,plumos-retroarch-config-merge,plumos-volume-control,plumos-cpu-control} "$runtime/bin/"
install -m 755 "$frontend/plumos-audio-output" "$runtime/bin/"
install -m 755 "$scripts/plumos-rk3566-audio-route" "$runtime/bin/"
ln -s /usr/bin/aplay "$runtime/bin/plumos-aplay"
python3 - "$runtime" <<'PY'
import hashlib
from pathlib import Path
import sys

root = Path(sys.argv[1])
for cfg in (root / "factory-defaults/retroarch").glob("*.cfg"):
    text = cfg.read_text().replace("/storage/plumos/", "/storage/plumos-rk3566/frontend/")
    text = text.replace('input_menu_toggle_btn = "17"', 'input_menu_toggle_btn = "10"')
    text = text.replace('input_screenshot_btn = "10"', 'input_screenshot_btn = "nul"')
    cfg.write_text(text)
autoconfig = root / "factory-defaults/retroarch/autoconfig/udev/gkd-bubble-retrogame-joypad.cfg"
autoconfig.write_text(autoconfig.read_text().replace('input_menu_toggle_btn = "17"', 'input_menu_toggle_btn = "10"')
                      .replace('input_screenshot_btn = "10"\n', ''))
audio = root / "bin/plumos-audio-output"
s = audio.read_text()
needle = "prepare() {\n"
assert s.count(needle) == 1
audio.write_text(s.replace(needle, needle + '    "$PLUMOS_ROOT/bin/plumos-rk3566-audio-route" apply\n'))
launcher = root / "bin/plumos-retroarch-launch"
s = launcher.read_text()
needle = """            printf '%s\\n' 'video_context_driver = ""'
            printf '%s\\n' 'video_threaded = "true"'"""
assert s.count(needle) == 1
launcher.write_text(s.replace(needle, needle.replace('video_threaded = "true"', 'video_threaded = "false"')))

for manifest in (root / "components").glob("*/checksums.sha256"):
    lines = []
    for entry in manifest.read_text().splitlines():
        _, relative = entry.split("  ", 1)
        if root / relative == root / "emulator/standalone/pcsx_rearmed/lib/libSDL2-2.0.so.0":
            continue
        digest = hashlib.sha256()
        with (root / relative).open("rb") as contents:
            for block in iter(lambda: contents.read(1024 * 1024), b""):
                digest.update(block)
        lines.append(f"{digest.hexdigest()}  {relative}\n")
    manifest.write_text("".join(lines))
PY
