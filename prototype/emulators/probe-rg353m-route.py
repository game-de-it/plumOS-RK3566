#!/usr/bin/env python3
"""Run one bounded test on the RG353M and emit a JSON result."""
import glob
import json
import os
from pathlib import Path
import re
import signal
import shutil
import struct
import subprocess
import sys
import time

root = Path("/storage/plumos-rk3566/frontend")
rom_root = Path("/storage/user/.plumos-emulator-matrix")
run = Path("/run/plumos-353m")
trace = Path("/sys/kernel/tracing/instances/plumos-matrix")
pcm = Path("/proc/asound/card0/pcm0p/sub0/status")

def write(path, value):
    path.write_text(str(value))

def count_frames():
    data = (trace / "trace").read_text(errors="replace")
    return len(re.findall(r"drm_vblank_event_delivered: .*crtc=1,", data))

def wait_sample(seconds):
    start = time.monotonic()
    count = count_frames()
    pointers, states, starts = [], set(), set()
    frequencies = []
    while time.monotonic() - start < seconds:
        try:
            data = pcm.read_text(errors="replace")
        except OSError:
            data = ""
        if data:
            states.add(data.splitlines()[0].removeprefix("state: "))
        match = re.search(r"^hw_ptr\s*:\s*(\d+)", data, re.M)
        if match:
            pointers.append(int(match[1]))
        trigger = re.search(r"^trigger_time\s*:\s*(\S+)", data, re.M)
        if trigger:
            starts.add(trigger[1])
        try:
            frequencies.append(int(Path("/sys/devices/system/cpu/cpufreq/policy0/scaling_cur_freq").read_text()))
        except (OSError, ValueError):
            pass
        time.sleep(0.24)
    return {
        "fps": round((count_frames() - count) / (time.monotonic() - start), 2),
        "pcm_states": sorted(states),
        "pcm_progress": len(set(pointers)) > 1,
        "pcm_triggers": len(starts),
        "cpu_khz_min": min(frequencies) if frequencies else None,
        "cpu_khz_max": max(frequencies) if frequencies else None,
    }

def press_joypad_key(code):
    device = next(p for p in Path("/sys/class/input").glob("event*")
                  if (p / "device/name").read_text().strip() == "retrogame_joypad")
    event = struct.Struct("@llHHi")
    with open("/dev/input/" + device.name, "wb", buffering=0) as stream:
        for value in (1, 0):
            stream.write(event.pack(0, 0, 1, code, value))
            stream.write(event.pack(0, 0, 0, 0, 0))
            time.sleep(0.12)

def process_owns_drm(group):
    for name in glob.glob("/proc/[0-9]*/stat"):
        try:
            if int(Path(name).read_text().rsplit(")", 1)[1].split()[2]) != group:
                continue
            for fd in Path(name).parent.joinpath("fd").iterdir():
                if fd.is_symlink() and os.readlink(fd) == "/dev/dri/card0":
                    return True
        except (FileNotFoundError, ProcessLookupError, PermissionError):
            continue
    return False

def stop(proc):
    try:
        os.killpg(proc.pid, signal.SIGTERM)
    except ProcessLookupError:
        pass
    try:
        proc.wait(timeout=1.5)
    except subprocess.TimeoutExpired:
        pass
    try:
        os.killpg(proc.pid, signal.SIGKILL)
    except ProcessLookupError:
        pass
    proc.wait()

