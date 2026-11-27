# JELOS 20240206の機種自動判定

共通SDイメージの生成経路では、既存の機種判定に加え、RGB30のCPUレギュレーターに応じてr1用またはr2用のDTBを選びます。[RGB30の共通SDイメージ](validation/2026-11-25-rgb30-unified-image.md)

## plumOS-RK3566の実機確認状況

| メーカー | 機種 | 現行イメージでの状況 |
| --- | --- | --- |
| Anbernic | RG353M | 実機で起動、フロントエンド、ADBを確認済み |
| Anbernic | RG353V | 共通SDでplumOS init、FE、p5、USB ADBを確認。修正版SYSTEMでSD2とROM・BIOSの公開を確認 |
| Anbernic | RG353P | 機種別DTBを同梱。plumOSでの実機起動は未確認 |
| Anbernic | RG503 | 共通SDで960×544のFEとTF2を確認。174プロファイルの表示、Appsの起動、USB給電中のスリープ復帰をWi-Fi SSHで検証。別のケーブルでUSB ADBのシェル接続とファイル往復も確認。[実機結果](validation/2026-11-25-rg503-runtime.md) |
| Powkiddy | RGB30 r1・r2 | 同一SDでDTBの自動切り替え、plumOS init、FE、p5、USB ADBを両機で確認。r2ではSD2も確認 |
| Powkiddy | RK2023 | 共通SDで640×480のFE、SD2、174エミュレータプロファイルの起動、Apps、USB給電中のスリープ復帰を確認。MacではADBの `NATIVE` 方式で接続した。[初回起動](validation/2026-11-25-rk2023-boot.md) · [実機動作試験](validation/2026-11-25-rk2023-runtime.md) |
| Powkiddy | RGB10 Max 3 | 機種別DTBを同梱。v0.1.2の実機写真でBubbleの起動と90度の表示ずれを確認。修正後の実機試験は未実施。[表示方向の検証](validation/rgb10max3-display.md) |
| Anbernic | RG353VS | JELOS 20240206の対応表に掲載。専用名のDTBは未収録で、plumOSでの実機起動は未確認 |

RG353Vでは共通SDの起動とSD2を確認した。修正版IMGでは、USBを接続したままの再起動とシャットダウン後の電源投入、起動後のUSB ADBも確認した。エミュレータ、Apps、USB DAC、スリープの試験結果も記録した。[RG353Vの共通SD起動とSD2](validation/2026-11-25-rg353v-sd2.md) · [USB接続中の電源投入](validation/2026-11-25-rg353v-usb-cold-boot.md) · [エミュレータ・Apps・電源管理](validation/2026-11-25-rg353v-runtime.md)

共通イメージのSD2マウント処理は、起動時のDTBの `mmc2` エイリアスとsysfsを使ってTF2のカードを特定する。同梱する全DTBでTF2の割り当てを照合した。[全機種のSD2とRG503の検証](validation/2026-11-25-rg503-sd2.md)

フロントエンドの製品名は `plumOS-RK3566`、設定に表示する機種欄は `RK3566`。同じイメージで使う共通の表示名で、実際に選ばれた機種は `/proc/device-tree/model` で確認できる。

2026年11月24日にRG353Mで表示名を更新したSYSTEMを試験した。STARTメニューの見出し、SYSTEM SETTINGSのINFORMATIONにある機種名と表示方式、USB ADBの製品名を確認した。カーネルとRG353M用DTBのSHA-256は試験前後で一致し、利用者用のp5は `/storage/user` にマウントされた。USB ADB経由で試験起動したSYSTEM `0acf15b3524b27891fc84f63460945b58f82530434d53c2ed2a5a3304703a464` を既定に設定した。

### RGB30の初回試験

2026年11月24日。ユーザーが実機のFE表示、起動ロゴの欠落、SD2の内容が表示されないこと、720×720画面の下部に余白があることを確認した。MacからはWi-Fi経由でFTP共有とSSHの待受に接続できた。SSHは公開鍵認証で止まり、MacのUSB一覧にADBデバイスは出なかった。

- 実機ログでDTのモデル `Powkiddy RGB30`、カーネル4.19.172、plumOS init、FEの準備完了を確認した。RG353Mで試験した同じSYSTEMハッシュが選ばれた。TF1のp3、p4、p5がそれぞれ `/flash`、`/storage`、`/storage/user` にマウントされている。
- DSIは720×720、fb0は32ビットで仮想サイズ720×1440。ロゴの状態は `framebuffer unavailable`、初回セットアップ描画の消去も失敗していた。[ロゴと消去の実装](../prototype/boot-splash.c)は640×480を要求する。
- カーネルはTF2カードを `/dev/mmcblk2p1` として認識した。 `/run/media/sd2` は未マウントで、FEはTF1のp5を走査していた。[SD2のマウント処理](../prototype/boot-system/manage-sd2)はRG353Mだけで起動する。
- FEの既定グリッドは3列×2行で、タイルの大きさを画面幅で制限する。720×720では2行を描いた後も画面下部に余白が残る。
- 本体の `adbd` とFunctionFSは起動し、コントローラー `fcc00000.dwc3` にバインド済みだった。採取時のUSB状態は `not attached` だった。Macへの列挙に至らなかった原因は未確定。
- ゲームパッド、電源キー、RK817のALSA再生デバイスは列挙された。ゲーム内の入力、実際の音声出力、スリープ復帰は未試験。
- 一度の再起動要求で、FEのオーバーレイを `Device or resource busy` でアンマウントできず、initが再起動を中止してFEとWi-Fiを復帰させた。オーバーレイを保持していたプロセスは未特定。

### RGB30の表示・SD2修正

