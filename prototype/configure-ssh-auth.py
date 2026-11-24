"""Enable the same password and public-key authentication as Bubble."""

import hashlib
from pathlib import Path
import sys


root = Path(sys.argv[1])
relative = "bin/plumos-network-services"
service = root / relative
source = service.read_text()
line = '    /usr/bin/dropbear -E -P "$SSH_PID" -r "$HOST_KEY" -p 22 -s -K 30 -I 300'
if source.count(line) != 1:
    raise SystemExit(f"SSH listener command changed in {service}")
service.write_text(source.replace(line, line.replace(" -s ", " "), 1))

digest = hashlib.sha256(service.read_bytes()).hexdigest()
for manifest in (root / "components").glob("*/checksums.sha256"):
    source = manifest.read_text()
    lines = source.splitlines(keepends=True)
    updated = "".join(
        f"{digest}  {relative}\n" if line.rstrip("\n").endswith(f"  {relative}") else line
        for line in lines
    )
    if updated != source:
        manifest.write_text(updated)
