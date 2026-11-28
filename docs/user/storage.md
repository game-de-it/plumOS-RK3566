# Games and saves

[日本語](storage.ja.md) · [Guide index](README.md)

## Games and BIOS

Bring your own game ROMs and, where required, matching BIOS files. On the SD1 **PLUMOS** volume or a FAT32 SD2, put ROMs in `Roms/<system>/` and BIOS files in `BIOS/` at the root. An SD2 ROM or BIOS folder takes priority over the corresponding SD1 folder. For disc games using a `.cue` or `.m3u` file, keep the files it references together.

| Example folder | Example content |
| --- | --- |
| `Roms/nes/` | NES `.nes` |
| `Roms/sfc/` | Super NES `.sfc`, `.smc` |
| `Roms/gb/`, `Roms/gba/` | Game Boy `.gb` and Game Boy Advance `.gba` |
| `Roms/nds/`, `Roms/psp/` | Nintendo DS `.nds` and PSP `.iso`, `.cso` |
| `Roms/psx/` | PlayStation `.cue`, `.chd`, `.pbp`, `.m3u` |
| `Roms/openbor/`, `Roms/pyxel/` | OpenBOR `.pak` and Pyxel `.pyxapp` |

See [Supported systems](supported-systems.md) for all recognized folders, extensions, and launch options.

## Library and artwork

After adding games, use `START` → `UI Settings` → `Refresh TOP`. To fetch artwork, connect to Wi-Fi and open `START` → `Apps` → `Scraping`. Matching depends on the ROM and available artwork. Images are kept under `Images/` on SD1.

## Saves and backups

These paths apply to games launched through the v0.2.0 frontend. They are relative to `/storage/plumos-rk3566/frontend/` on SD1. The locations in the table remain on SD1 when games are launched from SD2.

| Emulator | In-game saves | Save states |
| --- | --- | --- |
| RetroArch (RA) | Under `saves/` | Under `states/` |
| PicoArch (PICO) | `.sav` files in `saves/<system-id>/` | `.st0`, `.st1`, and other slots in `state/picoarch/<system-id>/.picoarch-<core-name>-<system-id>/` |
| DraStic (SA, Nintendo DS) | `.dsv` files in `config/standalone/drastic/work/backup/` | `.dss` files in `config/standalone/drastic/work/savestates/` |
| PCSX-ReARMed (SA, PlayStation) | Memory cards in `config/standalone/pcsx_rearmed/home/.pcsx/memcards/` (defaults are `card1.mcd` and `card2.mcd`) | `config/standalone/pcsx_rearmed/home/.pcsx/sstates/` |
| YabaSanshiro (SA, Sega Saturn) | `config/standalone/yabasanshiro/home/.yabasanshiro/backup.bin` | `.yss` files in the same `.yabasanshiro/` folder |
| OpenBOR (SA) | `config/standalone/openbor/data/Saves/` | Unavailable |
| PPSSPP (SA, PSP) | [PPSSPP save locations](#ppsspp) | [PPSSPP save locations](#ppsspp) |

For RetroArch, also check subfolders named for the core or the ROM's parent folder. Save and state support and file formats depend on the core. Games using writable disk images can also store changes in the disk image itself.

Pyxel and Ports save locations depend on the game. For Pyxel games that write to their home directory, check `state/pyxel-home/`. For ports launched through PortMaster, also check `state/portmaster/home/` and `state/portmaster/data/upstream/`. Include the game's own folder in backups, even on SD2, because a game can save there. Pyxel has no shared save-state feature. Save states for ports depend on the individual port.

Exit the emulator before backing up. Back up the whole card or copy the relevant folders over SFTP or ADB. Include the folders starting with a dot for PicoArch, PCSX-ReARMed, and YabaSanshiro. Use the same emulator and core when restoring save states.

### PPSSPP

`SA: PPSSPP-MALISX2` stores its data by default on SD1 under `/storage/plumos-rk3566/frontend/config/standalone/ppsspp/ppsspp/PSP/`. It uses this location even when the PSP game runs from SD2.

| Data | Folder inside `PSP/` |
| --- | --- |
| Saves made in the game | `SAVEDATA/` |
| PPSSPP save states | `PPSSPP_STATE/` |
| PPSSPP settings and button mappings | `SYSTEM/` |

Exit PPSSPP before transferring saves. Copy each game's full directory from `SAVEDATA/`. To back up saves, save states, and settings together, copy the entire `PSP/` folder. SFTP opens in `/storage/user`. Enter the absolute path above to reach the PPSSPP folder. [Connecting over SFTP or USB ADB](network.md)
