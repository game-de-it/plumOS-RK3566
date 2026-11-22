# JELOS 20240206の機種自動判定

## RG353Mで確認したTF1からの起動経路

Dockerで再ビルドしたJELOS 20240206を、黒画面で電源が落ちたplumOS試作と同じ物理SDに書き込み、RG353MでEmulationStationまで起動したことをユーザーが確認しました。

1. JELOSのRK3566用イメージ生成は、SDのLBA 64にRockchipのIDB、LBA 16384にU-Boot FIT、LBA 24576に `resource.img` を配置します。U-Bootはプリローダーから起動デバイスを取得し、取得できない場合は `rkimg_bootdev` が先に `mmc1` を調べます。`rkimgtest` はSDのLBA 64のIDBマジックを検査します。配布版・再ビルド版・12 GiB試作版のマジックは `0x534e4b52` でした。[イメージ生成](https://github.com/JustEnoughLinuxOS/distribution/blob/f8cac7b92040d734506e238f5a44560a4f0e81b0/projects/Rockchip/bootloader/mkimage#L7-L34) · [起動デバイスの選択](https://github.com/JustEnoughLinuxOS/rk356x-uboot/blob/97c658238f7ccd436fbdede451bfd7488514a5c8/arch/arm/mach-rockchip/boot_rkimg.c#L64-L106) · [IDBの検査](https://github.com/JustEnoughLinuxOS/rk356x-uboot/blob/97c658238f7ccd436fbdede451bfd7488514a5c8/cmd/rkimgtest.c#L26-L55)
2. JELOSのU-Bootでは `__ANBERNIC_BOOT__` が有効です。ビルドされた `bootcmd` は `boot_fit`、選択したデバイスの `boot_android` に続けて `setenv distro_bootpart 3&&run distro_bootcmd` を実行します。3イメージとも `boot_targets` は `mmc1 mmc0 usb0 pxe dhcp` でした。通常の探索では、そのデバイスの起動可能なGPT領域を調べます。実イメージの `p3` はEFIシステムパーティション型で、U-Bootの `is_bootable()` が起動可能と判定し、ここから `extlinux.conf` を読み込みます。[Anbernic向け定義](https://github.com/JustEnoughLinuxOS/rk356x-uboot/blob/97c658238f7ccd436fbdede451bfd7488514a5c8/include/configs/rockchip-common.h#L7-L10) · [RK3568系の起動コマンド](https://github.com/JustEnoughLinuxOS/rk356x-uboot/blob/97c658238f7ccd436fbdede451bfd7488514a5c8/include/configs/rk3568_common.h#L83-L109) · [パーティション探索](https://github.com/JustEnoughLinuxOS/rk356x-uboot/blob/97c658238f7ccd436fbdede451bfd7488514a5c8/include/config_distro_bootcmd.h#L370-L379) · [起動可能フラグの判定](https://github.com/JustEnoughLinuxOS/rk356x-uboot/blob/97c658238f7ccd436fbdede451bfd7488514a5c8/disk/part_efi.c#L66-L72)
3. `resource.img` の `rk3566-rg353m-linux#_saradc_ch1=512.dtb` で機種を判定し、`fdtfile` と `FDTDIR /` で `p3` の `rk3566-rg353m-linux.dtb` を選びます。LinuxがTF1を列挙し、JELOSのinitramfsが `boot=UUID=` で指定されたFATを `/flash` にマウントします。この起動では、再ビルド時に生成したFAT ID `2211-3302` を使いました。[DTBの選択](https://github.com/JustEnoughLinuxOS/rk356x-uboot/blob/97c658238f7ccd436fbdede451bfd7488514a5c8/arch/arm/mach-rockchip/resource_img.c#L854-L909) · [FDTDIRの処理](https://github.com/JustEnoughLinuxOS/rk356x-uboot/blob/97c658238f7ccd436fbdede451bfd7488514a5c8/cmd/pxe.c#L723-L766) · [JELOSのマウント処理](https://github.com/JustEnoughLinuxOS/distribution/blob/f8cac7b92040d734506e238f5a44560a4f0e81b0/packages/sysutils/busybox/scripts/init#L593-L602)

12 GiB試作版にもこれらのU-Boot設定があり、元の配布版の `p3` のGPTエントリ、`extlinux.conf`、カーネル、RG353M用DTBを保持していました。その試作で変更した主な箇所は `SYSTEM` とPID 1の引き渡し、`post-sysroot.sh`、`p4` の拡張・`p5` の追加です。以前の診断で `mmcblk1` が出なかった試行は、Linuxのカード認識段階で止まっていました。診断ログが残っていない黒画面の試行は停止位置が未確定です。次の差分検証では、起動が確認できた再ビルド版のSDレイアウトを基準にユーザランドの差分から確認します。

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

## 初回起動時のストレージ準備

### Bubbleとmini PLUS

1. stock由来の起動領域からカーネルとplumOSの外部initramfsを起動します。外部initramfsの `/init` が、起動元SD、既存パーティションの位置、イメージのマーカーを照合します。
2. 初回は `p3` を8 GiBに拡張し、そのext4ファイルシステムを拡張します。続いて、残りの領域に `p4` を作成し、FAT32の `PLUMOS` として初期化します。作成前に `p3` へ処理の記録を保存し、途中で止まった場合の再開に使います。
3. `p3` を `/storage`、`p4` を `/storage/user` にマウントします。FAT32側に `Roms`・`BIOS`・`Images` などを用意し、`/storage` 側にリンクを作ります。フロントエンドなどの管理Runtimeは `/storage/plumos` に置きます。
4. `/flash` にあるSystem A/Bから起動するSquashFSを選び、`switch_root` でplumOSの `/init` に引き渡します。このPID 1がRuntimeとフロントエンドのチェックサム等を確認し、ランチャーを監視します。ランチャーは設定の初期化、メディアの準備、ライブラリ走査を経て、DRMと入力を使うFEを起動します。

[Bubbleの再開可能な初回準備の実装](https://github.com/game-de-it/plumOS-Bubble/commit/9424a2e) · [mini PLUSのパーティション構成](https://github.com/game-de-it/plumOS-mini-PLUS/blob/baa7143a0bddb1aef5ebc8ee0c8c3358a6aa8d35/docs/developer/architecture.ja.md) · [mini PLUSの外部initramfs](https://github.com/game-de-it/plumOS-mini-PLUS/blob/baa7143a0bddb1aef5ebc8ee0c8c3358a6aa8d35/rootfs/mini-plus-external-initramfs/init) · [mini PLUSのSystem側PID 1](https://github.com/game-de-it/plumOS-mini-PLUS/blob/baa7143a0bddb1aef5ebc8ee0c8c3358a6aa8d35/rootfs/mini-plus-frontend/init)

同じシリーズでも、Pixel2 v2とRK2020は既存のSystem領域 `p2` を8 GiBに拡張し、`p3` にFAT32の `PLUMOS_USER` を作ります。V90S V2とXU20V32は `p4` に利用者用FAT32を作ります。MFはstockのフックからplumOSへ入り、SD上の単一FAT32領域をSystemファイル・Runtime・利用者データで共有します。 [Pixel2 v2](https://github.com/game-de-it/plumOS-pixel2_v2/blob/19e135ba996de5d7b7a7ea915edca5eadc43d225/docs/developer/storage-and-updates.ja.md) · [RK2020](https://github.com/game-de-it/plumOS-RK2020/blob/main/docs/user/storage-and-reimaging.ja.md) · [V90S V2](https://github.com/game-de-it/plumOS-V90S_V2/blob/main/docs/developer/storage-and-updates.ja.md) · [XU20V32](https://github.com/game-de-it/plumOS-XU20V32/blob/main/docs/developer/storage-and-updates.ja.md) · [MF](https://github.com/game-de-it/plumOS-MF/blob/0095017c39226ad1c22bf8df852202673075936d/docs/developer/architecture.ja.md)

### 現在のRK3566試作

利用者用FAT32を初回に生成する処理は未移植です。配布元のJELOSイメージには32 MiBの `p4`（ext4、`STORAGE`）と `.please_resize_me` が含まれます。初回、initramfsはこのマーカーを見て `fs-resize.target` を選びます。JELOSのサービスが既存の `p4` をSD末尾まで広げ、チェックと `resize2fs` を実行し、マーカーを消した状態で再起動します。

実機の起動SDは `mmcblk1` で、パーティションは `p1`〜`p4` の4つです。`p4` が `/storage` にマウントされ、ファイルシステム表示容量は53.9 GiBです。`/storage/user` は存在しません。実機に見えているFAT32の `mmcblk2p1` は別のSDです。[JELOSの初回拡張処理](https://github.com/JustEnoughLinuxOS/distribution/blob/f8cac7b92040d734506e238f5a44560a4f0e81b0/packages/sysutils/busybox/scripts/fs-resize)

通常起動では、U-BootがDTBと `KERNEL` を読み込みます。JELOS initramfsが `/flash/SYSTEM` をマウントし、`post-sysroot.sh` でロゴと配備済みの差分を読み込み、`p4` を `/storage` としてマウントします。ロゴを描画してからsystemdへ `switch_root` します。既定の `jelos.target` はJELOSの自動マウントを実行し、その後に `emustation.service` が試作の `start-frontend` を起動します。USB ADBは同じターゲット内で並行して起動します。[JELOSのinitramfs](https://github.com/JustEnoughLinuxOS/distribution/blob/f8cac7b92040d734506e238f5a44560a4f0e81b0/packages/sysutils/busybox/scripts/init) · [FEのsystemd設定](../prototype/system/usr/lib/systemd/system/emustation.service.d/plumos-353m.conf)

`start-frontend` は `/storage/plumos-353m/frontend` に状態と設定のディレクトリを用意し、未作成の設定に初期値を入れます。FE本体、フォント、テーマ等は `SYSTEM` 側のファイルを参照します。DRMとゲームパッドを待ち、ライブラリ走査に12秒の上限を設けてFEを起動します。実機ではsystemdが自動マウント完了を起動後約11.2秒、FEサービス開始を約14.0秒に記録し、描画完了マーカー `/tmp/plumos-fe-ready` を確認しました。[試作FEランチャー](../prototype/system/usr/lib/plumos-353m/start-frontend)
