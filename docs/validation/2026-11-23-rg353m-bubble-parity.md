# RG353M: Bubble runtime parity follow-up (2026-11-23)

## Scope and source

The tested SYSTEM is built from the pinned Bubble source
`ec81d42c0c2c39e7a32973bfe4df9b3027512a5d` with the preserved JELOS
boot path, kernel, DTB, and SD partition table. Source and build changes are in
`prototype/boot-system/init`, `prototype/build-bubble-system.sh`,
`prototype/stage-bubble-apps.sh`, and `prototype/system/usr/lib/plumos-353m/`.
The resulting SYSTEM SHA-256 is
`0af37e52703c7876e5a1ec57d44f926117c0db52a693ef861bfda2e26b497000`.
It was published as a trial over ADB, without rewriting the SD image. The
known-good default remains
`36986639c5ff450e909ad590143d9e25c55bbbd6660fa1095e5d2abdedc1339a`.

## Implemented

- PID 1 now stops the foreground process group and storage users, unmounts
  SD2, remounts p5 and p4 read-only, and commits clean-shutdown markers before
  a requested reboot or shutdown. It cancels the request on an unmount or
  remount failure.
- The audio route watcher is restarted if it exits.
- Bubble's power-key listener, power overlay, quiesce helper, DRM broker,
  shared DRM library, and DRM master helper are included. FE owns the power
  menu while it owns the display; during a game, the overlay quiesces the
  display owner and uses the DRM handoff.
- The FE checks required runtime files before starting. A failed FE or missing
  user storage retains ADB and attempts saved Wi-Fi settings; PID 1 records a
  recovery snapshot. A trial SYSTEM is marked healthy only when the FE is
  actually ready.

## Tests on the RG353M

- Docker build completed and `SYSTEM` passed SHA-256 verification on the SD.
  The generated SYSTEM contains the DRM helpers, shared library, overlay, and
  quiesce helper. The installed PID 1 script matches the source hash.
- Trial boot reached Bubble: FE PID 347, volume/power listener PID 713, and
  audio route watcher PID 345. `boot-system status` reported the new hash as
  both active and healthy. ADB was attached; Wi-Fi acquired
  `192.168.10.159`; p5 and SD2 were mounted read-write.
- Killing watcher PID 345 resulted in a new watcher PID 2080, with
  `audio route monitor exited; restarting` in `init.log`.
- Safe power helper dry runs reported `action=sleep backend=mem` and
  `action=reboot`; the DRM helpers were executable from the mounted frontend.
- An 8-second RTC wakealarm test with `--sleep --wakeup-sec 8` suspended the
  device and disconnected ADB. Automatic wake did not occur; USB ADB and Wi-Fi
  were still absent after the interval. A short physical power-key press did
  not wake the display either. After a long-press power cycle, Bubble and ADB returned. `boot-system status`
  showed that the boot selector had fallen back to the unchanged known-good
  default. Sleep remains under investigation; the test was performed while
  USB ADB supplied power. The in-game power overlay remains to be confirmed.

## Sleep investigation under USB power

Bubble defaults to `mem` for non-MF devices. Its RG35XX-family validation
records `deep` as the selected `mem_sleep` mode. Its Wi-Fi suspend fix
(`37520b4`) bounds termination of `wpa_supplicant` and DHCP before entering
sleep. RK2020 unloads and reloads its USB controller around suspend, while
V90S V2 restarts FunctionFS ADB after resume because a live `adbd` process
can retain an unusable USB transport. These are device-specific recovery
paths; they do not establish that `deep` works on RG353M.

The RG353M reported `ac/online=1`, `usb/online=0`, and a full battery while
its ADB cable was connected. The kernel offers `freeze mem` and selects
`deep` for `mem`. The staged `pm_test=devices`, `platform`, `processors`, and
`core` checks reached the power-management code and returned (success count
4, failure count 0). One processors-stage trace mentioned `Disabling
non-boot cpus failed`; repeated staged tests also caused an SDIO Wi-Fi
timeout. Therefore the other plumOS device's charging-state veto does not
explain the RG353M behavior.

