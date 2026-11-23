#!/bin/bash
set -euo pipefail

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 PREPARED_BUBBLE_SOURCE NEW_RUNTIME_DIRECTORY" >&2
    exit 2
fi
scripts=$(cd "$(dirname "$0")" && pwd)
bubble=$(cd "$1" && pwd)
runtime=$2
components=(
    retroarch/bubble libretro-cores/bubble-all picoarch/bubble standalone/bubble
    pyxel/bubble portmaster/bubble freej2me-plus/bubble
)
for component in "${components[@]}"; do
    test -d "$bubble/output/$component/plumos"
done
mkdir "$runtime"
for component in "${components[@]}"; do
    cp -R "$bubble/output/$component/plumos/." "$runtime/"
done
# PCSX's SDL 1.2 shim loads the JELOS KMSDRM SDL2 used to validate this panel.
pcsx_sdl2="$runtime/emulator/standalone/pcsx_rearmed/lib/libSDL2-2.0.so.0"
test -f "$pcsx_sdl2"
rm "$pcsx_sdl2"
ln -s /usr/lib/libSDL2-2.0.so.0 "$pcsx_sdl2"
frontend=$bubble/package/frontend-bubble/plumos/bin
install -m 755 "$frontend"/{plumos-retroarch-launch,plumos-retroarch-menu-launch,plumos-retroarch-config-merge,plumos-volume-control,plumos-cpu-control} "$runtime/bin/"
python3 "$scripts/set-volume-curve.py" "$runtime/bin/plumos-volume-control"
install -m 755 "$frontend/plumos-audio-output" "$runtime/bin/"
install -m 755 "$scripts/plumos-rk3566-audio-route" "$runtime/bin/"
ln -s /usr/bin/aplay "$runtime/bin/plumos-aplay"
python3 - "$runtime" <<'PY'
import hashlib
import json
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
# Bubble uses a video thread to keep DRM page-flip waits off the
# emulation/audio producer. Preserve that setting on RK3566 as well.
needle = '    *:flycast:*|*:flycast_xtreme:*|*:km_duckswanstation_xtreme_amped:*|'
assert s.count(needle) == 1
gl_routes = [
    "gpsp",
    "mednafen_pce",
    "fbneo",
    "mednafen_vb",
    "mame2000",
    "mame2003_plus",
    "scummvm",
    "potator",
    "puae",
    "km_puae_xtreme_amped",
]
gl_patterns = "".join(f"    *:{core}:*|\\\n" for core in gl_routes)
s = s.replace(needle, gl_patterns + needle)
needle = '''case "$core_id" in
    bluemsx)'''
assert s.count(needle) == 1
s = s.replace(needle, '''case "$core_id" in
    freej2me_plus)
        system_directory="$HOME/freej2me-plus"
        "$BB" mkdir -p "$system_directory/freej2me_system"
        "$BB" ln -sfnT "$PLUMOS_ROOT/share/libretro-system/freej2me-plus/freej2me_plus_runtime" \\
            "$system_directory/freej2me_plus_runtime"
        # Java Sound uses the managed ALSA device directly.
        printf '%s\\n' 'audio_enable = "false"' >>"$append_config"
        ;;
    bluemsx)''')
launcher.write_text(s)

for name in ("plumos-portmaster-launch", "plumos-portmaster-port-launch"):
    port_launcher = root / "bin" / name
    s = port_launcher.read_text()
    s = s.replace(
        '*plumos-controller-ui-bubble*|*plumos-controller-ui-fbdev*)',
        '*plumos-controller-ui-bubble*|*plumos-controller-ui-fbdev*|*plumos-controller-ui\\ --renderer*)',
    )
    s = s.replace('</run/plumos/audio/output.status',
                  '<"${PLUMOS_RUNTIME_ROOT:-/run/plumos}/audio/output.status"')
    s = s.replace('ALSA_CONFIG_PATH="/run/plumos/audio/asound.conf"',
                  'ALSA_CONFIG_PATH="${PLUMOS_RUNTIME_ROOT:-/run/plumos}/audio/asound.conf"')
    s = s.replace('export PLUMOS_ROOT PLUMOS_RUNTIME_ROOT="/run/plumos"',
                  'export PLUMOS_ROOT PLUMOS_RUNTIME_ROOT="${PLUMOS_RUNTIME_ROOT:-/run/plumos}"')
    # Native executables use JELOS's loader. Only the Python launcher may
    # load the private Pyxel/Python libc.
    libraries = "${PLUMOS_ROOT}/apps/pyxel/lib:${PLUMOS_ROOT}/apps/python/lib:"
    assert s.count(libraries) == 1
    s = s.replace(libraries, "").replace("${PLUMOS_ROOT}/apps/nextcommander/lib:", "")
    if name == "plumos-portmaster-port-launch":
        needle = 'LOG_FILE="${PLUMOS_ROOT}/logs/apps/portmaster-ports.log"'
        assert s.count(needle) == 1
        s = s.replace(needle, needle + '\nmkdir -p "${LOG_FILE%/*}"')
    port_launcher.write_text(s)

port_runtime = root / "bin/plumos-portmaster-runtime"
s = port_runtime.read_text()
needle = '  link_one libSDL2_mixer-2.0.so.0'
assert s.count(needle) == 1
port_runtime.write_text(s.replace(needle, '''  # Add only the image codecs, keeping NextCommander's libc private.
  for codec in libpng16.so.16 libjpeg.so.62 libtiff.so.6 libwebp.so.7 \
    libLerc.so.4 libjbig.so.0 libdeflate.so.0; do
    link_one "$codec" "${NEXTCOMMANDER_LIB}/$codec"
  done
''' + needle))

pyxel = root / "bin/plumos-pyxel-setup"
s = pyxel.read_text()
needle = '  install) install_site ;;'
assert s.count(needle) == 1
pyxel.write_text(s.replace(needle, '''  install)
    if [ "$REQUIREMENTS_SOURCE" = project ]; then
      install_site
    else
      print_status
    fi
    ;;'''))

# The RK3566 init keeps the managed ALSA config under /run/plumos-353m.
# Pyxel must select it even when the frontend did not export ALSA_CONFIG_PATH.
pyxel_launcher = root / "bin/plumos-pyxel-bubble-launch"
s = pyxel_launcher.read_text()
needle = 'ALSA_CONFIG_PATH="${ALSA_CONFIG_PATH:-/run/plumos/audio/asound.conf}"'
assert s.count(needle) == 1
pyxel_launcher.write_text(s.replace(
    needle,
    'ALSA_CONFIG_PATH="${ALSA_CONFIG_PATH:-${PLUMOS_RUNTIME_ROOT:-/run/plumos}/audio/asound.conf}"',
))
control = root / "bin/plumos-portmaster-frontend-control"
s = control.read_text()
needle = '    case "$cmdline" in\n'
assert s.count(needle) == 1
control.write_text(s.replace(needle, needle +
    '      "${PLUMOS_ROOT}/bin/plumos-controller-ui "*) printf \'%s\\n\' "$pid" ;;\n'))

libretro_manifest = root / "components/libretro-cores/manifest.json"
catalog = json.loads(libretro_manifest.read_text())
freej2me = json.loads((root / "components/freej2me-plus/manifest.json").read_text())
catalog["cores"].append(freej2me)
libretro_manifest.write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + "\n")

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
