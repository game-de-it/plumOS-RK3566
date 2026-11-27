# RG353M: plumOS-Bubble runtime parity follow-up (2026-11-23)

## Scope and source

The tested SYSTEM is built from the pinned plumOS-Bubble source
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
- plumOS-Bubble's power-key listener, power overlay, quiesce helper, DRM broker,
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
- Trial boot started the frontend (PID 347), volume/power listener (PID 713),
  and audio route watcher (PID 345). `boot-system status` reported the new hash as
  both active and healthy. ADB was attached; Wi-Fi acquired
  `192.168.10.159`; p5 and SD2 were mounted read-write.
- Killing watcher PID 345 resulted in a new watcher PID 2080, with
  `audio route monitor exited; restarting` in `init.log`.
- Safe power helper dry runs reported `action=sleep backend=mem` and
  `action=reboot`; the DRM helpers were executable from the mounted frontend.
- An 8-second RTC wakealarm test with `--sleep --wakeup-sec 8` suspended the
  device and disconnected ADB. Automatic wake did not occur; USB ADB and Wi-Fi
  were still absent after the interval. A short physical power-key press did
  not wake the display either. After a long-press power cycle, the frontend and ADB returned. `boot-system status`
  showed that the boot selector had fallen back to the unchanged known-good
  default. Sleep remains under investigation; the test was performed while
  USB ADB supplied power. The in-game power overlay remains to be confirmed.

## Sleep investigation under USB power

plumOS-Bubble defaults to `mem` for non-MF devices. Its RG35XX-family validation
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
power-key press before the alarm fired; the user confirmed that the
frontend screen returned. The power-key IRQ incremented, and the frontend process
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
At boot, `mem_sleep` read `[s2idle] deep lite ultra`, the frontend and ADB ran, and
`boot-system` recorded the trial as healthy. With USB power still present,
the production safe power script entered `mem` with an 8-second RTC alarm.
The log records `sleep=enter backend=mem` at 12:54:13 UTC and resume at
12:54:21 UTC; the kernel recorded `PM: suspend entry (s2idle)` and exit.
The boot ID and the frontend PID 348 did not change. PID 1 restarted the ADB
monitor (PID 202 to 2514), ADB reappeared without manual recovery, and Wi-Fi
reacquired `192.168.10.159`.

The user then chose Sleep through the frontend’s START menu and woke the RG353M
with one short physical power-key press. The user confirmed that display and
controls returned. The production log shows `backend=mem`, `ac=1`, and
`mem_sleep=[s2idle]` at 12:57:08 UTC, with resume at 12:57:11 UTC. The
kernel again recorded `PM: suspend entry (s2idle)` and exit. The boot ID and
the frontend PID 348 stayed unchanged; PID 1 restarted the ADB monitor, USB ADB
reappeared, and Wi-Fi again held `192.168.10.159`.

## In-game power-menu handoff

An NES game launched through PicoArch could not show the power menu. The
overlay log recorded `fbdev renderer init failed: mmap framebuffer: Invalid
argument`. The RG353M overlay script had copied plumOS-Bubble's DRM master handoff
but invoked the menu without `PLUMOS_DRM_DEVICE`, so the renderer attempted
to map `/dev/fb0` while the game used KMS. plumOS-Bubble's history introduced an
SCM_RIGHTS DRM broker and a DRM-backed power overlay (`4005c3f`), then hid
foreground KMS planes under the menu (`f682c81`). Both features were already
present in the pinned plumOS-Bubble frontend; the missing RG353M environment
variable prevented their use.

The overlay now passes `/dev/dri/card0`, the RG353M DRM flag, and plumOS-Bubble's
frontend library path. The script was copied over ADB to the existing SD,
with the previous version backed up in the logs directory. In the same
PicoArch process, the repaired menu opened `/dev/dri/card0` and held the
emulator after dropping its DRM master. The user saw the menu, selected
Sleep, short-pressed Power, and confirmed that game display, controls, and
audio returned. The kernel recorded `mem` entering and leaving `s2idle`;
the boot ID and PicoArch PID 14689 did not change. The emulator's ALSA PCM
was `RUNNING` afterward, ADB was automatically rebound, and Wi-Fi stayed
connected.

