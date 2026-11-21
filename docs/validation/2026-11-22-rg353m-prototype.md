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
