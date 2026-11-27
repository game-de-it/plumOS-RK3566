# Writing the system card and first boot

[日本語](install.ja.md) · [User manual](README.md)

## Prepare the card

Use a [tested device](devices.md), a microSD card for TF1/SD1 (16 GB or larger recommended), a card reader, and a raw-image writer. Use the compressed image and its SHA-256 checksum file from the same release.

Back up the target card before writing. If it already runs plumOS, back up saves, states, and settings as well as the files on the visible FAT32 volume. A whole-card backup includes both areas. [Data locations](storage.md)

## Write and boot

1. Download the image and checksum file from the same release. For v0.2.0, verify the compressed file before extracting it.

   ```sh
   shasum -a 256 -c plumOS-RK3566-v0.2.0.img.gz.sha256
   gzip -dk plumOS-RK3566-v0.2.0.img.gz
   ```

   On Linux, `sha256sum -c` performs the same check. On Windows, use `Get-FileHash -Algorithm SHA256` and compare the digest for each file with the matching entry.

2. Select the extracted `.img` and write it as a raw disk image. Verify the target's name and capacity before writing, since the operation overwrites that drive. Let the writer finish verification, then eject the card.
3. With the handheld powered off, put the card in the slot marked **TF1**, **SD1**, or **OS**, depending on the model. Use the printed slot label. Leave TF2 empty for the first boot if you want to check the system card on its own.
4. Power on and wait until the game list appears. First boot prepares the storage and creates the computer-readable FAT32 volume named **PLUMOS**. The handheld may reboot during this process. Keep the card inserted and wait for setup to finish.
5. Use the frontend's **Shutdown** action before removing the card. Use the **PLUMOS** volume when copying games from a computer. If the computer offers to initialize or format another partition, dismiss that prompt.

## Optional TF2/SD2

Use a FAT32 card with `Roms/` and, when needed, `BIOS/` at its root. Insert or remove the card while the handheld is powered off. On startup, plumOS uses the SD2 folders that are present and keeps saves and settings on SD1. [Folder examples](storage.md)
