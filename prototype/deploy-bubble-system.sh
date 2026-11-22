#!/bin/bash
set -euo pipefail

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 root@RG353M_IP BUBBLE_USERLAND_SQUASHFS" >&2
    exit 2
fi

device=$1
artifact=$2
ssh_options=()
if [ -n "${PLUMOS_SSH_SOCKET:-}" ]; then ssh_options=(-S "$PLUMOS_SSH_SOCKET"); fi
remote() { ssh "${ssh_options[@]}" "$device" "$@"; }

revision=$(shasum -a 256 "$artifact" | cut -d ' ' -f 1)
dest=/storage/plumos-rk3566
incoming="$dest/$revision.partial"
remote 'test "$(tr -d "\000" </proc/device-tree/model)" = "Anbernic RG353M" &&
    grep -q "boot=UUID=2211-3302" /proc/cmdline &&
    test "$(sha256sum /flash/SYSTEM | cut -d " " -f 1)" = b0028dc48926ad49ab2d0156fec2c64f16f406e2f463ded4cc84eb8dcaac4a83 &&
    mkdir -p /storage/plumos-rk3566'
remote "cat > '$incoming'" < "$artifact"
remote "sh -s -- '$revision'" <<'REMOTE'
set -eu
revision=$1
dest=/storage/plumos-rk3566
units=/storage/.config/system.d
payload=/run/plumos/bubble/usr/lib/plumos-353m
image="$dest/$revision.squashfs"
mount_unit=run-plumos-bubble.mount
adb_unit=plumos-rk3566-adb.service
dropin="$units/emustation.service.d/90-plumos-rk3566.conf"
enabled="$units/jelos.target.wants/$adb_unit"
printf '%s  %s\n' "$revision" "$dest/$revision.partial" | sha256sum -c
mv "$dest/$revision.partial" "$image"
for entry in "$units/$mount_unit" "$units/$adb_unit" "$dropin" "$enabled"; do
    test ! -e "$entry" && test ! -L "$entry"
done

rollback() {
    set +e
    systemctl stop emustation.service "$adb_unit" "$mount_unit"
    rm -f "$units/$mount_unit" "$units/$adb_unit" "$dropin" "$enabled"
    systemctl daemon-reload
    systemctl start emustation.service
}
trap 'rollback' EXIT
trap 'exit 1' INT TERM
mkdir -p "$units/emustation.service.d" "$units/jelos.target.wants"
cat > "$units/$mount_unit" <<UNIT
[Unit]
Description=plumOS Bubble userland
RequiresMountsFor=$dest

[Mount]
What=$image
Where=/run/plumos/bubble
Type=squashfs
Options=loop,ro
UNIT
cat > "$units/$adb_unit" <<UNIT
[Unit]
Description=plumOS USB ADB on RG353M
After=systemd-udev-trigger.service $mount_unit
Requires=$mount_unit

[Service]
Environment=PLUMOS_PAYLOAD=$payload
ExecStart=$payload/start-adb
KillMode=mixed
Restart=on-failure
RestartSec=4
UNIT
cat > "$dropin" <<UNIT
[Unit]
Requires=$mount_unit
After=$mount_unit

[Service]
Environment=PLUMOS_PAYLOAD=$payload
Environment=PLUMOS_ROOT=/storage/plumos-rk3566/frontend
ExecStartPre=
ExecStart=
ExecStart=$payload/start-frontend
ExecStopPost=/usr/bin/rm -f /tmp/plumos-fe-ready
KillMode=control-group
Restart=on-failure
RestartSec=3
UNIT
ln -s "../$adb_unit" "$enabled"
systemctl daemon-reload
systemctl start "$mount_unit" "$adb_unit"
systemctl stop emustation.service
systemctl start emustation.service
for second in $(seq 1 30); do
    if test -f /tmp/plumos-fe-ready && systemctl is-active --quiet emustation.service &&
        [ "$(cat /sys/kernel/config/usb_gadget/plumos353m/UDC)" = fcc00000.dwc3 ]; then
        trap - EXIT INT TERM
        sync
        exit 0
    fi
    sleep 1
done
journalctl -b -u emustation.service -u "$adb_unit" -n 50 --no-pager
exit 1
REMOTE
