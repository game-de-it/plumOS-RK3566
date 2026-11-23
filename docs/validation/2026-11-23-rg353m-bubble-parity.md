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
  were still absent after the interval. Physical power-key wake and the
  in-game power overlay remain to be confirmed. Do not treat timed RTC wake as
  working on this hardware.

## Storage housekeeping

Four obsolete trial SYSTEM files were removed from p4 after confirming that
none was active, default, pending, or healthy. The current default and the
previous recovery SYSTEM were retained. p4 free space rose from 303 MiB to
2.6 GiB. The temporary Docker build directory and duplicate userland image
were removed from the Mac after generating and verifying SYSTEM.
