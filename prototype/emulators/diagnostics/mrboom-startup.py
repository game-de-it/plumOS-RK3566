"""Record a bounded timeline around a stalled Mr.Boom startup on RK3566."""

from collections import deque
from contextlib import contextmanager
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import re
import signal
import struct
import subprocess
import sys
import tempfile
import time


STARTUP_SECONDS = 40
STALL_SECONDS = 3
RECOVERY_SECONDS = 3
CAPTURE_SECONDS = 20
SAMPLE_SECONDS = 0.15
BEFORE_SAMPLES = 40
# RK3566 runs AArch64 RetroArch. Its libc implements poll with ppoll.
AARCH64_PPOLL = 73
POLLFD = struct.Struct("=ihh")
FRAME = re.compile(rb"(\d+\.\d+): drm_vblank_event_delivered: file=[^,]+, crtc=(\d+), seq=(\d+)")


def read(path):
    try:
        return path.read_text(errors="replace").strip()
    except OSError:
        return ""


def fields(text):
    values = {}
    for line in text.splitlines():
        key, sep, value = line.partition(":")
        if sep:
            values[key.strip()] = value.strip()
    return values


def audio_state(runtime):
    # Follow the managed route, including USB DAC switches.
    route = read(runtime / "audio/output.status")
    target = re.search(r"^physical_pcm=(?:plug)?hw:(\d+),(\d+)$", route, re.M)
    audio = {"route": route.splitlines(), "streams": []}
    if target:
        card, pcm = target.groups()
        for substream in Path(f"/proc/asound/card{card}/pcm{pcm}p").glob("sub*"):
            status = read(substream / "status")
            audio["streams"].append({
                "device": str(substream),
                "status": fields(status) if ":" in status else status,
                "hw_params": fields(read(substream / "hw_params")),
            })
    return audio


def poll_state(task, proc, memory):
    syscall = read(task / "syscall")
    args = syscall.split()
    if len(args) < 4 or args[0] != str(AARCH64_PPOLL):
        return None
    address, nfds, timeout = (int(arg, 0) for arg in args[1:4])
    count = min(nfds, 32)
    result = {"tid": int(task.name), "comm": read(task / "comm"),
              "syscall": "ppoll", "nfds": nfds, "fds": []}
    try:
        data = os.pread(memory, count * POLLFD.size, address) if count else b""
        if len(data) != count * POLLFD.size:
            result["read_error"] = "short pollfd read"
        else:
            for fd, events, _ in POLLFD.iter_unpack(data):
                try:
                    path = os.readlink(proc / "fd" / str(fd)) if fd >= 0 else None
                except OSError:
                    path = None
                info = fields(read(proc / "fdinfo" / str(fd))) if path is not None else {}
                result["fds"].append({"fd": fd, "events": events & 0xffff, "path": path,
                                      "fdinfo": info})
        if timeout:
            data = os.pread(memory, 16, timeout)
            if len(data) == 16:
                sec, nsec = struct.unpack("=qq", data)
                result["timeout_ms"] = round(sec * 1000 + nsec / 1e6, 3)
        else:
            result["timeout_ms"] = None
    except OSError as error:
        result["read_error"] = str(error)
    # A thread can leave ppoll while the sampler reads its userspace array.
    if read(task / "syscall") != syscall:
        return None
    return result


@contextmanager
def trace_pipe(runtime):
    # Use a private mount and trace instance so other tracing consumers keep
    # their buffers and settings when the recorder exits.
    with tempfile.TemporaryDirectory(prefix="mrboom-trace.", dir=runtime) as temporary:
        mountpoint = Path(temporary)
        instance = mountpoint / "instances" / f"mrboom-{os.getpid()}"
        mounted = False
        pipe = None
        error = None
        try:
            try:
                subprocess.run(
                    ["mount", "-t", "tracefs", "tracefs", temporary],
                    check=True, capture_output=True, text=True,
                )
                mounted = True
                instance.mkdir()
                (instance / "trace_clock").write_text("mono\n")
                (instance / "events/drm/drm_vblank_event_delivered/enable").write_text("1\n")
                pipe = os.open(instance / "trace_pipe", os.O_RDONLY | os.O_NONBLOCK)
            except (OSError, subprocess.CalledProcessError) as exc:
                error = (getattr(exc, "stderr", "") or str(exc)).strip()
            yield pipe, error
        finally:
            if pipe is not None:
                os.close(pipe)
            if mounted:
                if instance.is_dir():
                    instance.rmdir()
                subprocess.run(["umount", temporary], check=True)


def read_frames(pipe, tail):
    if pipe is None:
        return None, b""
    try:
        data = os.read(pipe, 16384)
    except BlockingIOError:
        data = b""
    lines, sep, rest = (tail + data).rpartition(b"\n")
    matches = FRAME.findall(lines)
    if not matches:
        return {"events": 0}, rest if sep else tail + data
    stamp, crtc, seq = matches[-1]
    return {"events": len(matches), "last_event_s": float(stamp),
            "crtc": int(crtc), "sequence": int(seq)}, rest


