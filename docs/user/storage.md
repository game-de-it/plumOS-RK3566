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

Save data, save states and settings live on the system card's managed area under `/storage/plumos-rk3566/frontend/`. RetroArch uses `saves/` and `states/` under that path; standalone emulators and ports can use their own subdirectories. A copy of the visible FAT32 files alone misses these saves. Back up the whole card or retrieve the files using SFTP or ADB. Keep the original emulator and core available when relying on save states.

### PPSSPP

`SA: PPSSPP-MALISX2` stores its data by default on SD1 under `/storage/plumos-rk3566/frontend/config/standalone/ppsspp/ppsspp/PSP/`. It uses this location even when the PSP game runs from SD2.

| Data | Folder inside `PSP/` |
| --- | --- |
| Saves made in the game | `SAVEDATA/` |
| PPSSPP save states | `PPSSPP_STATE/` |
| PPSSPP settings and button mappings | `SYSTEM/` |

Exit PPSSPP before transferring saves. Copy each game's full directory from `SAVEDATA/`. To back up saves, save states, and settings together, copy the entire `PSP/` folder. SFTP opens in `/storage/user`. Enter the absolute path above to reach the PPSSPP folder. [Connecting over SFTP or USB ADB](network.md)
