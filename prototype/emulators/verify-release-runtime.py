#!/usr/bin/env python3
"""Verify the packaged runtime behind every FE emulator profile."""

import hashlib
import json
import os
from pathlib import Path
import shlex
import sys


root = Path(sys.argv[1])
frontend = root / "config/frontend"
catalog = json.loads((frontend / "systems.json").read_text())
coverage = json.loads((frontend / "runtime-coverage.json").read_text())
routes = {
    (system["system_id"], route["profile"]): route
    for system in coverage["systems"]
    for route in system["routes"]
}
expected = {
    (system["id"], profile)
    for system in catalog["systems"]
    for profile in system["launch_profiles"]
}
if routes.keys() != expected:
    raise SystemExit("FE catalog and generated runtime coverage disagree")


def require(relative, executable=False):
    path = root / relative
    if not path.is_file() or (executable and not os.access(path, os.X_OK)):
        raise SystemExit(f"Missing release runtime file: {relative}")
    return path


for system in catalog["systems"]:
    if not system.get("enabled", True):
        raise SystemExit(f"Release system is hidden from the FE: {system['id']}")
    if system.get("builtin_entry"):
        require(Path("share/frontend-builtins") / system["builtin_entry"])

for route in routes.values():
    require(route["binary"], executable=route["runtime"] not in {"retroarch", "picoarch"})
    if route["license"]["status"] in {"packaged", "project-approved-inclusion"}:
        require(route["license"]["path"])
    require(coverage["ownership_policies"][route["runtime"]]["loader"], executable=True)

psp_routes = [route for (system_id, _), route in routes.items() if system_id == "psp"]
if len(psp_routes) != 1 or psp_routes[0]["profile"] != "standalone:ppsspp":
    raise SystemExit("PSP must expose exactly one launch profile, with the existing saved core ID")
if psp_routes[0]["renderer"] != "malisx2-vulkan-kmsdrm":
    raise SystemExit("PSP launch profile requires the MaliSX2 Vulkan renderer")
ppsspp_driver = Path("emulator/standalone/ppsspp/vulkan")
for dependency in (
    "libvulkan.so.1", "libvulkan_malisx2.so", "malisx2_icd.json", "MANIFEST.json",
    "licenses/MaliSX2-LICENSE", "licenses/Mesa-license.rst", "licenses/libvulkan1-copyright",
):
    require(ppsspp_driver / dependency)

apps = json.loads((frontend / "apps.json").read_text())["apps"]
internal_tools = {
    "internal:scraping": ("bin/plumos-thumbnail-scraper", "bin/curl", "scraper/lib/plumos-curl"),
    "internal:sd2-repair": ("bin/plumos-sd2-repair", "bin/plumos-fsck-fat", "storage-tools/fsck.fat"),
}
for app in apps:
    if app["menu"] != "apps" or not app.get("visible", True):
        continue
    profile = app["launch_profile"]
    if profile in internal_tools:
        for tool in internal_tools[profile]:
            require(tool, executable=True)
    elif profile.startswith("shell:$PLUMOS_ROOT/"):
        require(shlex.split(profile.removeprefix("shell:$PLUMOS_ROOT/"))[0], executable=True)
    else:
        raise SystemExit(f"Unsupported release Apps entry: {app['id']}")

for executable in (
    "bin/retroarch",
    "bin/plumos-retroarch-menu-launch",
    "picoarch/bin/picoarch",
    "bin/plumos-python-bubble",
    "bin/plumos-pyxel-setup",
    "apps/python/lib/ld-linux-aarch64.so.1",
    "bin/plumos-portmaster-launch",
    "bin/plumos-portmaster-port-stop",
    "bin/plumos-portmaster-runtime",
    "apps/portmaster/adapter/bin/aarch64/bash",
    "apps/nextcommander/bin/NextCommander",
    "apps/music-player/bin/plumos-music-player.bin",
    "bin/plumos-ggfe",
    "share/libretro-system/freej2me-plus/freej2me_plus_runtime/linux-arm64/bin/java",
):
    require(executable, executable=True)
for dependency in (
    "config/frontend/scraper-sources.tsv",
    "lib/alsa-lib/libasound_module_pcm_plumos_hotplug.so",
    "lib/alsa-lib-armhf/libasound_module_pcm_plumos_hotplug.so",
    "apps/pyxel/lib/libSDL2-2.0.so.0",
    "emulator/standalone/pcsx_rearmed/lib/libSDL2-2.0.so.0",
    "apps/pyxel/lib/plumos-pyxel-fit.so",
    "apps/portmaster/upstream/PortMaster/pylibs.zip",
    "share/libretro-system/freej2me-plus/freej2me_plus_runtime/linux-arm64/bin/freej2me_plus-lr.jar",
):
    require(dependency)

for component in ("retroarch", "libretro-cores", "picoarch", "standalone", "pyxel",
                  "portmaster", "freej2me-plus", "nextcommander", "music-player"):
    checksums = require(f"components/{component}/checksums.sha256").read_text().splitlines()
    if not checksums:
        raise SystemExit(f"Empty release checksums for {component}")
    for line in checksums:
        expected_hash, relative = line.split("  ", 1)
        digest = hashlib.sha256()
        with require(relative).open("rb") as stream:
            for block in iter(lambda: stream.read(1024 * 1024), b""):
                digest.update(block)
        if digest.hexdigest() != expected_hash:
            raise SystemExit(f"Release runtime checksum mismatch: {relative}")

print(f"Verified {len(routes)} FE profiles, visible Apps entries and nine packaged components")
