# ゲームとセーブ

[English](storage.md) · [ガイドの目次](README.ja.md)

## ゲームとBIOS

ゲームROMと、必要な場合は対応するBIOSを用意してください。SD1の **PLUMOS** ボリュームまたはFAT32のSD2で、ルートの `Roms/<機種別フォルダ>/` にROMを、`BIOS/` にBIOSを置きます。SD2にROMまたはBIOS用フォルダがある場合は、対応するSD1側のフォルダより優先されます。ディスク作品の `.cue` や `.m3u` が参照するファイルは一緒に置きます。

| フォルダの例 | ファイルの例 |
| --- | --- |
| `Roms/nes/` | ファミコンの `.nes` |
| `Roms/sfc/` | スーパーファミコンの `.sfc`、`.smc` |
| `Roms/gb/`、`Roms/gba/` | ゲームボーイの `.gb`、ゲームボーイアドバンスの `.gba` |
| `Roms/nds/`、`Roms/psp/` | Nintendo DSの `.nds`、PSPの `.iso`、`.cso` |
| `Roms/psx/` | PlayStationの `.cue`、`.chd`、`.pbp`、`.m3u` |
| `Roms/openbor/`、`Roms/pyxel/` | OpenBORの `.pak`、Pyxelの `.pyxapp` |

システム別のフォルダ名、拡張子、エミュレータは[対応システム一覧](supported-systems.ja.md)を参照してください。

## 一覧と画像

ゲームを追加したら `START` → `UI Settings` → `Refresh TOP` で一覧を更新します。ジャケット画像はWi-Fi接続後に `START` → `Apps` → `Scraping` から取得できます。取得できるかはROMと配信元の画像によって異なり、取得した画像はSD1の `Images/` に保存されます。

## セーブとバックアップ

v0.2.0のフロントエンドから起動した場合、以下のパスはSD1の管理領域 `/storage/plumos-rk3566/frontend/` からの相対パスです。SD2からゲームを起動する場合も、表の保存先はSD1です。

| エミュレータ | 通常セーブ | セーブステート |
| --- | --- | --- |
| RetroArch（RA） | `saves/` 以下 | `states/` 以下 |
| PicoArch（PICO） | `saves/<システムID>/` の `.sav` | `state/picoarch/<システムID>/.picoarch-<コア名>-<システムID>/` の `.st0`、`.st1` など |
| DraStic（SA、Nintendo DS） | `config/standalone/drastic/work/backup/` の `.dsv` | `config/standalone/drastic/work/savestates/` の `.dss` |
| PCSX-ReARMed（SA、PlayStation） | `config/standalone/pcsx_rearmed/home/.pcsx/memcards/` のメモリーカード（既定は `card1.mcd` と `card2.mcd`） | `config/standalone/pcsx_rearmed/home/.pcsx/sstates/` |
| YabaSanshiro（SA、セガサターン） | `config/standalone/yabasanshiro/home/.yabasanshiro/backup.bin` | 同じ `.yabasanshiro/` にある `.yss` |
| OpenBOR（SA） | `config/standalone/openbor/data/Saves/` | 非対応 |
| PPSSPP（SA、PSP） | [PPSSPPの保存先](#ppsspp) | [PPSSPPの保存先](#ppsspp) |

RetroArchではコアやROMの親フォルダで分けられたサブフォルダも確認してください。セーブやステートへの対応とファイル形式はコアによって異なります。書き込み可能なディスクイメージを使うゲームでは、ディスク自体に変更が保存される場合もあります。

PyxelとPortsの保存先はゲームごとに異なります。ホームフォルダに保存するPyxelゲームでは `state/pyxel-home/` を確認してください。PortMasterから起動するPortsでは `state/portmaster/home/` と `state/portmaster/data/upstream/` も確認してください。ゲーム自身がゲームフォルダに保存する場合もあるので、SD2のゲームフォルダもバックアップ対象に含めてください。Pyxelの共通ステート機能はなく、Portsのステートは各移植版の実装によります。

バックアップ前にエミュレータを終了してください。カード全体をバックアップするか、SFTPやADBで該当フォルダをコピーします。PicoArch、PCSX-ReARMed、YabaSanshiroではドットで始まるフォルダも含めてください。ステートを移行する場合は、作成時と同じエミュレータとコアを使ってください。

### PPSSPP

`SA: PPSSPP-MALISX2` の既定の保存先は、SD1の `/storage/plumos-rk3566/frontend/config/standalone/ppsspp/ppsspp/PSP/` です。PSPのゲームをSD2から起動する場合も、この場所を使います。

| データ | 上記の `PSP/` 内のフォルダ |
| --- | --- |
| ゲーム内で保存した通常セーブ | `SAVEDATA/` |
| PPSSPPのセーブステート | `PPSSPP_STATE/` |
| PPSSPPの設定とボタン割り当て | `SYSTEM/` |

セーブを移行するときはPPSSPPを終了し、`SAVEDATA/` のゲーム別フォルダを中のファイルごとコピーします。ステートと設定もまとめて保存する場合は `PSP/` フォルダを丸ごとバックアップしてください。SFTPで接続した直後は `/storage/user` が開くので、上記の絶対パスに移動します。[SFTPとUSB ADBの接続方法](network.ja.md)