def append(report, record):
    report.write(json.dumps(record, ensure_ascii=True) + "\n")
    report.flush()


def publish(report, report_path):
    os.fsync(report.fileno())
    os.replace(report.name, report_path)
    directory = os.open(report_path.parent, os.O_RDONLY | os.O_DIRECTORY)
    try:
        os.fsync(directory)
    finally:
        os.close(directory)


def monitor(pid, proc, memory, runtime, report_path, boot_id):
    history = deque(maxlen=BEFORE_SAMPLES)
    report = None
    with trace_pipe(runtime) as (pipe, trace_error):
        start = time.monotonic()
        deadline = start + STARTUP_SECONDS
        last_frame = start
        main_poll_since = start
        last_poll = None
        recovered = None
        tail = b""
        end_reason = "recorder_interrupted"
        try:
            while time.monotonic() < deadline:
                now = time.monotonic()
                # The directory fd pins this /proc entry through PID reuse.
                if not read(proc / "stat"):
                    end_reason = "process_exited"
                    break
                display, tail = read_frames(pipe, tail)
                if display and display["events"]:
                    last_frame = display["last_event_s"]
                main = poll_state(proc / "task" / str(pid), proc, memory)
                signature = None
                if main is not None:
                    signature = main["nfds"], [(fd["fd"], fd["events"], fd["path"]) for fd in main["fds"]]
                if signature != last_poll:
                    main_poll_since = now
                    last_poll = signature
                sample = {
                    "type": "sample", "monotonic_s": round(now, 6),
                    "audio": audio_state(runtime),
                    "drm": display,
                    "seconds_since_flip": round(max(0, now - last_frame), 3) if pipe is not None else None,
                    "main_poll": main,
                }
                stalled = (
                    now - last_frame >= STALL_SECONDS if pipe is not None
                    else main is not None and now - main_poll_since >= STALL_SECONDS
                )
                if report is None and stalled:
                    report = tempfile.NamedTemporaryFile(
                        mode="w", encoding="utf-8", dir=report_path.parent,
                        prefix=".mrboom-startup.", delete=False,
                    )
                    append(report, {"type": "header", "pid": pid, "boot_id": boot_id,
                                    "recorded_utc": datetime.now(timezone.utc).isoformat(),
                                    "monitor_start_s": start, "drm_trace_error": trace_error})
                    for previous in history:
                        append(report, previous)
                    append(report, {"type": "stall", "monotonic_s": now,
                                    "reason": "no_pageflip" if pipe is not None else "main_poll_without_drm_trace"})
                    publish(report, report_path)
                    deadline = now + CAPTURE_SECONDS
                if report is not None:
                    sample["other_polls"] = [
                        wait for task in (proc / "task").glob("[0-9]*")
                        if task.name != str(pid)
                        and (wait := poll_state(task, proc, memory)) is not None
                    ]
                    append(report, sample)
                    progress = (display["events"] > 0) if display is not None else main is None
                    if progress and recovered is None:
                        recovered = now
                        append(report, {"type": "progress", "monotonic_s": now,
                                        "source": "pageflip" if display is not None else "main_left_poll"})
                    if recovered is not None and now - recovered >= RECOVERY_SECONDS:
                        end_reason = "recovery_samples_complete"
                        break
                history.append(sample)
                time.sleep(SAMPLE_SECONDS)
            else:
                end_reason = "capture_window_ended"
        finally:
            if report is not None:
                with report:
                    append(report, {"type": "end", "monotonic_s": time.monotonic(), "reason": end_reason})
                    os.fsync(report.fileno())
                    Path(report.name).unlink(missing_ok=True)


def main():
    pid = int(sys.argv[1])
    runtime = Path(os.environ["PLUMOS_RUNTIME_ROOT"])
    report_path = Path(os.environ["PLUMOS_ROOT"]) / "logs/mrboom-startup-stall.jsonl"
    try:
        directory = os.open(f"/proc/{pid}", os.O_RDONLY | os.O_DIRECTORY)
    except FileNotFoundError:
        return
    try:
        proc = Path(f"/proc/self/fd/{directory}")
        # Wait for the launcher child to exec the game before opening its mm.
        for _ in range(40):
            comm = read(proc / "comm")
            if not comm:
                return
            if comm == "retroarch":
                break
            time.sleep(0.025)
        else:
            return
        fd = os.open(proc / "mem", os.O_RDONLY)
        try:
            monitor(pid, proc, fd, runtime, report_path, read(Path("/proc/sys/kernel/random/boot_id")))
        finally:
            os.close(fd)
    finally:
        os.close(directory)


def stop(_signal, _frame):
    raise SystemExit(0)


if __name__ == "__main__":
    for handled_signal in (signal.SIGHUP, signal.SIGINT, signal.SIGTERM):
        signal.signal(handled_signal, stop)
    main()
