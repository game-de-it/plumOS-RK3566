"""Install the startup recorder in the RK3566 RetroArch launch path."""

import hashlib
from pathlib import Path
import shutil
import sys


root = Path(sys.argv[1])
source_dir = Path(__file__).resolve().parent / "diagnostics"
destination = root / "share" / "diagnostics"
destination.mkdir(parents=True, exist_ok=True)
shutil.copyfile(source_dir / "mrboom-startup.py", destination / "mrboom-startup.py")

relative = "bin/plumos-retroarch-launch"
launcher = root / relative
source = launcher.read_text()
anchor = 'retroarch_pid=$!\nwait "$retroarch_pid"\n'
if source.count(anchor) != 1:
    raise SystemExit(f"RetroArch wait block changed in {launcher}")
launcher.write_text(source.replace(anchor, '''retroarch_pid=$!
if [ "$core_id" = mrboom ]; then
    PLUMOS_ROOT="$PLUMOS_ROOT" PLUMOS_RUNTIME_ROOT="$RUNTIME_ROOT" \\
        "$PLUMOS_ROOT/bin/plumos-python-bubble" \\
        "$PLUMOS_ROOT/share/diagnostics/mrboom-startup.py" "$retroarch_pid" \\
        >>"$PLUMOS_ROOT/logs/retroarch-${system}-${core_id}.log" 2>&1 &
fi
wait "$retroarch_pid"
''', 1))

digest = hashlib.sha256(launcher.read_bytes()).hexdigest()
for checksum in (root / "components").glob("*/checksums.sha256"):
    source = checksum.read_text()
    lines = source.splitlines(keepends=True)
    updated = "".join(f"{digest}  {relative}\n" if line.rstrip("\n").endswith(f"  {relative}") else line
                      for line in lines)
    if updated != source:
        checksum.write_text(updated)
