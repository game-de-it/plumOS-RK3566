# Third-party licenses for plumOS-RK3566

[日本語](THIRD_PARTY_NOTICES.ja.md)

The [MIT License](LICENSE) covers original plumOS-RK3566 software and documentation. Third-party code, including code modified by plumOS patches, keeps its applicable upstream terms and copyright notices. Firmware, binaries, fonts, and artwork also retain their own terms.

The emulator inventory comes from the tested RG353V `SYSTEM` with SHA-256 `4c3a44d5ba2e7cce6aa066ca93849d49479e393f20f30ccc617a899f64134bfd`. Paths beginning with `licenses/`, `components/`, `apps/`, or `share/` below are relative to `/usr/lib/plumos-353m/frontend` inside that SYSTEM.

## Boot and hardware

| Component | License and evidence |
| --- | --- |
| JELOS 20240206 boot scripts and initramfs | JELOS software is GPL version 2. BusyBox 1.36.1 uses GPL-2.0-only. The build retains JELOS's early boot code. [Pinned source and build information](docs/jelos-20240206-source.md) |
| Linux 4.19.172, DTBs and Realtek Wi-Fi kernel modules | The kernel uses GPL-2.0-only, with the Linux syscall exception for applicable userspace headers and per-file terms for DT sources. The Realtek `8821cs.ko` and `8723ds.ko` drivers declare GPL. The RTL8723DS Wi-Fi firmware is embedded in the pinned driver source. [Pinned kernel source](https://github.com/JustEnoughLinuxOS/rk356x-kernel/tree/c741d56477939654bb4056be240f93d1ad1ae91e) |
| U-Boot | GPL version 2, with later versions permitted for most files and exceptions identified upstream. The RGB30 and RG353V changes are provided as patches to that source. [Pinned U-Boot license notes](https://github.com/JustEnoughLinuxOS/rk356x-uboot/blob/97c658238f7ccd436fbdede451bfd7488514a5c8/Licenses/README) |
| Rockchip rkbin DDR, SPL and BL31 | [Rockchip Binary Software License Agreement](docs/licenses/rockchip-rkbin.txt) from the pinned rkbin tree. Distribution is subject to its Rockchip platform, bundling and notice terms. [Binary names and revision](docs/jelos-20240206-source.md) |
| Arm Mali userspace driver | Proprietary. JELOS's libmali recipe identifies Bifrost G52 g13p0, packaged as `libmali.so.1.9.0`. [Mali agreement archived by JELOS](docs/licenses/jelos-mali-eula.txt). Confirm which terms apply to the exact JELOS binaries included in the release. |
| Realtek RTL8821CS Bluetooth firmware and configuration | The pinned JELOS recipe declares Apache-2.0 for `rtl8821c_fw` and `rtl8821c_config`. Both shipped files match the recipe inputs by SHA-256. Confirm the upstream copyright and complete notice before publication. [JELOS recipe](https://github.com/JustEnoughLinuxOS/distribution/blob/f8cac7b92040d734506e238f5a44560a4f0e81b0/packages/kernel/linux-firmware/RTL8821CS-firmware/package.mk) |
| JELOS branding and plumOS splash | JELOS branding and imagery use CC BY-NC-SA 4.0 where retained. Verify the files in the release boot image, including compressed resources. For the splash sourced from plumOS-mini-PLUS, verify the provenance of the image itself. [JELOS license](https://github.com/JustEnoughLinuxOS/distribution/blob/f8cac7b92040d734506e238f5a44560a4f0e81b0/LICENSE.md) · [Splash recipe](prototype/build-boot-splash.sh) |

## Frontend, emulators and Apps

| Component | License and evidence |
| --- | --- |
| plumOS-Bubble frontend, launchers and original helpers | MIT for original Bubble code. See the shipped frontend `LICENSE`. Preserve the separate terms for third-party material from that build. [Bubble notices](https://github.com/game-de-it/plumOS-Bubble/blob/main/THIRD_PARTY_NOTICES.md) |
| RetroArch and assets | RetroArch uses GPL-3.0-or-later. The assets collection includes CC BY 4.0 material and retains notices for separately licensed fonts and artwork. See `licenses/RetroArch-COPYING`, `licenses/RetroArch-Assets-COPYING` and `licenses/RetroArch-Assets-README.md`. |
| RetroArch and PicoArch cores | The [per-profile inventory](docs/licenses/libretro-cores.tsv) lists source revisions, upstream license labels and notice paths for 136 profiles. The set includes non-commercial and custom terms, including those for several Snes9x, FinalBurn and Genesis Plus GX builds. Follow each recorded notice for version, scope and restrictions. |
| PicoArch | BSD-3-Clause for PicoArch's own code, with separate GPL/LGPL/MAME options for libpicofe and MIT filters. See `licenses/picoarch-LICENSE`. |
| PCSX-ReARMed and Yaba Sanshiro standalones | GNU GPL version 2 license texts are bundled. Follow the source headers for version options and dependencies. See `licenses/pcsx-rearmed-standalone-COPYING` and `licenses/yabasanshiro-LICENSE`. |
| PPSSPP standalone | GPL-2.0-or-later with separate notices for bundled code such as PSPSDK. See `licenses/ppsspp-LICENSE.txt`. [Upstream](https://github.com/hrydgard/ppsspp) |
| MaliSX2 and Vulkan Loader (development builds after v0.1.0) | Scope is PPSSPP. MaliSX2 0.6.1 uses MIT, with separate terms for bundled Mesa code. Debian's Vulkan Loader uses Apache-2.0 and per-file terms. See `emulator/standalone/ppsspp/vulkan/licenses/`. [MaliSX2 source](https://github.com/bmdhacks/malisx2/tree/v0.6.1) |
| OpenBOR standalone | BSD-3-Clause for the engine. Game packs carry their own terms. See `licenses/openbor-LICENSE`. |
| DraStic | `steward-fu/nds` integration is LGPL-2.1-only. DraStic itself is a separate proprietary executable. The bundled integration notice and upstream release README do not establish public redistribution rights for that executable. See `licenses/steward-fu-nds-LGPL-2.1` and `licenses/drastic-upstream-NOTICE.txt`. |
| Pyxel, Python, pygame, NumPy and Pillow | Pyxel MIT, CPython PSF terms and historical notices, pygame LGPL-2.1, NumPy BSD-3-Clause, Pillow HPND. Keep wheel `*.dist-info` notices under `apps/pyxel/site/`, including bundled libraries and assets, and keep CPython's notices. |
| FreeJ2ME-Plus and Java | GPL-3.0 for the FreeJ2ME code, with separate terms for ObjectWeb ASM and other bundled code. OpenJDK uses GPL-2.0 with the Classpath Exception and per-module notices under `share/libretro-system/freej2me-plus/freej2me_plus_runtime/linux-arm64/legal/`. See `licenses/freej2me_plus-LICENSE`. |
| PortMaster | MIT for the pinned GUI. Helper programs, fonts, libraries and each downloaded port retain their own terms. See `apps/portmaster/upstream/PortMaster/licenses/`. [Pinned GUI license](https://github.com/PortsMaster/PortMaster-GUI/blob/2026.06.23-0015/LICENSE) |
| NextCommander | Verify the program's license for the [pinned source](https://github.com/LoveRetro/NextCommander/tree/49c24bb67c12aea8078f48c833815f9ef2dcc5e2). The root of that revision has no standalone license document. Source Code Pro is SIL OFL 1.1. Verify the other bundled font independently. |
| Music Player and audio routing | Original plumOS code uses MIT. miniaudio offers public-domain or MIT-0 terms. ALSA and other dependencies retain their respective terms. See `licenses/plumos-audio-router-MIT.txt` and `components/music-player/manifest.json`. [miniaudio](https://github.com/mackron/miniaudio) |

## System tools and libraries

| Component | License and evidence |
| --- | --- |
| BusyBox, Bash and GNU coreutils | BusyBox GPL-2.0-only. Bash and GNU coreutils GPL-3.0-or-later. Preserve Debian package notices and the BusyBox notice shipped with the network tools. |
| Debian util-linux/fdisk, e2fsprogs, dosfstools and kmod | util-linux/fdisk and e2fsprogs carry GPL, LGPL and other per-file terms. dosfstools is GPL-3.0-or-later. kmod carries GPL and LGPL terms. Use the packaged file-level copyright notices. |
| Dropbear, OpenSSH SFTP, OpenSSL and Samba | Dropbear uses MIT-style and bundled notices. OpenSSH uses BSD/ISC-style and other notices. OpenSSL 3 uses Apache-2.0. Samba uses GPL-3.0-or-later with separately licensed libraries. |
| wpa_supplicant, ALSA tools and Info-ZIP UnZip | wpa_supplicant and wpa_cli use BSD-3-Clause. ALSA tools use GPL with package-specific exceptions. UnZip uses the Info-ZIP license. |
| Shared libraries, CA certificates and time zones | Consult the exact Debian package notices for linked libraries, Samba modules, ALSA data, `ca-certificates` and `tzdata`. This includes LGPL glibc and ALSA libraries, zlib-licensed SDL2, and GCC runtime libraries with their runtime exception where applicable. |
| RGB10 Max 3 display libraries | Rockchip librga is Apache-2.0. The packaged binary comes from the reference JELOS 20240206 SYSTEM, and the custom SDL2 2.32.0 build uses the zlib license. The matching RGA headers come from the pinned JELOS source. [RGA source](https://github.com/JustEnoughLinuxOS/linux-rga/tree/df26244eb0c3991df319d4276ab80e8c0bf91f64) · [RGA license](docs/licenses/linux-rga-Apache-2.0.txt) · [SDL2 license](https://github.com/libsdl-org/SDL/blob/release-2.32.0/LICENSE.txt) |
| Standalone Linux adbd | The pinned `v36.0.1-linux.2` source carries [Apache-2.0](docs/licenses/standalone-linux-adbd-Apache-2.0.txt). The static executable includes separately licensed dependencies. Keep their notices from the exact build inputs. [Pinned source and build inputs](https://github.com/happyme531/standalone-linux-adbd/tree/v36.0.1-linux.2) |

The [Debian package inventory](docs/licenses/debian-runtime.tsv) identifies 164 packages with at least one byte-identical file in the tested SYSTEM and the cached Docker runtime. It records the binary and source versions and the labels in their Debian copyright files. Generated files such as the CA certificate bundle and files built in a separate layer require separate provenance.

For each release, map Debian binaries and shared libraries to their source package and version in the Docker build container. Preserve each applicable `/usr/share/doc/<package>/copyright` and the license text it references. [Docker runtime recipe](prototype/build-runtime-system.sh) · [Debian copyright-file policy](https://www.debian.org/doc/debian-policy/ch-docs.html#copyright-information)

For a public artifact, reconcile this inventory with the actual SD image and SYSTEM, including fonts, media and statically linked dependencies. Keep the applicable notices and provide corresponding source, build scripts and patches where the license requires them. Resolve outstanding firmware, binary and asset permissions before including those components. [Release checklist](docs/developer/release.md#release-files)
