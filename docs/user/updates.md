# Updates

[日本語](updates.ja.md) · [Guide index](README.md)

## One-time migration from v0.1.1

The original v0.1.1 installation needs the RK3566 release public key before it can accept signed updates.

1. Download `plumOS-RK3566-update-key.zip` and its `.sha256` file from the [v0.1.2 release](https://github.com/game-de-it/plumOS-RK3566/releases/tag/v0.1.2) and verify the ZIP checksum.
2. Extract the archive and copy the `plumOS-RK3566-update-key` folder to the root of the SD1 **PLUMOS** volume.
3. Boot v0.1.1. Open `START` → `Apps` → `File Manager`, select `Install-Update-Key.sh`, and choose **Execute**. When `Update-Key.log` in the same folder shows `OK: The RK3566 release key is installed.`, use the procedure below to install v0.1.2.

If you are running v0.1.0, first use the manual upgrade ZIP from the [v0.1.1 release](https://github.com/game-de-it/plumOS-RK3566/releases/tag/v0.1.1). Install the key once per SD1 card.

## Signed runtime update

1. Download the RK3566 update package for your installed version and verify its checksum.
2. Put the package in `updates/` on the SD1 **PLUMOS** volume.
3. Open `START` → `System Settings` → `System Update` and follow the prompts through reboot.

The updater checks the signature and updates runtime files.

## Full SD image releases

Back up your saves and settings, then follow the image-writing instructions. [Backups](storage.md#saves-and-backups) · [Installation](install.md)
