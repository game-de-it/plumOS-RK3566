# System layout

[日本語](architecture.ja.md) · [Guide index](README.md)

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
