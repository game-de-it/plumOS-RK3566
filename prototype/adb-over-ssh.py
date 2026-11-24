#!/usr/bin/env python3
"""Carry ADB over an existing authenticated SSH connection to plumOS."""

import argparse
import asyncio
from contextlib import suppress
from pathlib import Path
import shlex
import sys


START_ADBD = r'''
set -eu
cd /
mount --make-rprivate /
mount -t tmpfs -o mode=0700,size=1m tmpfs /dev/usb-ffs
# Drop the cloned storage mounts so a debug session cannot keep them busy.
umount -l /run/media/sd2 2>/dev/null || :
umount -l /storage 2>/dev/null || :
ip link set lo up
printf '0\n' > /proc/sys/net/ipv6/conf/lo/disable_ipv6
export ADBD_PORT=5555 ADB_TCP_PORT=5555 ADBD_SHELL=/bin/sh
/usr/lib/plumos-353m/adbd </dev/null >&2 &
daemon=$!
trap 'kill "$daemon" 2>/dev/null || :' EXIT
trap 'exit 1' HUP INT TERM
for attempt in 1 2 3 4 5; do
    if grep -q ':15B3 .* 0A ' /proc/net/tcp6; then
        busybox nc 127.0.0.1 5555
        exit
    fi
    kill -0 "$daemon"
    sleep 1
done
exit 1
'''

LOAD_IPV6 = r'''
set -eu
module=$(mktemp /run/plumos-adb-ipv6.XXXXXX)
trap 'rm -f "$module"' EXIT
cat > "$module"
[ -d /sys/module/ipv6 ] || insmod "$module" disable_ipv6=1 autoconf=0
'''


async def copy(reader, writer):
    while buffer := await reader.read(65536):
        writer.write(buffer)
        await writer.drain()


async def forward(ssh, reader, writer):
    process = await asyncio.create_subprocess_exec(
        *ssh, f"exec busybox unshare -m -n /bin/sh -c {shlex.quote(START_ADBD)}",
        stdin=asyncio.subprocess.PIPE, stdout=asyncio.subprocess.PIPE,
    )
    transfers = [
        asyncio.create_task(copy(reader, process.stdin)),
        asyncio.create_task(copy(process.stdout, writer)),
    ]
    try:
        await asyncio.wait(transfers, return_when=asyncio.FIRST_COMPLETED)
    finally:
        for transfer in transfers:
            transfer.cancel()
        await asyncio.gather(*transfers, return_exceptions=True)
        process.stdin.close()
        writer.close()
        with suppress(ProcessLookupError):
            process.terminate()
        await process.wait()


async def ensure_ipv6(ssh, module):
    check = await asyncio.create_subprocess_exec(*ssh, "test -d /sys/module/ipv6")
    status = await check.wait()
    if status == 0:
        return True
    if status != 1:
        return False
    if module is None:
        print("ADB requires IPv6. Supply --ipv6-module for this kernel.", file=sys.stderr)
        return False
    load = await asyncio.create_subprocess_exec(
        *ssh, LOAD_IPV6, stdin=asyncio.subprocess.PIPE,
    )
    await load.communicate(module)
    return load.returncode == 0


async def serve(ssh, port, module):
    module_lock = asyncio.Lock()

    async def connect(reader, writer):
        # A device reboot unloads the module while the host listener survives.
        async with module_lock:
            ready = await ensure_ipv6(ssh, module)
        if ready:
            await forward(ssh, reader, writer)
        else:
            writer.close()
            await writer.wait_closed()

    async with await asyncio.start_server(connect, "127.0.0.1", port) as server:
        print(f"ADB listener on 127.0.0.1:{port}", flush=True)
        await server.serve_forever()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("target", help="OpenSSH host alias or root@address")
    parser.add_argument("--identity", type=Path, help="existing SSH private key")
    parser.add_argument("--port", type=int, default=15555)
    parser.add_argument("--ipv6-module", type=Path, help="optional ipv6.ko from this device's kernel")
    args = parser.parse_args()
    if not 1 <= args.port <= 65535:
        parser.error("--port must be between 1 and 65535")
    ssh = ["ssh", "-T", "-o", "BatchMode=yes", "-o", "ConnectTimeout=5"]
    if args.identity is not None:
        ssh.extend(["-o", "IdentitiesOnly=yes", "-i", str(args.identity)])
    ssh.extend(["--", args.target])
    module = args.ipv6_module.read_bytes() if args.ipv6_module else None
    try:
        asyncio.run(serve(ssh, args.port, module))
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
