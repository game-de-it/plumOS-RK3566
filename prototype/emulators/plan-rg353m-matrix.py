#!/usr/bin/env python3
"""Select representative ROM2 content for every Bubble launch profile."""
import argparse
import json
from pathlib import Path
import re
import shlex
import subprocess
import time

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("catalog", type=Path)
parser.add_argument("roms", type=Path)
parser.add_argument("report", type=Path)
parser.add_argument("--adb", type=Path, help="transfer content to an isolated p5 directory")
args = parser.parse_args()
root = args.roms.resolve()
remote = "/storage/user/.plumos-emulator-matrix"
systems = json.loads(args.catalog.read_text())["systems"]
preferred = {
    "nes": "Binary Land.nes",
    "gba": "Densetsu no Stafy (Japan).gba",
    "megadrive": "Bare Knuckle - Ikari no Tekken ~ Streets of Rage (World).md",
    "pcengine": "Bomberman_93_U.pce",
    "psx": "chroQW.img",
    "psp": "Star Soldier (Japan).iso",
    "dreamcast": "Crazy Taxi (Japan).chd",
    "neogeocd": "Fatal Fury WAV.cue",
    "msx": "usas.rom",
    "atari5200": "Millipede.a52",
    "atari800": "CavernsOfMars.rom",
    "cavestory": "Doukutsu.exe",
    "lutro": "lutro-pong.lutro",
    "arcade": "imgfight.zip",
    "fbneo": "imgfight.zip",
    "mame2003plus": "varthj.zip",
    "cps1": "varthj.zip",
    "cps2": "ssf2tu.zip",
    "cps3": "sfiii3nr1.zip",
    "pico8": "51752.p8",
    "scummvm": "sky.scummvm",
    "pyxel": "finardry.pyxapp",
}
extra = {
    "arcade": ["mame", "fbneo"],
    "cps1": ["mame", "fbneo"],
    "cps2": ["mame", "fbneo"],
    "cps3": ["mame", "fbneo"],
    "supervision": ["_etc/supervision"],
    "supergrafx": ["_etc/supergrafx"],
    "wonderswancolor": ["wonderswan"],
    "gameandwatch": ["_etc/gameandwatch"],
    "cpc": ["_etc/cpc"],
}

def folder(name):
    current = root
    for part in Path(name).parts:
        if not current.is_dir():
            return current / part
        current = next((p for p in current.iterdir() if p.name.casefold() == part.casefold()), current / part)
    return current

def dependencies(path, system_id):
    files = [path]
    if path.suffix.lower() == ".cue":
        members = re.findall(r'^\s*FILE\s+(?:"([^"]+)"|(\S+))', path.read_text(errors="replace"), re.I | re.M)
        for quoted, bare in members:
            name = quoted or bare
            if Path(name).name != name:
                return []
            found = next((p for p in path.parent.iterdir() if p.name == name), None)
            if not found or not found.is_file() or found.stat().st_size == 0:
                return []
            files.append(found)
    elif path.suffix.lower() == ".ccd":
        files.extend(p for p in path.parent.glob(path.stem + ".*") if p.suffix.lower() in {".img", ".sub"})
        if not any(p.suffix.lower() == ".img" and p.stat().st_size > 0 for p in files):
            return []
    elif path.suffix.lower() == ".gdi":
        for line in path.read_text(errors="replace").splitlines()[1:]:
            fields = re.findall(r'"[^"]+"|\S+', line)
            if len(fields) < 6 or Path(fields[-2].strip('"')).name != fields[-2].strip('"'):
                return []
            files.append(path.parent / fields[-2].strip('"'))
        if not all(p.is_file() and p.stat().st_size > 0 for p in files):
            return []
    elif (path.suffix.lower() in {".ldb", ".scummvm", ".svm"}
          or system_id in {"cannonball", "cavestory", "dinothawr"}):
        files = sorted(p for p in path.parent.rglob("*") if p.is_file() and not p.name.startswith("."))
    return files

def adb(*command):
    for attempt in range(3):
        try:
            subprocess.run([str(args.adb.resolve()), *command], check=True, timeout=180)
            return
        except (subprocess.CalledProcessError, subprocess.TimeoutExpired):
            if attempt == 2:
                raise
            time.sleep(3)

def transfer(path):
    relative = path.relative_to(root).as_posix()
    target = f"{remote}/{relative}"
    adb("shell", "-T", f"mkdir -p {shlex.quote(target.rsplit('/', 1)[0])}")
    adb("push", "--sync", str(path), target)
    return target

