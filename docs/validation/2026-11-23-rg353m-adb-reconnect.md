# RG353M USB ADB reconnect recovery (2026-11-23)

## Failure and fix

After an ADB cable disconnect and reconnect, the USB gadget could return to
`configured` while `adbd` remained alive with its old FunctionFS endpoints.
The Mac enumerated the USB device and sent an ADB `CNXN`, but received no reply.
The earlier device log is in `output/rg353m-audio/device-adb-report.log`; the
host trace is in `output/rg353m-audio/adb-usb-trace.log`.

`prototype/system/usr/lib/plumos-353m/start-adb` now observes the UDC state.
After a `configured` → disconnected → `configured` transition, it exits through
its existing cleanup path. This unbinds the gadget, stops `adbd`, and unmounts
FunctionFS. plumOS init then starts a fresh ADB service. The check does not
restart the kernel, frontend, Wi-Fi, or audio services.

## Build and live test

- `sh -n prototype/system/usr/lib/plumos-353m/start-adb` and `git diff --check` passed.
- `prototype/build-bubble-system.sh` completed in Docker. The generated SYSTEM
  SHA-256 is `36986639c5ff450e909ad590143d9e25c55bbbd6660fa1095e5d2abdedc1339a`.
  The embedded `start-adb` hash matches the source:
  `01b65ae0d7059d9ad7ad9d0b715103605a5b28f1ec66a137b782607a589f23d0`.
- Published the SYSTEM with `boot-system publish`, selected it with `trial`,
  then rebooted. Previous default SYSTEM was retained during the trial.
- On normal boot, ADB was online, UDC was `configured`, Bubble's
  `plumos-controller-ui` was running, and the trial became healthy.
- With the OS and Bubble running, the user unplugged the Mac ADB cable for
  several seconds and plugged it back in. Device log recorded the old adbd
  transport termination, `plumOS ADB: USB reconnected; restarting stale
  FunctionFS transport`, then a new `adbd started` entry. The adbd PID changed
  from 220 to 4592. The Bubble PID remained 353 and system uptime continued.
- Mac ADB returned from an empty device list to `device` with a new transport
  ID. `adb shell` worked. SD2 ROM storage remained mounted.
- Promoted the healthy SYSTEM with `boot-system keep`; active, default, and
  healthy hashes now match the new SYSTEM.

The test covers one physical USB disconnect/reconnect cycle with the Mac and
current hub. The UDC state monitor requires a sampled non-configured state;
very brief controller resets shorter than its 100 ms polling interval have not
been tested.
