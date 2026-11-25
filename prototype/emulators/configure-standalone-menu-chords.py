"""Configure menu chords on handhelds without an FN button."""

import hashlib
from pathlib import Path
import sys


root = Path(sys.argv[1])
bindings = {
    "plumos-picoarch-launch": (
        "set +e\nHOME=",
        '"$LOG"',
    ),
    "plumos-standalone-launch": (
        'if [ "$emulator_id" = ppsspp ]; then',
        '"$route_log"',
    ),
}

changed = {}
for launcher, (anchor, log) in bindings.items():
    relative = f"bin/{launcher}"
    path = root / relative
    source = path.read_text()
    if source.count(anchor) != 1:
        raise SystemExit(f"Menu binding anchor changed in {path}")
    addition = f'/usr/lib/plumos-353m/standalone-menu-chord "$$" >>{log} 2>&1 &\n'
    if launcher == "plumos-standalone-launch":
        addition = (
            'if [ "$emulator_id" = drastic ]; then\n'
            '    case "$("$BB" tr -d \'\\000\' 2>/dev/null </proc/device-tree/model || :)" in\n'
            '        "Powkiddy RGB30"|"Powkiddy RK2023") export PLUMOS_DRASTIC_RGB30_CHORD=1 ;;\n'
            '    esac\n'
            'else\n'
            f'    {addition}'
            'fi\n'
        )
        config_anchor = '    drastic_config="$work/config/drastic.cfg"\n'
        if source.count(config_anchor) != 1:
            raise SystemExit(f"DraStic config anchor changed in {path}")
        source = source.replace(config_anchor, config_anchor + '''\
    if [ ! -e "$work/config/.rk3566-frameskip-v1" ]; then
        # Migrate a pristine copy of the old factory configuration. Existing
        # RGB30 migrations and custom global or per-game settings take priority.
        if [ ! -e "$work/config/.rgb30-frameskip-v1" ] &&
           "$BB" sed 's/^frameskip_type = 0$/frameskip_type = 2/' \\
               "$runtime/config/drastic.cfg" | "$BB" cmp -s - "$drastic_config"; then
            "$BB" cp -p "$runtime/config/drastic.cfg" "$drastic_config.next"
            "$BB" mv "$drastic_config.next" "$drastic_config"
        fi
        : >"$work/config/.rk3566-frameskip-v1"
    fi
''', 1)
    path.write_text(source.replace(anchor, addition + anchor, 1))
    changed[relative] = hashlib.sha256(path.read_bytes()).hexdigest()

for checksum in (root / "components").glob("*/checksums.sha256"):
    source = checksum.read_text()
    lines = []
    for line in source.splitlines(keepends=True):
        digest, separator, relative = line.rstrip("\n").partition("  ")
        if separator and relative in changed:
            line = f"{changed[relative]}  {relative}\n"
        lines.append(line)
    updated = "".join(lines)
    if updated != source:
        checksum.write_text(updated)
