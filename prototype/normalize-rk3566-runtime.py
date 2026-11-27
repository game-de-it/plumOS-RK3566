#!/usr/bin/env python3
"""Apply RK3566-owned names to the staged runtime from the pinned upstream."""

import hashlib
import json
from pathlib import Path
import subprocess
import sys

payload = Path(sys.argv[1])
root = payload / "frontend"
prototype = Path(__file__).resolve().parent

renames = {
    "bin/plumos-bubble-mount-sd2": "bin/plumos-mount-sd2",
    "bin/plumos-network-control-bubble": "bin/plumos-wifi-control",
    "bin/plumos-python-bubble": "bin/plumos-python",
    "bin/plumos-pyxel-bubble-launch": "bin/plumos-pyxel-launch",
    "bin/plumos-storage-health-bubble": "bin/plumos-storage-health-core",
    "factory-defaults/retroarch/retroarch-bubble.cfg":
        "factory-defaults/retroarch/retroarch-rk3566.cfg",
    "factory-defaults/retroarch/retroarch-bubble-pre-v90s.cfg":
        "factory-defaults/retroarch/retroarch-rk3566-pre-v90s.cfg",
    "factory-defaults/retroarch/autoconfig/udev/gkd-bubble-retrogame-joypad.cfg":
        "factory-defaults/retroarch/autoconfig/udev/rk3566-retrogame-joypad.cfg",
}
names = {Path(old).name: Path(new).name for old, new in renames.items()}
names.update({
    "PLUMOS_BUBBLE_PYTHON_": "PLUMOS_RK3566_PYTHON_",
    "PLUMOS_BUBBLE_PYXEL_ROOT": "PLUMOS_PYXEL_ROOT",
    "PLUMOS_BUBBLE_MAX_BRIGHTNESS": "PLUMOS_MAX_BRIGHTNESS",
    "PLUMOS_BUBBLE_BACKLIGHT": "PLUMOS_BACKLIGHT",
    "pyxel:bubble": "pyxel:rk3566",
    "bubble-rk3566-backlight": "rk3566-backlight",
    "bubble-sdl2-kmsdrm-gles2": "rk3566-sdl2-kmsdrm-gles2",
    "bubble_only_start_entries": "device_specific_start_entries",
    "bubble_only_apps_entries": "device_specific_apps_entries",
    "bubble_portmaster_route_only_accepts_top_level_sh_launchers":
        "portmaster_route_only_accepts_top_level_sh_launchers",
    "bubble_daphne_core_uses_zip_game_bundles": "daphne_core_uses_zip_game_bundles",
    "plumos-bubble-portmaster-v1": "plumos-rk3566-portmaster-v1",
    "plumOS-Bubble-PortMaster/1": "plumOS-RK3566-PortMaster/1",
    "plumos-bubble-1": "plumos-rk3566-1",
    "bubble-gui-": "rk3566-gui-",
    ":-bubble-$(date": ":-rk3566-$(date",
    "/bubble.cfg": "/rk3566.cfg",
    "before-bubble-softvol": "before-rk3566-softvol",
    "Bubble Mali": "RK3566 Mali",
    "Bubble Python": "Bundled Python",
    "Bubble graphics devices": "graphics devices",
    "PPSSPP Bubble devices": "PPSSPP display devices",
    "the Bubble app layer": "the RK3566 app layer",
    "PortMaster Bubble ": "PortMaster ",
    "required Bubble audio helper": "required audio helper",
})
changed = set()


def substitute(text):
    for old, new in names.items():
        text = text.replace(old, new)
    return text


def write(path, text, original):
    if text != original:
        path.write_text(text)
        if path.is_relative_to(root):
            changed.add(str(path.relative_to(root)))


def edit_text(path):
    if path.is_symlink() or not path.is_file():
        return
    with path.open("rb") as stream:
        if stream.read(4) == b"\x7fELF":
            return
    text = path.read_text()
    write(path, substitute(text), text)


def update_metadata(data):
    if isinstance(data, list):
        return [update_metadata(value) for value in data]
    if isinstance(data, dict):
        return {
            substitute(key): "rk3566"
            if key in {"device", "device_specific", "runtime_id"} and value == "bubble"
            else update_metadata(value)
            for key, value in data.items()
        }
    if not isinstance(data, str):
        return data
    data = substitute(data)
    for old, new in (
        ("for plumOS Bubble", "for plumOS-RK3566"),
        ("for Bubble", "for plumOS-RK3566"),
        ("plumOS Bubble", "plumOS-RK3566"),
        ("miyoo-flip pending per-port Bubble validation", "miyoo-flip compatibility profile"),
    ):
        data = data.replace(old, new)
    return data


for old, new in renames.items():
    if (root / old).exists():
        if (root / new).exists():
            raise SystemExit(f"Both runtime paths exist: {old}, {new}")
        (root / old).rename(root / new)

for path in (
    *root.glob("bin/plumos-*"),
    *root.glob("apps/portmaster/adapter/*.py"),
    *root.glob("apps/portmaster/adapter/shims/python*"),
    root / "apps/portmaster/adapter/control.txt",
    payload / "manage-sd2",
):
    edit_text(path)

for path in (
    *root.glob("components/*/manifest.json"),
    *root.glob("config/frontend/*.json"),
    root / "factory-defaults/system/settings.json",
):
    text = path.read_text()
    data = json.loads(text)
    updated = update_metadata(data)
    if updated != data:
        write(path, json.dumps(updated, ensure_ascii=False, indent=2) + "\n", text)

for component in ("music-player", "nextcommander", "pyxel"):
    path = root / f"share/doc/{component}/README.txt"
    text = path.read_text()
    write(path, substitute(text).replace("for Bubble", "for plumOS-RK3566"), text)

# The v0.1.x public-key filename belongs to the old updater. Stamp the
# official key at the canonical path used by both fresh build paths.
update = root / "share/update"
(update / "plumos-bubble-update-public.pem").unlink(missing_ok=True)
key = update / "plumos-rk3566-update-public.pem"
key.write_bytes((prototype / "update/rk3566-update-public.pem").read_bytes())
key.chmod(0o644)
updater = update / "plumos-system-update.py"
text = updater.read_text()
configured = subprocess.run(
    ["sed", "-f", str(prototype / "update/configure-rk3566-update.sed")],
    input=text, text=True, check=True, stdout=subprocess.PIPE,
).stdout
write(updater, configured, text)

for path in root.glob("components/*/checksums.sha256"):
    text = path.read_text()
    entries = []
    for line in text.splitlines():
        digest, relative = line.split("  ", 1)
        relative = renames.get(relative, relative)
        if relative in changed:
            digest = hashlib.sha256((root / relative).read_bytes()).hexdigest()
        entries.append(f"{digest}  {relative}")
    write(path, "\n".join(entries) + "\n", text)
