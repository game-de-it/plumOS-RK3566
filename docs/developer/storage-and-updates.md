# Trial SYSTEM and recovery

[日本語](storage-and-updates.ja.md) · [Guide index](README.md)

## Stage and boot the trial

Use this path to test a replacement userspace on an existing compatible SD. Work from a stopped game, use a single ADB target or select its serial, and check available space on `/storage` before staging the SquashFS.

```sh
system_file=output/release-work/system/SYSTEM
state=/storage/plumos-rk3566/system
boot_ctl="$state/boot-system"
digest=$(shasum -a 256 "$system_file" | awk '{print $1}')

adb devices -l
adb shell "$boot_ctl status; df -h /storage"
adb shell "test ! -e $state/SYSTEM.partial" &&
  adb push "$system_file" "$state/SYSTEM.partial" &&
  adb shell "$boot_ctl publish $digest && $boot_ctl trial $digest && $boot_ctl reboot"
```

## Verify and keep the trial

After reboot, check the active digest, frontend readiness and relevant hardware. Run `keep` only after those checks succeed. A trial is consumed once; a following boot falls back to the previous default or the factory SYSTEM unless the trial is kept.

```sh
adb shell 'cat /dev/plumos-system-active /tmp/plumos-fe-ready'
adb shell 'grep -E " /storage/user | /run/media/sd2 " /proc/mounts'
adb shell "$boot_ctl status"
adb shell "$boot_ctl keep"
```

## Recovery

With ADB access, `boot-system factory` clears the trial and default selections so that the next boot uses `/flash/SYSTEM`. Keep a known bootable card or card backup for recovery. A shipped runtime update is a separate path through `System Update` and requires a matching signed package. [Boot selection implementation](../../prototype/boot-system/mount-storage.sh) · [Runtime update and rollback notes](../rk3566-runtime.md)