records = []
copied = set()
for system in systems:
    sid = system["id"]
    profiles = system.get("launch_profiles", [])
    if not profiles:
        continue
    extensions = set(system.get("extensions", [])) - {"m3u", "7z"}
    if sid == "supergrafx":
        extensions.discard("pce")
    aliases = extra.get(sid, []) + [a["name"] for a in system.get("directory_aliases", [])]
    files = set()
    for alias in aliases:
        directory = folder(alias)
        if directory.is_dir():
            accepted = extensions | {"pce"} if alias == "_etc/supergrafx" else extensions
            candidates = (p for p in directory.rglob("*") if p.is_file()
                          and not any(part.startswith(".") or part.casefold() == "bios"
                                      for part in p.relative_to(directory).parts))
            if sid == "fds":
                files.update(p for p in candidates if p.name.lower().endswith((".fds", ".fds.zip")))
            else:
                files.update(p for p in candidates if p.suffix.lower().lstrip(".") in accepted)
    sizes = {p: p.stat().st_size for p in files}
    ordered = sorted((p for p, size in sizes.items() if size > 0), key=lambda p: (
        p.name.casefold() != preferred.get(sid, "").casefold(),
        p.suffix.lower() in {".zip", ".iso", ".gdi"},
        sizes[p], str(p).casefold(),
    ))
    if sid == "pico8":
        ordered = [p for p in ordered if p.suffix.lower() == ".p8" or p.name.lower().endswith(".p8.png")]
    if sid in {"arcade", "cps1", "cps2", "cps3", "mame2003plus", "fbneo"}:
        ordered = [p for p in ordered if p.name.casefold() == preferred[sid].casefold()]
    selected = next(((p, companions) for p in ordered if (companions := dependencies(p, sid))), None)
    if not selected and sid == "scummvm":
        directory = folder("scummvm/BASS-Floppy-1.3")
        game_files = {p.name.casefold(): p for p in directory.iterdir() if p.is_file()} if directory.is_dir() else {}
        if {"sky.dsk", "sky.dnr"} <= game_files.keys():
            selected = (directory / "sky.scummvm", list(game_files.values()))
    for profile in profiles:
        no_content = profile in {"retroarch:2048", "retroarch:mrboom"}
        if profile.startswith("external:"):
            status, reason = "unavailable", "external_port_requires_review"
        elif no_content or selected:
            status, reason = "planned", None
        else:
            status, reason = "unavailable", "no_compatible_sample_in_rom2"
        path = selected[0] if selected and not no_content else None
        records.append({"system": sid, "profile": profile, "status": status, "reason": reason,
                        "rom": path.relative_to(root).as_posix() if path else None,
                        "cpu": system.get("default_cpu_policy", "ondemand")})
    if args.adb and selected and any(r["status"] == "planned" for r in records[-len(profiles):]):
        for member in selected[1]:
            if member not in copied:
                transfer(member)
                copied.add(member)
        if sid == "scummvm" and not selected[0].exists():
            target = f"{remote}/{selected[0].relative_to(root).as_posix()}"
            adb("shell", "-T", f"printf '%s\\n' sky > {shlex.quote(target)}")
if args.adb:
    bios = folder("bios")
    if bios.is_dir():
        names = {"scph5500.bin", "scph5501.bin", "scph5502.bin", "scph1001.bin", "gba_bios.bin",
                 "disksys.rom", "syscard3.pce", "neogeo.zip", "dc_boot.bin", "dc_flash.bin",
                 "sega_101.bin", "mpr-17933.bin", "coleco.rom", "bios_CD_U.bin", "bios_CD_E.bin",
                 "bios_CD_J.bin", "kick34005.A500", "kick40068.A1200", "exec.bin", "grom.bin"}
        coverage = args.catalog.with_name("runtime-coverage.json")
        if coverage.is_file():
            planned_systems = {r["system"] for r in records if r["status"] == "planned"}
            names.update(f["path"] for s in json.loads(coverage.read_text())["systems"]
                         if s["system_id"] in planned_systems
                         for r in s["routes"] for f in r["bios"]["files"])
        by_path = {}
        by_name = {}
        for path in bios.rglob("*"):
            if path.is_file():
                by_path.setdefault(path.relative_to(bios).as_posix().casefold(), path)
                by_name.setdefault(path.name.casefold(), path)
        if any(r["status"] == "planned" and r["profile"] == "retroarch:bluemsx" for r in records):
            for path in by_path.values():
                if path.relative_to(bios).parts[0] in {"Databases", "Machines"}:
                    names.add(path.relative_to(bios).as_posix())
        for name in sorted(names):
            relative = Path(name)
            if relative.is_absolute() or ".." in relative.parts:
                continue
            found = by_path.get(name.casefold())
            if not found and len(relative.parts) == 1:
                found = by_name.get(name.casefold())
            if found:
                target = f"{remote}/bios/{relative.as_posix()}"
                adb("shell", "-T", f"mkdir -p {shlex.quote(target.rsplit('/', 1)[0])}")
                adb("push", "--sync", str(found), target)
args.report.write_text(json.dumps(records, ensure_ascii=False, indent=2) + "\n")
