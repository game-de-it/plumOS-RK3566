# Troubleshooting

[日本語](troubleshooting.ja.md) · [Guide index](README.md)

- **The frontend does not appear.** Allow first-boot storage preparation to finish. If boot stays stuck, check the image checksum and TF1 slot, then try booting with TF2 removed while powered off. Keep the exact device model, image version and screen message for a bug report.
- **SD2 or games missing.** Shut down, check the FAT32 card and root folder layout, then boot and refresh the list. A test boot with TF2 empty can help identify a card problem. `Repair SD2` under `Apps` is for a recognized SD2 with filesystem errors.
- **USB appears to charge only.** Confirm the data-capable port, unlock the computer and allow any accessory prompt, then check `adb devices -l`. RG503 USB ADB worked in the retest with a different data cable. [RG503 retest](../validation/2026-11-25-rg503-runtime.md#別ケーブルでのusb-adb再試験)
- **Slow gameplay, silent audio, or a failed launch.** Check the selected core, its BIOS requirements and the active audio output. Performance and compatibility vary by title. The emulator matrix measured representative launches and leaves untested profiles marked. [Device test records](../developer/validation.md)
