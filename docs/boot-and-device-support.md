# JELOS 20240206の機種自動判定

## 元イメージと試作で確認した内容

1. Rockchip U-Bootは `resource` パーティションのDTB候補を読み、ハードウェアIDに合う候補を選ぶ。このJELOSイメージの候補名には `#_saradc_ch1=...` が付いている。例えば、RG353Mの候補は `rk3566-rg353m-linux#_saradc_ch1=512.dtb`。
2. U-Bootは選ばれた候補名から `fdtfile` を設定する。FAT32の `extlinux/extlinux.conf` の `FDTDIR /` は、そのファイル名を使ってFAT32上のカーネル用DTBを読み込む。
3. Linuxのinitramfsが `SYSTEM` をルートにしてsystemdを起動するため、機種自動判定とユーザランドの起動設定は独立している。

試作イメージの `resource` 領域と `extlinux.conf` は元のバイト列と一致した。FAT32上の7つのDTBも個別に照合した。

| FAT32上のDTB | DTB内の `model` |
| --- | --- |
| `rk3566-rg353p-linux.dtb` | Anbernic RG353P |
| `rk3566-rg353m-linux.dtb` | Anbernic RG353M |
| `rk3566-rg353v-linux.dtb` | Anbernic RG353V |
| `rk3566-rg503-linux.dtb` | Anbernic RG503 |
| `rk3566-rk2023-linux.dtb` | Powkiddy RK2023 |
| `rk3566-rgb30-linux.dtb` | Powkiddy RGB30 |
| `rk3566-max3pro-linux.dtb` | Powkiddy RGB10 Max 3 |

JELOS 20240206の対応表にはRG353VSも載っている。このイメージにはVS専用名のDTBがない。RGB10 Max 3 ProはAmlogic A311Dで、上表のRGB10 Max 3とは別機種。x55には同じJELOSタグ内に `RK3566-X55` という別ターゲットがある。

[JELOS RK3566のビルド設定](https://github.com/JustEnoughLinuxOS/distribution/blob/f8cac7b92040d734506e238f5a44560a4f0e81b0/projects/Rockchip/devices/RK3566/options) · [U-BootのハードウェアID選択](https://github.com/JustEnoughLinuxOS/rk356x-uboot/blob/97c658238f7ccd436fbdede451bfd7488514a5c8/arch/arm/mach-rockchip/resource_img.c#L850-L909) · [U-BootのFDTDIR読み込み](https://github.com/JustEnoughLinuxOS/rk356x-uboot/blob/97c658238f7ccd436fbdede451bfd7488514a5c8/cmd/pxe.c#L723-L767) · [当時のJELOS対応表](https://github.com/JustEnoughLinuxOS/distribution/blob/f8cac7b92040d734506e238f5a44560a4f0e81b0/README.md#device-support) · [x55のビルド設定](https://github.com/JustEnoughLinuxOS/distribution/blob/f8cac7b92040d734506e238f5a44560a4f0e81b0/projects/Rockchip/devices/RK3566-X55/options)

## 同一イメージで対応機種を増やす場合

現試作はRG353M用のDRMノード、ゲームパッドと電源キーのパス、USBデバイスコントローラーをフロントエンドとADBの起動スクリプトで指定している。別機種のDTBを選んでLinuxまで到達できても、plumOSの表示・入力・ADBは各機種で検証が必要。

複数機種に対応する場合は、JELOSのDTB選択を維持し、ユーザランド起動時に `/proc/device-tree/model` などから検証済みの機種設定を選ぶ。同じフロントエンドを使い、DRMコネクタと回転、入力マッピング、音声、USBデバイスモードの差分を機種ごとに持つ。機種設定を追加するたびに、実機でコールドブート、最初の描画、ボタン、ADBを確認する。

## パーティションとユーザランドの引き渡し

| GPT | 名前 | 実機の用途 |
| --- | --- | --- |
| p1 | `uboot` | U-BootとARM Trusted Firmwareを含むFIT |
| p2 | `resource` | 機種自動判定用のRockchipリソースとDTB |
| p3 | `boot` | FAT32。`/flash` に読み取り専用でマウント。`KERNEL`、DTB、extlinux、SquashFSの `SYSTEM`、ADB差分更新の起動フックを格納。 |
| p4 | `storage` | ext4。`/storage` に読み書き可能でマウント。設定やユーザーデータを保存。 |

カーネル内のJELOS initramfsの `/init` が初期PID 1となり、`SYSTEM` をマウントします。この段階で `post-sysroot.sh` がロゴ表示を差し替えます。その後、`switch_root` が `SYSTEM` 内の `/usr/lib/systemd/systemd` を実行します。実機の常駐PID 1はsystemd、既定ターゲットは `jelos.target` です。同ターゲットの既存 `emustation.service` をplumOSフロントエンドに切り替え、USB ADBのサービスを追加しています。PID 1とターゲットの構成はJELOSを引き継いでいます。
