#!/usr/bin/env python3
"""Set the RG353M volume curve in a Bubble volume-control launcher."""

from pathlib import Path
import re
import sys


if len(sys.argv) != 2:
    raise SystemExit("usage: set-volume-curve.py plumos-volume-control")

path = Path(sys.argv[1])
source = path.read_text()
curve = """# Keep levels 1 and 20 at the existing end points. ALSA softvol's
# 0..255 control is linear in dB, so an increasing raw step gives a finer
# audible change near the bottom and a larger one near the top. The button
# range, persisted setting and level 0 remain unchanged.
volume_to_raw() {
    case $(normalize "$1") in
        0) printf '0\\n' ;;
        1) printf '181\\n' ;;
        2) printf '182\\n' ;;
        3) printf '183\\n' ;;
        4) printf '185\\n' ;;
        5) printf '187\\n' ;;
        6) printf '189\\n' ;;
        7) printf '191\\n' ;;
        8) printf '194\\n' ;;
        9) printf '197\\n' ;;
        10) printf '200\\n' ;;
        11) printf '204\\n' ;;
        12) printf '208\\n' ;;
        13) printf '212\\n' ;;
        14) printf '217\\n' ;;
        15) printf '222\\n' ;;
        16) printf '227\\n' ;;
        17) printf '233\\n' ;;
        18) printf '240\\n' ;;
        19) printf '247\\n' ;;
        20) printf '255\\n' ;;
    esac
}
"""

pattern = re.compile(r"(?ms)^# Pixel2 applies.*?^volume_to_raw\(\) \{.*?^\}\n")
updated, count = pattern.subn(lambda _: curve, source)
if count != 1:
    raise SystemExit(f"expected one Bubble volume curve in {path}, found {count}")
old_marker = "curve=pixel2-linear-amplitude-v1"
if updated.count(old_marker) != 1:
    raise SystemExit(f"expected one Bubble curve log marker in {path}")
updated = updated.replace(old_marker, "curve=rg353m-progressive-db-v1")
path.write_text(updated)
