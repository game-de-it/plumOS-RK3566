#!/usr/bin/env python3
"""Set the RG353M volume curve in a Bubble volume-control launcher."""

from pathlib import Path
import re
import sys


if len(sys.argv) != 2:
    raise SystemExit("usage: set-volume-curve.py plumos-volume-control")

path = Path(sys.argv[1])
source = path.read_text()
curve = """# Level 0 remains the softvol minimum. Level 1 is deliberately quiet:
# the former raw 181 made the first press much louder than expected. Softvol
# is linear in dB, so increasing raw steps keep low levels fine and make the
# upper levels change more. The 0..20 persisted setting remains unchanged.
volume_to_raw() {
    case $(normalize "$1") in
        0) printf '0\\n' ;;
        1) printf '136\\n' ;;
        2) printf '138\\n' ;;
        3) printf '140\\n' ;;
        4) printf '143\\n' ;;
        5) printf '146\\n' ;;
        6) printf '150\\n' ;;
        7) printf '154\\n' ;;
        8) printf '159\\n' ;;
        9) printf '164\\n' ;;
        10) printf '170\\n' ;;
        11) printf '176\\n' ;;
        12) printf '183\\n' ;;
        13) printf '190\\n' ;;
        14) printf '198\\n' ;;
        15) printf '206\\n' ;;
        16) printf '215\\n' ;;
        17) printf '224\\n' ;;
        18) printf '234\\n' ;;
        19) printf '244\\n' ;;
        20) printf '255\\n' ;;
    esac
}
"""

pattern = re.compile(
    r"(?ms)^# (?:Pixel2 applies|Keep levels 1 and 20).*?^volume_to_raw\(\) \{.*?^\}\n"
)
updated, count = pattern.subn(lambda _: curve, source)
if count != 1:
    raise SystemExit(f"expected one Bubble volume curve in {path}, found {count}")
old_markers = ("curve=pixel2-linear-amplitude-v1", "curve=rg353m-progressive-db-v1")
if sum(updated.count(marker) for marker in old_markers) != 1:
    raise SystemExit(f"expected one known curve log marker in {path}")
for marker in old_markers:
    updated = updated.replace(marker, "curve=rg353m-progressive-db-v2")
path.write_text(updated)
