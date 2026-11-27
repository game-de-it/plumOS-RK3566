"""Route RGB10 Max 3 SDL applications through the board-specific library."""

from pathlib import Path
import sys


root = Path(sys.argv[1])
select_library = '''# Keep the private SDL2 outside the normal library search path.
rgb10_sdl_dir=
case $("$BB" tr -d '\\000' </proc/device-tree/model 2>/dev/null || :) in
    "Powkiddy RGB10 Max 3"|"Powkiddy RGB10MAX3")
        candidate="$PLUMOS_ROOT/lib/rgb10max3"
        if [ -r "$candidate/libSDL2-2.0.so.0" ]; then
            rgb10_sdl_dir=$candidate
        fi
        ;;
esac
'''

standalone = root / "bin/plumos-standalone-launch"
source = standalone.read_text()
for emulator, anchor in (
    ("OpenBOR", 'if [ "$emulator_id" = openbor ]; then'),
    ("PCSX-ReARMed", 'runtime="$PLUMOS_ROOT/emulator/standalone/pcsx_rearmed"'),
):
    before, marker, after = source.partition(anchor)
    if not marker:
        raise SystemExit(f"Missing {emulator} launcher")
    old = 'LD_LIBRARY_PATH="$PLUMOS_ROOT/emulator/lib:$runtime/lib:/usr/lib"'
    if old not in after:
        raise SystemExit(f"Missing {emulator} library path")
    source = before + marker + after.replace(
        old, 'LD_LIBRARY_PATH="${rgb10_sdl_dir:+$rgb10_sdl_dir:}$PLUMOS_ROOT/emulator/lib:$runtime/lib:/usr/lib"', 1
    )
marker = 'if [ "$emulator_id" = openbor ]; then'
standalone.write_text(source.replace(marker, select_library + "\n" + marker, 1))

pyxel = root / "bin/plumos-pyxel-bubble-launch"
source = pyxel.read_text()
marker = 'if [ -r "$FIT_LIBRARY" ] && [ "${PLUMOS_PYXEL_FIT:-1}" != "0" ]; then'
if source.count(marker) != 1:
    raise SystemExit("Missing Pyxel GLES setup")
pyxel.write_text(source.replace(marker, select_library + '''
if [ -n "$rgb10_sdl_dir" ]; then
    # Python loads this after switching to its own glibc loader.
    export PLUMOS_BUBBLE_PYTHON_LD_PRELOAD="$rgb10_sdl_dir/libSDL2-2.0.so.0${PLUMOS_BUBBLE_PYTHON_LD_PRELOAD:+:$PLUMOS_BUBBLE_PYTHON_LD_PRELOAD}"
    export PLUMOS_PYXEL_FIT_USE_DRAWABLE=1
fi

''' + marker, 1))
