# RG353M 試作SDの実機検証

2026年11月22日（JST）。対象は `plumOS-353M-prototype.img`（SHA-256 `9f1a0f132d3a89cb4f133b1b53fdfea3b42cd1e7db8aacbc6d7c258717ec178a`）。mini PLUSのフロントエンドは `baa7143a0bddb1aef5ebc8ee0c8c3358a6aa8d35`。

| 項目 | USB ADBで確認した結果 |
| --- | --- |
| 試作SDからの起動 | 実機モデルはAnbernic RG353M、Linux 4.19.172。試作のフロントエンドリビジョンを読み取れた。 |
| マウント | `/flash` はmmcblk1p3のFAT32、`/` は読み取り専用SquashFS、`/storage` はmmcblk1p4の読み書き可能なext4。初回拡張後の `/storage` は53.9 GiB。 |
| フロントエンド | `emustation.service` はactive。97件のシステム定義をロードし、ライブラリスキャンとインデックス書き出しを完了。 |
| 表示 | フロントエンドが最初の描画完了マーカーを作成。内蔵DSI-1に 640×480 のフレームバッファが割り当てられ、DRMの出力がactive。 |
| USB ADB | `plumos-usb-adb.service` はactive。FunctionFSは `fcc00000.dwc3` にbindし、USBはconfigured。Macからシェルで起動ログを取得。46バイトのテストファイルをpush・pullし、バイト一致を確認。 |
| 起動後のsystemd | 採取時点でfailedのユニットは0件。 |
| ゲームパッド | `retrogame_joypad` からSTART (315)、十字キー上 (544)・下 (545)・右 (547)、フェイスボタンの押下・解放を採取。STARTでトップからメニューへ遷移し、上下でカーソルが0 → 1 → 0と移動。初回の操作ログはフロントエンド上の論理アクションで、その後の押下試験で物理A・Bの逆転を特定した。 |

## A・Bマッピングの修正

本体に印字された A → B → X → Y の順に押して、初版と修正版のevdevコードおよびアクションをUSB ADBで照合しました。

| 本体の印字 | evdevコード | 初版のアクション | 修正版のアクション |
| --- | --- | --- | --- |
| A | 305 (`BTN_EAST`) | `b` | `a` |
| B | 304 (`BTN_SOUTH`) | `a` | `b` |
| X | 307 (`BTN_NORTH`) | `x` | `x` |
| Y | 308 (`BTN_WEST`) | `y` | `y` |

実測と一致するmini PLUSのビルド時設定 `PLUMOS_MINI_PLUS_INPUT` を有効にしました。修正版バイナリをADBで転送し、systemdの一時設定で稼働中のフロントエンドを交換しました。稼働プロセスのバイナリをSHA-256で照合し、AでトップからROM一覧へ進み、Bでトップへ戻ることを画面操作とログの両方で確認しました。XとYのアクションも印字どおりでした。

現在の初版SDに対する一時設定は再起動で解除されます。修正版SDイメージの `SYSTEM` には、この変更を組み込んだバイナリを収録します。

修正版イメージは `plumOS-353M-prototype-r2.img`（SHA-256 `8272d9110c12b1b6ef62a49c61bb757fdb95703b46387f7afe29f2080854a023`）。FAT32から `SYSTEM` を再抽出し、収録したフロントエンドが実機で検証した修正版バイナリとバイト単位で一致することを確認しました。

## 起動時のplumOSロゴ

実機からADBで採取した `/etc/issue` に、起動時のJELOSのブロック文字が入っていました。カーネル内のinitramfsを展開し、`load_splash` が `SYSTEM` の `/etc/issue` を既存のコンソールへ出す箇所を確認しました。r3では `SYSTEM` 内のこのファイルをplumOSの文字ロゴに差し替えています。U-Bootやカーネルの変更は不要です。

ビルドでは、完成イメージのFAT32から `SYSTEM` を読み戻し、収録した `/etc/issue` をソースと比較します。r3を書き込んだSDでの起動時目視確認は未実施です。

r3のSHA-256は `62120d0cf4740dc48162484e1dd57c18d00d0315daef681753e6c0665cbbbc22`。FAT32から読み戻したロゴはソースと一致し、フロントエンドとADBのバイナリはr2とバイト単位で一致しました。

### 既存SDへのADB更新

初版の試作SDを挿した状態で、USB ADBからr3の `/etc/issue` とA・B修正済みフロントエンドを約1.6 MBの差分として転送しました。JELOSの `post-sysroot.sh` は、ブート時に `load_splash` が走る前に、この2ファイルを読み取り専用の `SYSTEM` の該当パスへバインドします。