With the same cable connected, a bounded diagnostic `freeze` run (`--wakeup-sec 8`)
entered `s2idle`, incremented the RTC alarm IRQ, and resumed. A second
`freeze` run with a 60-second backup alarm resumed from a short physical
power-key press before the alarm fired; the user confirmed that Bubble's
screen returned. The power-key IRQ incremented, and the frontend process
remained alive. The diagnostic run manually restarted the ADB monitor after
resume; ADB and saved Wi-Fi then returned. This only establishes that the
shallower suspend state can resume. The user requested investigation of the
failed `mem` path before any fallback is considered. The `freeze` SYSTEM was
built locally but was not published or deployed, and was then deleted.

JELOS 20240206 has an RG353M-specific `030-suspend_mode` quirk. It selects
`mem` as the systemd suspend state and then writes `s2idle` to
`/sys/power/mem_sleep`. The preserved vendor DT marks the `rockchip-suspend`
node disabled; the PMIC and power key have wakeup capability, and its GPIO
power key alternative is commented out. The live plumOS node is also disabled.
The direct `mem` failure occurred with the kernel's default `s2idle [deep]`
selection because the JELOS boot-time quirk had not been carried over.

On the current known-good plumOS SYSTEM, a live diagnostic wrote `s2idle`
to `mem_sleep` and invoked `--sleep --sleep-backend mem --wakeup-sec 8` with
the ADB cable still supplying power (`ac/online=1`). The kernel logged
`PM: suspend entry (s2idle)`, the RTC IRQ count went from 1 to 2, and the
command returned 0 after eight seconds. The frontend remained running; the
diagnostic restarted the ADB gadget monitor, and USB ADB returned. This
reproduces JELOS's `mem` mode without changing the kernel or DTB. The
production code now selects `mem_sleep=s2idle` at init, refuses accidental
`mem+deep`, and requests PID 1 to restart ADB after resume.

Docker produced trial SYSTEM
`7d525fc05bd910db1dacd48bc7e34b0d7908a6529a3d6b7710f0a563e7c10440`.
The embedded init and safe power script matched their source SHA-256 values.
It was published and trial-booted through ADB without rewriting the SD; the
known-good default stayed `36986639c5ff450e909ad590143d9e25c55bbbd6660fa1095e5d2abdedc1339a`.
At boot, `mem_sleep` read `[s2idle] deep lite ultra`, Bubble and ADB ran, and
`boot-system` recorded the trial as healthy. With USB power still present,
the production safe power script entered `mem` with an 8-second RTC alarm.
The log records `sleep=enter backend=mem` at 12:54:13 UTC and resume at
12:54:21 UTC; the kernel recorded `PM: suspend entry (s2idle)` and exit.
The boot ID and Bubble PID 348 did not change. PID 1 restarted the ADB
monitor (PID 202 to 2514), ADB reappeared without manual recovery, and Wi-Fi
reacquired `192.168.10.159`. Normal power-menu and physical power-key
acceptance remain to be recorded.

The JELOS source is
[`Anbernic RG353M/030-suspend_mode`](https://github.com/JustEnoughLinuxOS/distribution/blob/f8cac7b92040d734506e238f5a44560a4f0e81b0/packages/hardware/quirks/devices/Anbernic%20RG353M/030-suspend_mode),
with the state selection in
[`suspendmode`](https://github.com/JustEnoughLinuxOS/distribution/blob/f8cac7b92040d734506e238f5a44560a4f0e81b0/packages/jelos/sources/scripts/suspendmode).

Sources: [Bubble sleep path](https://github.com/game-de-it/plumOS-Bubble/commit/37520b4372af9d6968648f9e25c650a20d9c624d),
[RK2020 stock suspend validation](https://github.com/game-de-it/plumOS-RK2020/blob/846c462f42c229baa73b1c93ab639293a511e99b/docs/validation/2026-10-26-rk2020-stock-suspend-path.md),
[V90S V2 ADB resume fix](https://github.com/game-de-it/plumOS-V90S_V2/commit/519b3b7c49bda6fe65d8ede46c6394a811edc85a),
[mini PLUS charging-state fix](https://github.com/game-de-it/plumOS-mini-PLUS/commit/3a2ddb37d99c29860d25713e48136d4b17c777d9).

## Storage housekeeping

Four obsolete trial SYSTEM files were removed from p4 after confirming that
none was active, default, pending, or healthy. The current default and the
previous recovery SYSTEM were retained. p4 free space rose from 303 MiB to
2.6 GiB. The temporary Docker build directory and duplicate userland image
were removed from the Mac after generating and verifying SYSTEM.
