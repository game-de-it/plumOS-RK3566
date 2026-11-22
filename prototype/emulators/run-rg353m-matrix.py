#!/usr/bin/env python3
"""Execute the RG353M plan over ADB while isolating emulator saves and config."""
import argparse
import json
from pathlib import Path
import shlex
import subprocess

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("adb", type=Path)
parser.add_argument("plan", type=Path)
parser.add_argument("report", type=Path)
parser.add_argument("--only", nargs="*", metavar="SYSTEM")
args = parser.parse_args()
data = json.loads(args.plan.read_text())
if args.report.exists():
    completed = {(r["system"], r["profile"], r["rom"], r["cpu"]): r["result"]
                 for r in json.loads(args.report.read_text()) if "result" in r}
    for record in data:
        key = (record["system"], record["profile"], record["rom"], record["cpu"])
        if record["status"] == "planned" and key in completed:
            record["result"] = completed[key]
runner = Path(__file__).with_name("probe-rg353m-route.py")
device = "/run/plumos-353m/rg353m-probe.py"

def adb(*cmd, timeout=40):
    return subprocess.run([str(args.adb.resolve()), *cmd], text=True, capture_output=True,
                          check=True, timeout=timeout).stdout

def save_report():
    temporary = args.report.with_suffix(args.report.suffix + ".tmp")
    temporary.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n")
    temporary.replace(args.report)

root = "/storage/plumos-rk3566/frontend"
run = "/run/plumos-353m"
paths = "config/retroarch config/standalone state/retroarch state/picoarch state/standalone state/pyxel-home saves states"
if any(record.get("frontend_launch") for record in data):
    paths += " state/frontend"
setup = f'''
set -eu
R={root}
V={run}
export PLUMOS_ROOT=$R PLUMOS_RUNTIME_ROOT=$V
"$R/bin/plumos-volume-control" apply 4
test "$(cat "$V/volume/current")" = 4
test ! -e "$V/validation-hold"
frontend_pid=
for attempt in 1 2 3 4 5 6 7 8 9 10; do
    frontend_pid=$(sed -n 's/^pid=//p' /tmp/plumos-fe-ready 2>/dev/null || :)
    if test -n "$frontend_pid" && kill -0 "$frontend_pid" 2>/dev/null; then
        break
    fi
    sleep 1
done
test -n "$frontend_pid"
kill -0 "$frontend_pid"
grep -qs ' /sys/kernel/tracing tracefs ' /proc/mounts || mount -t tracefs tracefs /sys/kernel/tracing
mkdir -p /sys/kernel/tracing/instances/plumos-matrix
sed '/^set -eu/a while [ -e {run}/validation-hold ]; do sleep 1; done' /usr/lib/plumos-353m/start-frontend > "$V/matrix-frontend"
chmod 755 "$V/matrix-frontend"
: > "$V/validation-hold"
mount --bind "$V/matrix-frontend" /usr/lib/plumos-353m/start-frontend
kill -TERM "$frontend_pid"
sleep 2
test -z "$(pgrep -x plumos-controll || :)"
: > "$V/matrix-mounts"
for rel in {paths}; do
    mkdir -p "$V/matrix-state/$rel" "$R/$rel"
    mount --bind "$V/matrix-state/$rel" "$R/$rel"
    printf '%s\n' "$R/$rel" >> "$V/matrix-mounts"
done
'''
cleanup = f'''
V={run}
if test -f "$V/matrix-mounts"; then
    while IFS= read -r path; do umount -l "$path"; done < "$V/matrix-mounts"
    rm -f "$V/matrix-mounts"
fi
if grep -qs ' /usr/lib/plumos-353m/start-frontend ' /proc/mounts; then
    umount -l /usr/lib/plumos-353m/start-frontend
fi
rm -f "$V/validation-hold"
rmdir /sys/kernel/tracing/instances/plumos-matrix 2>/dev/null || :
'''
todo = [r for r in data if r["status"] == "planned" and not r.get("result")
        and (not args.only or r["system"] in args.only)]
save_report()
if todo:
    adb("push", str(runner), device)
    initialized = False
    try:
        adb("shell", "-T", "test ! -e /run/plumos-353m/validation-hold")
        initialized = True
        adb("shell", "-T", setup)
        for idx, record in enumerate(todo, 1):
            command = f"python3 {device} {shlex.quote(json.dumps(record, ensure_ascii=False))}"
            try:
                frame_limit = record.get("picoarch_diagnostic_frames", 0)
                sample_seconds = record.get("sample_seconds", 3)
                startup_seconds = record.get("startup_seconds", 2)
                output = adb("shell", "-T", command,
                             timeout=55 + frame_limit / 30 + sample_seconds + startup_seconds)
                record["result"] = json.loads(output)
            except (subprocess.CalledProcessError, subprocess.TimeoutExpired, json.JSONDecodeError) as exc:
                record["result"] = {"outcome": "probe_error", "reason": str(exc),
                                    "detail": str(getattr(exc, "stderr", ""))[-1000:]}
            save_report()
            result = record["result"]
            print(idx, len(todo), record["system"], record["profile"], result["outcome"],
                  result.get("play", {}), flush=True)
    finally:
        if initialized:
            adb("shell", "-T", cleanup)