Docker generated the final SYSTEM
`4904ef22573ac247ca45b192a839c3c8ed89892b88c635ce8606a28b1e2ad240`.
Its embedded init, safe power script, and overlay script matched source
hashes. It was published and trial-booted over ADB, without SD rewrite.
The device selected `[s2idle] deep lite ultra`, launched the frontend, attached
ADB, reacquired Wi-Fi, and marked the candidate healthy. A production
`mem`/RTC test on this exact SYSTEM entered `s2idle` at 13:09:08 UTC and
resumed at 13:09:16 UTC under `ac/online=1`; the boot ID and the frontend PID 350
were unchanged, PID 1 rebound ADB, and Wi-Fi retained `192.168.10.159`.
The final SYSTEM was then set as the boot default with `boot-system keep`;
`active`, `default`, and `healthy` all matched its hash. The previous
working `mem` SYSTEM remains on the SD as a recovery candidate.

plumOS-Bubble history: [DRM master handoff](https://github.com/game-de-it/plumOS-Bubble/commit/4005c3f56994f9cf7279800038283c81dab27903),
[foreground plane handling](https://github.com/game-de-it/plumOS-Bubble/commit/f682c814374010d9c13eea487685c98b29113a9b).

### Input and display after game resume

The user reported that the D-pad and A/B did not respond after resume. At
the time, PicoArch was running NES/FCEUmm. The kernel exposed the built-in
`retrogame_joypad` at `/dev/input/event5`, with no `/dev/input/event2`. The
PicoArch startup log and file descriptors showed that its evdev probe had
stopped at the first missing number before opening the joypad. The patch
scans the input nodes that exist, in numeric order, and skips nodes that
disappear before they can be opened. With the patch installed over ADB,
PicoArch opened `event5` and the user confirmed D-pad and A/B operation
before and after Sleep. PicoArch PID 23983 and its ALSA playback survived
the test.

RetroArch/QuickNES had a separate display failure. The overlay hid the
game plane but could not restore it by using the LCD dimensions in place
of the game's actual 627×480 source and destination rectangles. Enabling
the DRM atomic client capability exposed the plane geometry. Restoring it
fixed the immediate handoff, but a complete Sleep cycle still lost the game
plane when the kernel restored the display. The power menu now keeps its
renderer open during Sleep. It restores the saved plane after the kernel
resumes, then releases DRM and continues the game process.

With ADB supplying power (`ac/online=1`), the repaired RetroArch route
entered `mem` through the in-game menu and woke by RTC. The log showed
successful plane restore after resume. RetroArch PID 7108 kept `event5`
open and the game plane continued rotating through framebuffer IDs 137,
139 and 141 at the original position. Injected FN opened RGUI and two
successive SELECT+START presses closed RetroArch cleanly and returned to
the frontend. The existing `quit_press_twice=true` setting requires both presses.

The final inline Sleep path also passed an RTC run on PicoArch PID 11215.
It retained the joypad descriptor, resumed PCM playback, and accepted an
injected FN/menu Exit sequence after wake. The final Docker SYSTEM
`fc01b5ed99c5745be0ee701e1f4ceed7e1c5c52e477e34d382187d61a1daba02`
contains the same two binaries and overlay script tested live. It was
verified against the source artifacts and trial-booted over ADB. The frontend,
Wi-Fi, and ADB came up, and `boot-system keep` set the verified SYSTEM as
the default. The trial did not require rewriting the SD image.

The JELOS source is
[`Anbernic RG353M/030-suspend_mode`](https://github.com/JustEnoughLinuxOS/distribution/blob/f8cac7b92040d734506e238f5a44560a4f0e81b0/packages/hardware/quirks/devices/Anbernic%20RG353M/030-suspend_mode),
with the state selection in
[`suspendmode`](https://github.com/JustEnoughLinuxOS/distribution/blob/f8cac7b92040d734506e238f5a44560a4f0e81b0/packages/jelos/sources/scripts/suspendmode).

Sources: [plumOS-Bubble sleep path](https://github.com/game-de-it/plumOS-Bubble/commit/37520b4372af9d6968648f9e25c650a20d9c624d),
[RK2020 stock suspend validation](https://github.com/game-de-it/plumOS-RK2020/blob/846c462f42c229baa73b1c93ab639293a511e99b/docs/validation/2026-10-26-rk2020-stock-suspend-path.md),
[V90S V2 ADB resume fix](https://github.com/game-de-it/plumOS-V90S_V2/commit/519b3b7c49bda6fe65d8ede46c6394a811edc85a),
[mini PLUS charging-state fix](https://github.com/game-de-it/plumOS-mini-PLUS/commit/3a2ddb37d99c29860d25713e48136d4b17c777d9).

## Storage housekeeping

Four obsolete trial SYSTEM files were removed from p4 after confirming that
none was active, default, pending, or healthy. The current default and the
previous recovery SYSTEM were retained. p4 free space rose from 303 MiB to
2.6 GiB. The temporary Docker build directory and duplicate userland image
were removed from the Mac after generating and verifying SYSTEM.