同じSDのまま `systemctl --no-block reboot` を実行し、新しいブートIDとADBの再接続を確認しました。再起動後の `/etc/issue` と実行中のフロントエンドのSHA-256は、転送したファイルと一致しました。フロントエンドとADBはactiveで、初回描画完了マーカーが作成されました。

### フロントエンドの再起動とシャットダウン

本体のリセット後にUSB ADBが接続できることを確認しました。初版のフロントエンドでは、再起動とシャットダウンのメニューが呼ぶ `plumos-safe-shutdown` が配備されていませんでした。JELOSのsystemdへ再起動と電源断を渡すヘルパーを追加し、USB ADBで既存SDに転送して、フロントエンドから参照できる場所に有効化しました。

実機上のフロントエンドのメニュースクリプトで、確認入力を経た再起動とシャットダウンがそれぞれ `reboot` と `poweroff` に解決されることをドライランで確認しました。修正後の実電源断は未実施です。

### Bubbleのグラフィック起動ロゴ

Bubble `ec81d42c0c2c39e7a32973bfe4df9b3027512a5d` の `boot-splash.png` と、ビルドに使うmini PLUSの画像は、SHA-256 `f55f1ad088fe842217f4d62153978c5227c470807303d266ecd6badcba7a553d` で一致しました。色と画素寸法を保ったままXRGB8888に変換し、静的リンクしたAArch64の描画プログラムとともにADBで転送しました。[Bubbleの起動画像](https://github.com/game-de-it/plumOS-Bubble/blob/ec81d42c0c2c39e7a32973bfe4df9b3027512a5d/package/frontend-bubble/plumos/config/frontend/boot-splash.png)

既存の `post-sysroot.sh` から、initramfsの `load_splash` が画像を描画するようにしました。同じ試作SDからの再起動後に描画成功マーカー、フロントエンドの初回描画マーカー、ADB接続を確認し、実機の液晶に画像が表示されたと利用者から確認を得ました。

### 作業ディレクトリの改名

作業ツリーと `.git` を `/Users/kroot/plumOS-353M` から `/Users/kroot/plumOS-RK3566` へ移動しました。改名前後でHEAD `557a862fe340b68118c67d0295f51da96ef60a8d` と全8コミットの一覧を照合し、`git fsck --full` を通過しました。

新しいディレクトリからフロントエンドと起動画像の描画プログラムをビルドし、USB ADBで既存のSDへデプロイしました。同じSDから再起動した後に、今回の配備先からフロントエンドがマウントされ、実行中のバイナリのSHA-256が新しいビルドと一致することを確認しました。起動画像の描画マーカーがあり、フロントエンドとADBの両サービスがactiveでした。

移動した作業ツリーのJELOSイメージを展開し、新しいパスから `build-image.sh` を実行しました。完成イメージのSHA-256、FAT32上の起動フック、`SYSTEM` の読み戻しを照合し、収録されたフロントエンドと起動画像の描画プログラムもビルド出力とバイト単位で一致しました。このイメージはMac上で検証し、実機では既存SDへのADB差分デプロイを検証しました。

### BubbleのDockerビルド環境

MacにDocker Desktop 4.99.0をインストールしました。Docker Engine 29.9.3でBubble `ec81d42c0c2c39e7a32973bfe4df9b3027512a5d` のDockerfileを使い、`linux/arm64` の `plumos-rk3566-bubble-tools:ec81d42` を構築しました。

`prototype/build-frontend-docker.sh` でJELOSの共有ライブラリを使ってフロントエンドとライブラリスキャナーをビルドしました。生成物はAArch64 ELFで、Dockerコンテナ内で両方の `--help` の実行を確認しました。RG353Mでは既存SDのジャーナル待ちが継続しており、PID 1試作の実機配備は未検証です。

### plumOS PID 1のSDイメージ

初回書き込み用に `plumOS-RK3566-rg353m-pid1-prototype.img` を作成しました。JELOSのカーネル、DTB、ブート領域とGPTは元イメージと比較しました。FAT32から `SYSTEM` を読み戻し、JELOSの引き渡し先からplumOS initへのリンク、初回拡張スクリプト、DockerでビルドしたFE・スキャナー、Bubble由来の初回進捗フレームを照合しました。

Dockerの別テストでは、元イメージの複製を拡大した後にGPTの既存 `p4` を拡張し、取り出したext4を新しい容量へ拡張しました。UUIDの維持と、GPTが4区画のままであることを確認しました。この段階の初回セットアップは既存のext4拡張までです。利用者用FAT32の作成と、完成SDからのRG353M実機起動は未検証です。

イメージのSHA-256は `7c23a956f6c49cdc92b05ba974f2254f928c266c18c1cf60cfc7ae065bbe5bc2` です。

### RG353Mで電源断が起きたSDの読み戻し

利用者の報告では画面は起動直後から暗く、電源断の直前に短いメッセージが表示されました。文面は未採取です。

- Macから物理SDを読み取り専用で調べました。`p3` 全体のSHA-256は配布イメージの同じ範囲と一致し、`fsck_msdos -n` は正常終了しました。`p4` も配布イメージとバイト一致し、ext4の検査は正常でした。マウント回数は0で、`.please_resize_me` が残り、`init.log` はありませんでした。SD上に `/storage` のマウントや初回拡張に到達した痕跡がありません。
- SDの先頭16 MiBは3セクタに差分があり、いずれもRockchipのVendorStorage領域です。先頭のGPT、U-Bootの `p1`、機種識別データの `p2` は配布イメージと一致しました。[Rockchip U-BootのVendorStorage定義](https://github.com/JustEnoughLinuxOS/rk356x-uboot/blob/97c658238f7ccd436fbdede451bfd7488514a5c8/arch/arm/mach-rockchip/vendor.c#L12-L28)
- macOSはバックアップGPTの位置について警告しました。配布イメージの複製を実カードと同じ62,914,560,000バイトに広げたDocker上の試験では、Linuxが4パーティションすべてを認識し、JELOS initramfsのBusyBoxで `boot=` と `disk=` のUUIDに従って両方を読み取り専用マウントできました。`SYSTEM` のSquashFSマウントとplumOS initの構文確認も通りました。この検証環境のLinuxはRG353M上のカーネルと異なります。[Linux 4.19のGPT検証](https://github.com/torvalds/linux/blob/v4.19/block/partitions/efi.c#L600-L621)
- 実機のJELOS initramfsは `/flash`、`SYSTEM`、`/storage` いずれかのマウントを繰り返し試みて失敗すると電源を切ります。今回の停止箇所の確定には、電源断直前の画面メッセージが必要です。[JELOS initramfsのマウント処理](https://github.com/JustEnoughLinuxOS/distribution/blob/f8cac7b92040d734506e238f5a44560a4f0e81b0/packages/sysutils/busybox/scripts/init#L113-L130)

### 電源断メッセージとRG353M用の診断設定

利用者の写真で `Unable to find UUID=0602-1646` を確認しました。これは `boot=` で指定したFAT32の `/flash` をJELOS initramfsがマウントできなかったときの表示です。この表示はUUIDの検索失敗と、デバイス発見後のマウント失敗を区別しません。

`prepare-rg353m-boot-diagnostics.sh` は既存の `extlinux.conf` からRG353M用の診断設定を生成します。以前の実機で確認したTF1の `/dev/mmcblk1p3` を `boot=` に指定し、`debugging` でマウントコマンドのエラーを画面に出します。`disk=` のext4 UUIDと `FDTDIR` は元の設定を使います。配布イメージの複製上でFAT32に書き込み、読み戻した設定の一致を確認しました。

物理SDの `extlinux/extlinux.conf` をMacに退避し、同じSDの該当ファイルに診断設定を適用しました。読み戻しで一致を確認して取り出しました。この設定は特定機種の切り分け用として物理SDにのみ適用しています。

### MMCの認識状況を出す診断起動

次の写真では `/dev/mmcblk1p3` を `/flash` にマウントする処理が `No such file or directory` で失敗しました。JELOSは先に `/flash` を作るため、Linux側でのデバイス認識を調べます。このエラーだけでは、SD本体とパーティションのどちらが見えていないかは確定できません。

`build-sd-probe.sh` で小さい外部initramfsを生成し、同じカードのFAT32に配置しました。カーネル内の設定で初期RAMディスクとgzip対応を確認し、JELOSのBusyBoxに必要なコマンドが揃うこと、FAT32から読み戻した診断ファイルと設定が一致することを確認しました。元のUUID指定に戻し、診断が読み取り専用でブート領域を開ける場合はJELOSの `/init` に引き渡します。失敗時はMMCパーティション、ファイルシステムとカーネルメッセージを画面に残します。実機での診断出力は採取待ちです。[Rockchip U-BootのINITRD読み込み](https://github.com/JustEnoughLinuxOS/rk356x-uboot/blob/97c658238f7ccd436fbdede451bfd7488514a5c8/cmd/pxe.c#L608-L618)

### 診断画面で確認したTF1の状態

診断用の外部initramfsが実機で動作しました。起動SDから診断ファイルを読めたため、U-Bootからの読み出しは成功しています。Linux側の画面には内蔵eMMCの `mmcblk0` とTF2の別カード（`mmcblk2`、14.5 GiB）が表示され、TF1のカード `mmcblk1` とブート領域のUUIDは確認できませんでした。画面に残ったカーネルログは末尾9件のみで、TF1の初期化メッセージは採取できていません。

元のJELOSと配布用試作イメージから `KERNEL`、RG353M用DTB、`extlinux.conf` を再抽出し、ファイルごとのSHA-256がすべて一致することを確認しました。JELOSのRG353M用DTBでは `mmc1` が `/dwmmc@fe2b0000` に対応し、ノードは有効です。物理カードには一時的な診断用 `INITRD` と `rdinit=` の設定を適用中です。この検証でカーネルとDTBの書き換えは行っていません。

### JELOSのSD起動と内蔵Androidの共存

ROCKNIXのRG353向け説明では、旧ブートローダーを持つeMMCモデルの制約が記載され、P/M/Vの導入手順は内蔵eMMC全体を消去する内容です。[ROCKNIXのRG353向け説明](https://rocknix.org/devices/anbernic/rg353pmvvs/#installation)

JELOS 20240206のRockchip用イメージ生成処理は、SDのLBA 64に `idbloader`、LBA 16384にU-Boot FIT、LBA 24576に機種識別用データを書き込みます。JELOSが採用するRockchip U-Bootは、SDのIDBを検証する分岐と、SDをeMMCより先に検索する既定の起動順を持ちます。`rkimgtest` はLBA 64の先頭を読み、実イメージにある `RKNS` を有効なIDBヘッダーとして受理します。[JELOSのイメージ生成](https://github.com/JustEnoughLinuxOS/distribution/blob/f8cac7b92040d734506e238f5a44560a4f0e81b0/projects/Rockchip/bootloader/mkimage#L6-L30) · [Rockchip U-Bootの起動順](https://github.com/JustEnoughLinuxOS/rk356x-uboot/blob/97c658238f7ccd436fbdede451bfd7488514a5c8/include/configs/rockchip-common.h) · [IDBの検査](https://github.com/JustEnoughLinuxOS/rk356x-uboot/blob/97c658238f7ccd436fbdede451bfd7488514a5c8/cmd/rkimgtest.c#L26-L54)

元のJELOS、起動実績のあるr3試作、現PID 1試作、物理SDの既存ダンプで、LBA 64からVendorStorageの手前まで、U-Boot FITを含む `p1`、機種識別用の `p2` をそれぞれSHA-256で照合し、すべて一致しました。3つのイメージに含まれるカーネル、RG353M用DTBと既定の `extlinux.conf` も一致しました。どの媒体の最初のローダーが実行されたかはシリアル起動ログ未採取のため確定していません。診断用initramfsの実行からSD上の起動ファイルが読み込まれたことは確認できます。観測された停止はLinuxに切り替わった後のTF1認識段階です。

### 同じRG353MでのJELOS再起動対照試験

以前起動していたJELOSのSDで再起動し、SSHでLinux 4.19.172のログを読み取りました。TF1は `mmc1` がSDXCをSDR104で初期化し、起動後約1.17秒で115 GiBの `mmcblk1` を認識しました。`p1`〜`p4` が見え、`p3` は `/flash`、`p4` は `/storage` にマウントされました。内蔵eMMCは `mmcblk0`、TF2の14.5 GiBカードは `mmcblk2` として見えています。

稼働中の `/flash/KERNEL` とRG353M用DTBのSHA-256は、JELOS元イメージとPID 1試作イメージの値に一致し、`boot=` と `disk=` のUUIDも一致しました。現在起動できたJELOSの115 GiBカードと、認識されなかった試作の約58.6 GiBカードは別媒体です。この比較で、同じ本体と同じカーネル・DTBでTF1が動作することを確認できました。試作カードの初期化が失敗する理由は未特定です。

### 同じ試作SDのTF2挿入試験

JELOSをTF1の既知正常カードで起動したまま、TF2の既存カードをアンマウントして約58.6 GiBの試作SDに差し替えました。JELOSのホットプラグ自動マウントを一時停止し、試験後に元の設定へ戻しました。

同じLinux 4.19.172が試作SDをTF2でSDR104のSDXCとして認識し、`mmcblk2p1`〜`p4` を列挙しました。`p3` と `p4` のFAT32/ext4のUUIDを確認し、`p3` を読み取り専用でマウントして `KERNEL` とRG353M用DTBのSHA-256を配布イメージの値と照合しました。`SYSTEM` の存在も確認し、試験後はアンマウント済みです。

LinuxはバックアップGPTが物理末尾にないという警告を出しましたが、全パーティションを認識しました。同じカードと同じカーネルでTF2から読めるため、次の切り分けはTF1でのコールドブート時のカード検出と初期化です。今回の結果はTF1での接触、初期化条件、媒体の相性のいずれかを単独で確定するものではありません。

### TF1のコールドブート時にログを採る設定

外部診断ファイルの出力をTF1の `mmc1`、`mmcblk1`、`fe2b0000` に絞りました。カード本体が見えているかを画面に表示し、ブート領域を読めれば診断の結果をカーネルログに書いてJELOSの `/init` に進みます。読めない場合は直近11件のTF1関連ログとマウントエラーを画面に残します。起動できたJELOSの対照ログで、フィルターがTF1のクロック設定、チューニング、SDXCとパーティションの認識を拾うことを確認しました。

JELOSをTF1で動かしたまま、SSHからTF2に挿した試作カード上の `plumos-sd-probe.cpio.gz` だけを更新しました。同カードの識別情報と旧ファイルを確認してから更新し、アンマウント後に読み取り専用で再マウントして、新しいアーカイブのSHA-256と従来の診断用 `extlinux.conf` の一致を確認しました。SD全体の再書き込みは行っていません。試作SDはTF2でアンマウント済みです。

### TF1で試作SDを認識した起動

TF2を空にした試作SDのコールドブートでは、起動後1.542秒にTF1がSDR104のSDXCを認識し、1.552秒に `mmcblk1p1`〜`p4` を列挙しました。報告容量はTF2試験時と同じ58.6 GiBでした。`vmmc-supply` が見つからないという表示は、正常起動したJELOSの対照ログにもあります。この起動では画面の `Boot mount error` の後にエラー本文がなく、診断の最後のマウント処理が失敗したとの証拠はありません。

旧診断では、`SYSTEM` の読み出し確認に失敗した後や最後にマウントできた場合でも診断画面で止まる分岐がありました。再試行と最後の確認の両方で、読み取り専用マウント、`SYSTEM` の読み出し可否、アンマウントを確認し、成功すればJELOSに引き渡すよう修正しました。模擬試験では、2回目または最後の確認で読み出し可能になったときに引き渡すことを確認しました。

実機の再試験用には、同じ試作SDの `extlinux.conf` を元のJELOSと同じバイト列に戻し、読み戻しで照合しました。診断アーカイブはカードに残っていますが、この設定では呼び出されません。JELOSカーネル内蔵のinitramfsが通常どおり `SYSTEM` を開く構成です。

### 無表示で電源断した試行とUSB復旧経路

元のJELOS起動設定へ戻した試行では、画面にメッセージが出る前に電源が切れたと報告がありました。直後の物理SDの `p4` を読み出したところ、配布イメージの32 MiBのext4とバイト一致し、マウント回数は0、初回拡張マーカーも残っていました。

JELOS組み込みinitramfsのBusyBoxを実行して確認すると `seq`、`ln`、`rmdir` がありませんでした。旧診断の待機ループは `seq` の不在で試行を繰り返していませんでした。シェルのカウンターへ置き換え、USB復旧用アーカイブには既存のRG353M向けADBランチャー、静的adbdと、必要なアプレットを備えた別の静的BusyBoxを同梱しました。ARM64 Docker内で実際のJELOS initramfsと結合し、USBランチャーに渡すアプレットの解決とリンク作成を確認しました。RG353Mのカーネル設定にはDWC3、configfs、FunctionFSが組み込まれていますが、復旧ADBの実機接続は未確認です。

診断用の設定では、TF1のブート領域が読めるとJELOSの `/init` に渡します。その前後にTF1の読み出し、JELOSの `/flash` と `SYSTEM` のマウント、`switch_root` 前の到達点をブート領域の `plumos-boot-trace.log` に追記します。TF1を開けない場合は起動を止めてUSB復旧ADBを開始します。USB復旧機能と到達点の記録は診断用ファイルで、配布イメージの既定の起動設定には組み込んでいません。