def command(record, env):
    sid = record["system"]
    kind, name = record["profile"].split(":", 1)
    rom = str(rom_root / record["rom"]) if record["rom"] else None
    cpu = record.get("cpu", "ondemand")
    if kind == "retroarch":
        option = ["--rom", rom] if rom else ["--no-content"]
        return ("plumos-retroarch-launch",
                ["--system", sid, "--core", str(root / "cores" / (name + "_libretro.so")),
                 *option, "--cpu", cpu, "--safe-exit", "false"],
                root / "logs" / f"retroarch-{sid}-{name}.log")
    if kind == "picoarch":
        env.update(PLUMOS_PICOARCH_SYSTEM=sid, PLUMOS_PICOARCH_CPU_POLICY=cpu)
        return "plumos-picoarch-launch", [name, rom], root / "logs" / f"picoarch-{sid}-{name}.log"
    if kind == "standalone":
        env["PLUMOS_STANDALONE_CPU_POLICY"] = cpu
        logs = {"pcsx_rearmed": "pcsx-rearmed", "ppsspp": "ppsspp", "drastic": "drastic",
                "yabasanshiro": "yabasanshiro", "openbor": "openbor"}
        return "plumos-standalone-launch", [name, rom], root / "logs" / (logs[name] + "-standalone.log")
    if kind == "pyxel":
        return "plumos-pyxel-bubble-launch", ["-m", "pyxel", "play", rom], root / "logs/pyxel/runtime.log"
    if kind == "external" and name == "port":
        return "plumos-portmaster-port-launch", [rom], root / "logs/apps/portmaster-ports.log"
    raise ValueError(kind)

record = json.loads(sys.argv[1])
if record["profile"].startswith("retroarch:"):
    # The matrix runner bind-mounts this config directory onto tmpfs. Keep
    # audio A/B experiments scoped to a single probe and restore the factory
    # value for the next record, including when RetroArch saves its config.
    cfg = root / "config/retroarch/retroarch-bubble.cfg"
    factory = root / "factory-defaults/retroarch/retroarch-bubble.cfg"
    shutil.copyfile(factory, cfg)
    source = cfg.read_text()
    for key, value in (("audio_latency", record.get("audio_latency_ms")),
                       ("audio_driver", record.get("audio_driver"))):
        if value is None:
            continue
        source, changed = re.subn(rf'^{key} = "[^"]*"$',
                                  f'{key} = "{value}"', source, flags=re.M)
        if changed != 1:
            raise RuntimeError(f"expected one {key} in RetroArch config")
    cfg.write_text(source)
if record.get("user_media"):
    rom_root = Path("/storage/user/Roms")
    sdcard_root = rom_root.parent
else:
    sdcard_root = rom_root if record.get("frontend_launch") else Path("/storage/user")
bios_root = run / "matrix-packaged-bios" if record.get("use_packaged_bios") else rom_root / "bios"
if record.get("user_media"):
    bios_root = sdcard_root / "BIOS"
env = dict(os.environ, PLUMOS_ROOT=str(root), PLUMOS_ROM_ROOT=str(rom_root),
           PLUMOS_BIOS_ROOT=str(bios_root), PLUMOS_RUNTIME_ROOT=str(run),
           PLUMOS_SDCARD_ROOT=str(sdcard_root), PLUMOS_BUSYBOX=str(root / "bin/busybox"),
           ALSA_CONFIG_PATH=str(run / "audio/asound.conf"),
           PLUMOS_RG353M_DRM="1", HOME="/storage")
launcher, argv, log = command(record, env)
if not (root / "bin" / launcher).exists():
    print(json.dumps({"outcome": "unavailable", "reason": "launcher_missing"}))
    sys.exit(0)
sample = rom_root / record["rom"] if record["rom"] else None
if record.get("builtin"):
    sample = root / "share/frontend-builtins" / Path(record["rom"]).name
if sample is not None and not sample.is_file():
    print(json.dumps({"outcome": "unavailable", "reason": "sample_not_staged"}))
    sys.exit(0)

offset = log.stat().st_size if log.exists() else 0
wrapper = run / "matrix-wrapper.log"
diagnostic_frames = (record.get("picoarch_diagnostic_frames")
                     if record["profile"].startswith("picoarch:") else None)
if diagnostic_frames:
    screenshot = run / f"matrix-{record['system']}-{record['profile'].split(':', 1)[1]}"
    screenshot_file = Path(f"{screenshot}.bmp")
    screenshot_file.unlink(missing_ok=True)
    env.update(PLUMOS_PICOARCH_PROBE_FRAMES=str(diagnostic_frames),
               PLUMOS_PICOARCH_PROBE_SCREENSHOT=str(screenshot),
               PLUMOS_PICOARCH_AUDIO_REPORT="1")
