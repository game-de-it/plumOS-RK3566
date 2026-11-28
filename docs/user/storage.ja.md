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

セーブ、ステート、設定は、SD1の管理領域 `/storage/plumos-rk3566/frontend/` 以下に保存されます。RetroArchではその中の `saves/` と `states/` を使い、単体エミュレータやPortsは個別の保存先を使う場合があります。セーブを含めるにはカード全体をバックアップするか、SFTPやADBで保存先からコピーしてください。ステートを使い続ける場合は、作成時のエミュレータとコアも控えておいてください。

### PPSSPP

`SA: PPSSPP-MALISX2` の既定の保存先は、SD1の `/storage/plumos-rk3566/frontend/config/standalone/ppsspp/ppsspp/PSP/` です。PSPのゲームをSD2から起動する場合も、この場所を使います。

| データ | 上記の `PSP/` 内のフォルダ |
| --- | --- |
| ゲーム内で保存した通常セーブ | `SAVEDATA/` |
| PPSSPPのセーブステート | `PPSSPP_STATE/` |
| PPSSPPの設定とボタン割り当て | `SYSTEM/` |

セーブを移行するときはPPSSPPを終了し、`SAVEDATA/` のゲーム別フォルダを中のファイルごとコピーします。ステートと設定もまとめて保存する場合は `PSP/` フォルダを丸ごとバックアップしてください。SFTPで接続した直後は `/storage/user` が開くので、上記の絶対パスに移動します。[SFTPとUSB ADBの接続方法](network.ja.md)
