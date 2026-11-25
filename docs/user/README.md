# plumOS-RK3566 user manual

[日本語](README.ja.md) · [Documentation index](../README.md)

Start here to choose a device, find the controls, and set up your library. [Writing the SD card and first boot](install.md)

## Devices

The same SD image selects the board at boot. RGB30 r1 and r2 use the same image.

| Device | What was checked |
| --- | --- |
| Anbernic RG353M | Boot, frontend, SD2, Wi-Fi, USB ADB, and representative emulator, audio and sleep tests |
| Anbernic RG353V | Boot, SD2, USB ADB, power-on with USB connected, and representative emulator, app, audio and sleep tests |
| Anbernic RG503 | Boot, 960×544 display, SD2, USB ADB with an alternate data cable, and representative emulator, app, audio and sleep tests |
| Powkiddy RGB30 r1 / r2 | Boot, automatic board revision selection, frontend, and ADB on both revisions. The broader SD2, emulator and audio tests used r2. |
| Powkiddy RK2023 | Boot, 640×480 display, SD2, USB ADB, representative emulator and app tests, sleep and USB DAC switching back to the speaker. Wi-Fi hardware was absent from the test unit's device inventory. |

The image includes board definitions for RG353P and RGB10 Max 3. Both still await a plumOS hardware boot test. RG353VS is also untested and has no dedicated device tree in the image. [Device evidence](../boot-and-device-support.md)

## Controls and audio

| Where | Control |
| --- | --- |
| Frontend | Use the D-pad to move, `A` to confirm or launch, `B` to go back, and `START` to open the main menu. |
| Game selected in the frontend | Press `SELECT` to choose an available emulator or core. |
| RetroArch | Press **SELECT + B** in either order to open the Quick Menu. On handhelds with FN, **FN** also opens it. |
| PicoArch and standalone emulators | Press **FN** on RG353M, RG353V, or RG503. On RGB30 or RK2023, press **SELECT + START**. |
| Ports and Pyxel | Use the controls and exit menu supplied by each game or app. |
| Power | Short-press the power button to bring up the power menu. Choose `Sleep` and short-press power again to wake, or use `Shutdown` before removing a card. |
| Volume | Use the hardware volume buttons during gameplay or the frontend's `Volume` setting. |

With the default RetroArch bindings, `SELECT + START` exits to the frontend, `SELECT + R` saves a state, and `SELECT + L` loads one. Use the emulator's menu if your controls have been remapped.

On RG353M, hold `START` and press left or right on the D-pad to adjust brightness. Volume steps are finer near mute. A compatible USB DAC on the data/OTG port can take over from the speaker during gameplay. Disconnecting it can return playback to the speaker. This was checked with representative devices and emulators; support varies with the DAC and game.

To switch the frontend language, open `START` → `System Settings` → `Language`.

## Games and saves

Bring your own game ROMs and, where required, matching BIOS files. On the SD1 **PLUMOS** volume or a FAT32 SD2, put ROMs in `Roms/<system>/` and BIOS files in `BIOS/` at the root. An SD2 ROM or BIOS folder takes priority over the corresponding SD1 folder. For disc games using a `.cue` or `.m3u` file, keep the files it references together.

| Example folder | Example content |
| --- | --- |
| `Roms/nes/` | NES `.nes` |
| `Roms/sfc/` | Super NES `.sfc`, `.smc` |
| `Roms/gb/`, `Roms/gba/` | Game Boy `.gb` and Game Boy Advance `.gba` |
| `Roms/nds/`, `Roms/psp/` | Nintendo DS `.nds` and PSP `.iso`, `.cso` |
| `Roms/psx/` | PlayStation `.cue`, `.chd`, `.pbp`, `.m3u` |
| `Roms/openbor/`, `Roms/pyxel/` | OpenBOR `.pak` and Pyxel `.pyxapp` |

After adding games, use `START` → `UI Settings` → `Refresh TOP`. To fetch artwork, connect to Wi-Fi and open `START` → `Apps` → `Scraping`. Matching depends on the ROM and available artwork. Images are kept under `Images/` on SD1.

Save data, save states and settings live on the system card's managed area under `/storage/plumos-rk3566/frontend/`. RetroArch uses `saves/` and `states/` under that path; standalone emulators and ports can use their own subdirectories. A copy of the visible FAT32 files alone misses these saves. Back up the whole card or retrieve the files using SFTP or ADB. Keep the original emulator and core available when relying on save states.

## Network and USB

On devices with detected Wi-Fi hardware, use `START` → `Network Settings` → `Connect Wi-Fi` to choose an SSID. Read the IP address under `INFORMATION` in the same menu, and enable the service you need under `NW Service`.

| Service | How to connect |
| --- | --- |
| SSH / SFTP | Device IP, port 22. The factory login is `root` / `plumos`. SFTP starts in the user area. |
| FTP | Device IP, port 21. Anonymous access to the user area. |
| Samba | Share `SDCARD`. Factory login `plumos` / `plumos`. The share starts in the user area. |
| USB ADB | Connect the handheld's data-capable port using a data cable and run `adb devices -l`. The ADB switch is under `NW Service`. A service change can require a restart. |

Factory credentials are shared across installations and USB ADB provides a root shell. Enable the services you use on a trusted network or computer.

## Updates and troubleshooting

- **Update offered for your installation.** Verify its checksum and place the signed RK3566 runtime package in `updates/` on the SD1 **PLUMOS** volume. Select `System Update` under `START` → `System Settings`, and follow the prompts through reboot. This update path checks the package and does not write the bootloader or kernel. For a release distributed as a full image, follow its installation instructions and back up user data first. [Installation](install.md)
- **The frontend does not appear.** Allow first-boot storage preparation to finish. If boot stays stuck, check the image checksum and TF1 slot, then try booting with TF2 removed while powered off. Keep the exact device model, image version and screen message for a bug report.
- **SD2 or games missing.** Shut down, check the FAT32 card and root folder layout, then boot and refresh the list. A test boot with TF2 empty can help identify a card problem. `Repair SD2` under `Apps` is for a recognized SD2 with filesystem errors.
- **USB appears to charge only.** Confirm the data-capable port, unlock the computer and allow any accessory prompt, then check `adb devices -l`. RG503 USB ADB worked in the retest with a different data cable. [RG503 retest](../validation/2026-11-25-rg503-runtime.md#別ケーブルでのusb-adb再試験)
- **Slow gameplay, silent audio, or a failed launch.** Check the selected core, its BIOS requirements and the active audio output. Performance and compatibility vary by title. The emulator matrix measured representative launches and leaves untested profiles marked. [Device test records](../developer/README.md#device-validation)
