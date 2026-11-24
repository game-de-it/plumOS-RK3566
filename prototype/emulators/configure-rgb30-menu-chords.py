"""Install the RGB30 menu bindings in the packaged emulator launchers."""

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