RGB30の実測に合わせて、起動ロゴと初回セットアップの画像を画面の比率を保って描画し、終了時は仮想画面全体を消去する。FEは正方形画面で3列×3行を使い、テキスト一覧とROM一覧の表示件数を画面の高さに合わせる。RGB30では、TF2の `mmcblk2p1` をSD2として公開する。再起動の際は、ネットワークサービスを停止した後、オーバーレイ上の実行ファイルやマッピングを保持するプロセスも停止してからアンマウントする。

既存SDを更新し、カーネル・RGB30用DTB・extlinux設定のSHA-256が前後で一致した。試験起動したSYSTEMで `framebuffer: 720x720 XRGB8888` と消去成功、FEの3段目の選択、SD2の読み書きマウントとROM・BIOSのバインドを確認した。

USB ADBはMacで実際に接続とシェル実行ができた。再起動後にPHYが給電専用の `DCP=1` と報告した場合は、FunctionFSが正常にバインドしていてもMacへ列挙されなかった。gadgetの再起動だけでは、このPHY状態は変わらなかった。

表示・SD2修正版で、オーバーレイ上の実行ファイルを保持するプロセスを用意して再起動を要求したとき、一度電源が落ちた。ユーザーが電源を入れ直し、plumOSの画像ロゴが表示された。次回起動のログには正常終了の記録があった。

### RGB30の再起動とUSB ADB

電源が落ちたRGB30では、RK817の電源レール設定を保存する2バイトが `0x7f/0x00` だった。RGB30のDTはU-Bootに保存させない設定だが、JELOSのBSPカーネルは第1バイトが非ゼロなら以前の値を再起動時に読み戻す。RGB30で機種名、PMICの種類、DTフラグを照合し、再起動・シャットダウンの前にこの保存領域だけを消去する処理をplumOS initに追加した。実機で消去と読み戻しを確認した後、電源ボタンを押さずに再起動できた。同じBSP処理を持つ別機種でも、同じ保存値による再起動障害が報告されている。 [GammaOS Nextのカーネル修正](https://github.com/TheGammaSqueeze/rg_ds_kernel/commit/7ecfef9)

組み込み版SYSTEM `970aa332cad0d3fc90776f23daa17bfc94d12863088e3a222b52c0dcf582c82b` を試験起動し、正常判定を得て既定に設定した。前回と同様にFEのオーバーレイ上の実行ファイルを保持するプロセスを用意して再起動したところ、そのプロセスが停止し、電源ボタンを押さずに同じSYSTEMが立ち上がった。正常終了の記録、SD2の再マウント、FE、Wi-Fiの復帰を確認した。カーネル、RGB30用DTB、extlinux設定のSHA-256は表示修正時の値と一致した。

USB ADBは、RGB30側のOTG端子でケーブルを挿し直した際に `DCP`（給電専用）から `CDP`（給電とデータ）へ変化した。MacでADBの列挙とシェル接続を確認した。NWサービスの設定操作は不要だった。同じMacのUSBハブにつないだまま再起動すると再び `DCP` になった。PHYの一時的なperipheral設定とgadgetの再起動では、`DCP` の状態を変えられなかった。試験終了時に一時SSH鍵と登録用スクリプトを削除した。

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

以下はsystemdを使っていた初期試作の記録です。現行のPID 1とパーティション構成は[現行のシステム構成](rk3566-runtime.md)を参照してください。

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

### 初期のRK3566試作

利用者用FAT32を初回に生成する処理は未移植です。配布元のJELOSイメージには32 MiBの `p4`（ext4、`STORAGE`）と `.please_resize_me` が含まれます。初回、initramfsはこのマーカーを見て `fs-resize.target` を選びます。JELOSのサービスが既存の `p4` をSD末尾まで広げ、チェックと `resize2fs` を実行し、マーカーを消した状態で再起動します。

実機の起動SDは `mmcblk1` で、パーティションは `p1`〜`p4` の4つです。`p4` が `/storage` にマウントされ、ファイルシステム表示容量は53.9 GiBです。`/storage/user` は存在しません。実機に見えているFAT32の `mmcblk2p1` は別のSDです。[JELOSの初回拡張処理](https://github.com/JustEnoughLinuxOS/distribution/blob/f8cac7b92040d734506e238f5a44560a4f0e81b0/packages/sysutils/busybox/scripts/fs-resize)

通常起動では、U-BootがDTBと `KERNEL` を読み込みます。JELOS initramfsが `/flash/SYSTEM` をマウントし、`post-sysroot.sh` でロゴと配備済みの差分を読み込み、`p4` を `/storage` としてマウントします。ロゴを描画してからsystemdへ `switch_root` します。既定の `jelos.target` はJELOSの自動マウントを実行し、その後に `emustation.service` が試作の `start-frontend` を起動します。USB ADBは同じターゲット内で並行して起動します。[JELOSのinitramfs](https://github.com/JustEnoughLinuxOS/distribution/blob/f8cac7b92040d734506e238f5a44560a4f0e81b0/packages/sysutils/busybox/scripts/init) · [FEのsystemd設定](../prototype/system/usr/lib/systemd/system/emustation.service.d/plumos-353m.conf)

`start-frontend` は `/storage/plumos-353m/frontend` に状態と設定のディレクトリを用意し、未作成の設定に初期値を入れます。FE本体、フォント、テーマ等は `SYSTEM` 側のファイルを参照します。DRMとゲームパッドを待ち、ライブラリ走査に12秒の上限を設けてFEを起動します。実機ではsystemdが自動マウント完了を起動後約11.2秒、FEサービス開始を約14.0秒に記録し、描画完了マーカー `/tmp/plumos-fe-ready` を確認しました。[試作FEランチャー](../prototype/system/usr/lib/plumos-353m/start-frontend)
