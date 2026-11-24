"""Configure RGB30 input and DraStic defaults in the packaged launchers."""

import hashlib
from pathlib import Path
import sys


root = Path(sys.argv[1])
bindings = {
    "plumos-retroarch-launch": (
        'set -- "$PLUMOS_ROOT/bin/retroarch" -v -c "$config"',
        "retroarch",
        '"$PLUMOS_ROOT/logs/retroarch-$system-$core_id.log"',
    ),
    "plumos-retroarch-menu-launch": (
        'set -- "$PLUMOS_ROOT/bin/retroarch" -v -c "$config"',
        "retroarch",
        '"$PLUMOS_ROOT/logs/retroarch-menu.log"',
    ),
    "plumos-picoarch-launch": (
        "set +e\nHOME=",
        "standalone",
        '"$LOG"',
    ),
    "plumos-standalone-launch": (
        'if [ "$emulator_id" = ppsspp ]; then',
        "standalone",
        '"$route_log"',
    ),
}

changed = {}
for launcher, (anchor, profile, log) in bindings.items():
    relative = f"bin/{launcher}"
    path = root / relative
    source = path.read_text()
    if source.count(anchor) != 1:
        raise SystemExit(f"Menu binding anchor changed in {path}")
    addition = f'/usr/lib/plumos-353m/rgb30-menu-chord "$$" {profile} >>{log} 2>&1 &\n'
    if launcher == "plumos-standalone-launch":
        addition = (
            'if [ "$emulator_id" = drastic ] &&\n'
            '   [ "$("$BB" tr -d \'\\000\' </proc/device-tree/model)" = "Powkiddy RGB30" ]; then\n'
            '    export PLUMOS_DRASTIC_RGB30_CHORD=1\n'
            'else\n'
            f'    {addition}'
            'fi\n'
        )
        config_anchor = '    drastic_config="$work/config/drastic.cfg"\n'
        if source.count(config_anchor) != 1:
            raise SystemExit(f"DraStic config anchor changed in {path}")
        source = source.replace(config_anchor, config_anchor + '''\
    if [ "${PLUMOS_DRASTIC_RGB30_CHORD:-0}" = 1 ] &&
       [ ! -e "$work/config/.rgb30-frameskip-v1" ]; then
        # A title could stay at one displayed frame out of five after the
        # menu closed. Migrate the old factory pair once, with a backup.
        if "$BB" grep -qx 'frameskip_type = 2' "$drastic_config" &&
           "$BB" grep -qx 'frameskip_value = 4' "$drastic_config"; then
            drastic_backup="$drastic_config.pre-rgb30-frameskip"
            [ -e "$drastic_backup" ] || "$BB" cp -p "$drastic_config" "$drastic_backup"
            "$BB" sed 's/^frameskip_type = 2$/frameskip_type = 0/' \\
                "$drastic_config" >"$drastic_config.next"
            "$BB" mv "$drastic_config.next" "$drastic_config"
        fi
        : >"$work/config/.rgb30-frameskip-v1"
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
