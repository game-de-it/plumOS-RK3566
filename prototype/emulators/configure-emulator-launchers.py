"""Configure the Bubble launchers for the RK3566 runtime."""

from pathlib import Path
import sys


runtime = Path(sys.argv[1])
for name, cpu_control, message in (
    ("plumos-retroarch-launch", "cpu_control", "RetroArch: CPU policy unavailable; keeping current clock"),
    ("plumos-picoarch-launch", "CPU_CONTROL", "PicoArch: CPU policy unavailable; keeping current clock"),
    ("plumos-pyxel-bubble-launch", "CPU_CONTROL", "Pyxel: CPU policy unavailable; keeping current clock"),
):
    path = runtime / "bin" / name
    source = path.read_text()
    old = f'if [ -x "${cpu_control}" ] &&'
    if source.count(old) != 1:
        raise SystemExit(f"CPU policy block changed in {path}")
    new = (
        'if [ ! -d "${PLUMOS_CPUFREQ_ROOT:-/sys/devices/system/cpu/cpufreq}/policy0" ]; then\n'
        f"    printf '%s\\n' '{message}' >&2\n"
        f'elif [ -x "${cpu_control}" ] &&'
    )
    path.write_text(source.replace(old, new, 1))

pyxel = runtime / "bin/plumos-pyxel-bubble-launch"
source = pyxel.read_text()
old = '''  export PLUMOS_PYXEL_FIT_WIDTH="${PLUMOS_PYXEL_FIT_WIDTH:-640}"
  export PLUMOS_PYXEL_FIT_HEIGHT="${PLUMOS_PYXEL_FIT_HEIGHT:-480}"
'''
new = r'''  # The fbdev mode is the visible scanout size, including on square panels.
  mode=$("$BB" sed -n 's/^[A-Z]:\([1-9][0-9]*x[1-9][0-9]*\)[ip]-[0-9][0-9]*$/\1/p' \
    /sys/class/graphics/fb0/modes 2>/dev/null | "$BB" head -n 1)
  mode=${mode:-640x480}
  export PLUMOS_PYXEL_FIT_WIDTH="${PLUMOS_PYXEL_FIT_WIDTH:-${mode%x*}}"
  export PLUMOS_PYXEL_FIT_HEIGHT="${PLUMOS_PYXEL_FIT_HEIGHT:-${mode#*x}}"
'''
if source.count(old) != 1:
    raise SystemExit(f"Pyxel display sizing changed in {pyxel}")
pyxel.write_text(source.replace(old, new, 1))

retroarch = runtime / "bin/plumos-retroarch-launch"
source = retroarch.read_text()
old = '        # Java Sound uses the managed ALSA device directly.\n'
new = r'''        # Use the bundled font on images without a system Fontconfig database.
        font_config="$system_directory/fontconfig.properties"
        printf '%s\n' 'version=1' 'sequence.allfonts=alphabetic' \
            'allfonts.alphabetic=DejaVu Sans' \
            "filename.DejaVu_Sans=$PLUMOS_ROOT/retroarch/assets/fonts/DejaVuSans.ttf" \
            >"$font_config"
        export JAVA_TOOL_OPTIONS="${JAVA_TOOL_OPTIONS:+$JAVA_TOOL_OPTIONS }-Dsun.awt.fontconfig=$font_config"
''' + old
if source.count(old) != 1:
    raise SystemExit(f"FreeJ2ME launch block changed in {retroarch}")
retroarch.write_text(source.replace(old, new, 1))
