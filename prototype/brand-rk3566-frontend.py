"""Apply RK3566 display names to the pinned frontend sources and translations."""
from pathlib import Path
import json
import sys

source = Path(sys.argv[1])
frontend = source / "src/frontend"
assets = source / "package/frontend-bubble/plumos"

for path, replacements in {
    frontend / "plumos_fbdev_renderer.h": {"plumOS Bubble": "plumOS-RK3566"},
    frontend / "plumos_controller_ui.c": {
        "GKD Bubble": "RK3566",
        "Bubble RK3566 backlight": "RK3566 backlight",
        "RG353M RK3566 backlight / DSI": "RK3566 backlight / DSI",
        "Bubble runtime update": "plumOS-RK3566 runtime update",
        "Bubble DRM property": "RK3566 DRM property",
    },
    assets / "bin/plumos-system-update": {
        "Bubble Python runtime is missing": "Python runtime is missing",
        "Bubble update engine is missing": "plumOS update engine is missing",
    },
    assets / "share/update/plumos-system-update.py": {
        "Transactional Runtime updater for plumOS Bubble.": "Transactional Runtime updater for plumOS-RK3566.",
        "Bubble currently accepts runtime update packages only": "plumOS-RK3566 accepts runtime update packages only",
        "package target does not match Bubble aarch64": "package target does not match RK3566 aarch64",
    },
}.items():
    text = path.read_text()
    for old, new in replacements.items():
        text = text.replace(old, new)
    path.write_text(text)

for path in (assets / "share/frontend/lang").glob("*.lang"):
    text = path.read_text()
    updated = (text.replace("Bubble RK3566", "RK3566")
                   .replace("Bubble Runtime", "plumOS-RK3566 Runtime")
                   .replace("GKD Bubble", "RK3566")
                   .replace("Bubble", "RK3566"))
    if updated != text:
        path.write_text(updated)

path = assets / "factory-defaults/system/settings.json"
settings = json.loads(path.read_text())
settings["model"] = "RK3566"
path.write_text(json.dumps(settings, ensure_ascii=False, indent=2) + "\n")
