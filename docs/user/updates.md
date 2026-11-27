# Updates

[日本語](updates.ja.md) · [Guide index](README.md)

## Move from v0.1.x to v0.2.0

Back up your saves and settings, then write the v0.2.0 common SD image to the TF1 card. [v0.2.0 release](https://github.com/game-de-it/plumOS-RK3566/releases/tag/v0.2.0) · [Data locations](storage.md) · [Installation](install.md)

## Signed runtime updates

The v0.2.0 common SD image includes the official public key and the RK3566 updater. When a compatible update is published, you can install it through the standard System Update menu using the embedded key.

1. Download the `plumos-rk3566-runtime-<version>.tar.gz` package for your installed version and verify the attached SHA-256.
2. Place the archive in `updates/` on the TF1 **PLUMOS** volume.
3. Open `START` → `System Settings` → `System Update`. After the automatic reboot, check the runtime version in `Information`.
