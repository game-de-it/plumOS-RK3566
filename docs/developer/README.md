# plumOS-RK3566 developer guide

[日本語](README.ja.md) · [Documentation index](../README.md) · [User manual](../user/README.md)

## System layout

The common image inherits the JELOS 20240206 RK3566 boot chain. The patched U-Boot FIT selects the RGB30 r1/r2 device tree by CPU regulator and handles RG353V power-on with USB attached. Linux 4.19.172 and the extlinux/initramfs handoff are retained. The handoff enters plumOS init and starts the Bubble frontend and hardware services from the newly assembled SYSTEM. [Boot chain and board support](../boot-and-device-support.md) · [JELOS source revisions](../jelos-20240206-source.md)

| Area | Role |
| --- | --- |
| TF1 p1 and p2 | U-Boot FIT and board-selection resources |
| TF1 p3, `/flash` | Boot files and the factory `SYSTEM` |
| TF1 p4, `/storage` | ext4 for the writable runtime, settings, saves, logs and trial SYSTEMs |
| TF1 p5, `/storage/user` | FAT32 `PLUMOS` volume created during first boot |
| TF2, `/run/media/sd2` | Optional ROM and BIOS media. The current DTB's `mmc2` alias identifies the controller. |
| `/usr/lib/plumos-353m/frontend` | Factory runtime in SYSTEM, used as the read-only lower layer |
| `/storage/plumos-rk3566/frontend` | Runtime view with a persistent writable upper layer |

`plumos-353m` in internal paths is retained for compatibility. Use `/proc/device-tree/model` to identify the active board. The initramfs entry `/usr/lib/systemd/systemd` is a symlink to plumOS init. Verify `/dev/plumos-native-init` or `/proc/1/exe` when checking which init is running. [Runtime and storage notes](../rk3566-runtime.md)

## Build and make changes

- The emulator build applies the RK3566 patch set to pinned Bubble and V90S inputs. The SYSTEM build assembles the frontend, emulators, Apps, hardware services, and ARM64 userspace. The image build installs that SYSTEM and the board-specific boot assets in the bootable seed. [Docker build instructions](build.md)
- Make catalog or launcher changes in the normal build pipeline and test launch through the frontend. Keep the frontend and emulator DRM lifetime coordinated. Firmware, launchers, component manifests and checksums should describe the same packaged files. [Runtime verifier](../../prototype/emulators/verify-release-runtime.py)
- The common RetroArch patch handles SELECT + B before the gameplay input mask and reads the built-in FN event separately. PicoArch and standalone emulators use SELECT + START on RGB30 and RK2023. Verify both RetroArch press orders and the usual controls after touching input handling. [RetroArch patch](../../prototype/emulators/retroarch-select-b-menu.patch) · [Standalone menu configuration](../../prototype/emulators/configure-standalone-menu-chords.py)

## Trial SYSTEM and recovery

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

After reboot, check the active digest, frontend readiness and relevant hardware. Run `keep` only after those checks succeed. A trial is consumed once; a following boot falls back to the previous default or the factory SYSTEM unless the trial is kept.

```sh
adb shell 'cat /dev/plumos-system-active /tmp/plumos-fe-ready'
adb shell 'grep -E " /storage/user | /run/media/sd2 " /proc/mounts'
adb shell "$boot_ctl status"
adb shell "$boot_ctl keep"
```

With ADB access, `boot-system factory` clears the trial and default selections so that the next boot uses `/flash/SYSTEM`. Keep a known bootable card or card backup for recovery. A shipped runtime update is a separate path through `System Update` and requires a matching signed package. [Boot selection implementation](../../prototype/boot-system/mount-storage.sh) · [Runtime update and rollback notes](../rk3566-runtime.md)

## Device validation

These records cover multiple development builds. A hardware result applies to the image or SYSTEM recorded in that test. Use the listed results as regression coverage when checking the exact release candidate.

| Device | Evidence |
| --- | --- |
| RG353M | [Emulator matrix](../validation/2026-11-22-rg353m-emulator-matrix.md) · [Wi-Fi startup](../validation/rg353m-wifi-boot.md) · [Sleep and resume](../validation/2026-11-23-rg353m-sleep-matrix.md) |
| RG353V | [Runtime, menus, apps and power](../validation/2026-11-25-rg353v-runtime.md) · [USB-powered cold boot](../validation/2026-11-25-rg353v-usb-cold-boot.md) |
| RG503 | [Runtime and USB ADB retest](../validation/2026-11-25-rg503-runtime.md) · [SD2](../validation/2026-11-25-rg503-sd2.md) |
| RGB30 r1 / r2 | [Common image on both revisions](../validation/2026-11-25-rgb30-unified-image.md) · [Runtime on r2](../validation/2026-11-24-rgb30-emulators.md) |
| RK2023 | [First boot and USB enumeration](../validation/2026-11-25-rk2023-boot.md) · [Runtime, audio and menus](../validation/2026-11-25-rk2023-runtime.md) |

## Release verification

Record the source commit, version, artifact hashes and exact test hardware. Write the candidate to a fresh card and validate first-boot provisioning, cold boot, reboot, shutdown, SD2, representative emulators and app menus, audio, and sleep/resume. Check Wi-Fi and USB ADB where available, screen layout on each panel geometry, and rollback for any update package included with the release. Distinguish a successful launch from compatibility throughout an entire game.

Keep the final artifact inventory and the source and license notices for shipped components. Inspect the staged artifacts for personal ROMs, BIOS files, saves, test scripts, Wi-Fi profiles, host keys and signing material. The runtime verifier checks route and component coverage; review redistribution terms and validate the final image separately. [Image validation commands](build.md#verify-and-package)