write(trace / "tracing_on", 0)
write(trace / "trace", "")
write(trace / "events/drm/drm_vblank_event_delivered/enable", 1)
write(trace / "tracing_on", 1)
proc = None
out = {}
cpu_min_path = Path("/sys/devices/system/cpu/cpufreq/policy0/scaling_min_freq")
original_cpu_min = None
try:
    if "cpu_floor_khz" in record:
        original_cpu_min = cpu_min_path.read_text().strip()
        cpu_min_path.write_text(str(int(record["cpu_floor_khz"])))
    with wrapper.open("wb") as stream:
        if record.get("frontend_launch") and record["rom"]:
            launch_command = [str(root / "bin/plumos-text-ui"), "launch", record["system"],
                              record["rom"], "--profile", record["profile"], "--execute"]
        else:
            launch_command = [env["PLUMOS_BUSYBOX"], "sh", str(root / "bin" / launcher), *argv]
        proc = subprocess.Popen(launch_command,
                                env=env, start_new_session=True, stdout=stream, stderr=stream)
    deadline = time.monotonic() + (16 if record["profile"].startswith("standalone:") else 9)
    while proc.poll() is None and time.monotonic() < deadline and not process_owns_drm(proc.pid):
        time.sleep(0.25)
    time.sleep(record.get("startup_seconds", 2))
    out["drm_open"] = process_owns_drm(proc.pid)
    sample_seconds = record.get("sample_seconds", 6 if diagnostic_frames else 3)
    out["play"] = wait_sample(sample_seconds) if proc.poll() is None else {}
    mixer = subprocess.run(["/usr/bin/amixer", "-c", "0", "cget", "name=Soft Volume Master"],
                           text=True, capture_output=True, timeout=3)
    match = re.search(r": values=(\d+(?:,\d+)*)", mixer.stdout)
    out["softvol"] = match[1] if match else None
    if (record.get("check_fn", True) and proc.poll() is None and out["drm_open"]
            and not record["profile"].startswith("pyxel:")):
        press_joypad_key(316)
        out["menu"] = wait_sample(1.25)
        press_joypad_key(304 if record["profile"] == "standalone:drastic" else 316)
        out["resumed"] = wait_sample(1.25)
    if diagnostic_frames and proc.poll() is None:
        try:
            proc.wait(timeout=diagnostic_frames / 30 + 10)
        except subprocess.TimeoutExpired:
            out["diagnostic_timed_out"] = True
    out["exit_before_cleanup"] = proc.poll()
finally:
    if proc is not None:
        if record["profile"] == "external:port":
            try:
                subprocess.run([str(root / "bin/plumos-portmaster-port-stop"), "stop"],
                               env=env, capture_output=True, timeout=10)
            except subprocess.TimeoutExpired:
                out["port_stop_timed_out"] = True
        stop(proc)
    write(trace / "tracing_on", 0)
    write(trace / "events/drm/drm_vblank_event_delivered/enable", 0)
    if original_cpu_min is not None:
        cpu_min_path.write_text(original_cpu_min)
    time.sleep(0.15)
runtime = b""
if log.exists():
    with log.open("rb") as stream:
        stream.seek(min(offset, log.stat().st_size))
        runtime = stream.read()
message = runtime.decode(errors="replace")
out["menu_layer_seen"] = bool(re.search(r"layer=2\b", message))
if diagnostic_frames:
    completed = re.search(r"Frame probe complete: frames=(\d+)", message)
    underrun = re.search(r"Audio underrun frames: (\d+)", message)
    out["picoarch_frames_completed"] = int(completed[1]) if completed else None
    out["picoarch_audio_underrun_frames"] = int(underrun[1]) if underrun else None
    if completed and screenshot_file.is_file():
        out["picoarch_screenshot"] = str(screenshot_file)
out["outcome"] = "frames_observed" if out.get("play", {}).get("fps", 0) > 0 else "no_frames_observed"
out["runtime_log"] = message[-5000:]
out["wrapper_log"] = wrapper.read_text(errors="replace")[-2500:]
print(json.dumps(out))
