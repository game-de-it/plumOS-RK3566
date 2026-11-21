# plumOS-353M 試作

RG353Mの内蔵液晶とゲームパッドで、GKD mini PLUS由来のplumOSフロントエンドを確認するためのイメージです。mini PLUSのコミット `baa7143a0bddb1aef5ebc8ee0c8c3358a6aa8d35` を使用しています。ゲーム・エミュレーター・機種固有メニューの移植はこの試作の検証対象外です。

## ADBでの実機更新

既に起動できる試作SDを開発用に使います。アプリや設定はUSB ADBで転送し、サービス再起動で反映できる変更はその場で確認します。起動時に読まれる変更はADBで配置し、同じカードを差したまま再起動して確認します。イメージの書き直しは、新規カードを作る場合や、現在のSDへADBで安全に適用できない変更がある場合に行います。

初版の試作SDへr3のロゴとA・Bの修正を反映する例です。`build-frontend.sh` で生成済みの修正版バイナリを指定します。

```sh
./prototype/deploy-boot-overlay.sh /path/to/compiled/plumos-controller-ui
./output/adb shell 'systemctl --no-block reboot'
./output/adb wait-for-device
./output/adb shell 'cat /etc/issue; cat /tmp/plumos-fe-ready'
```

デプロイは転送内容をSHA-256で確認し、JELOSの `post-sysroot.sh` に、ロゴとフロントエンドの2ファイルを読み込む設定を置きます。起動時の照合に失敗した場合は内蔵の `SYSTEM` のファイルで起動します。独自の `post-sysroot.sh` を先に置いている場合は、その内容を調べてから組み合わせます。

## 新規SDカードと実機確認

1. `output/plumOS-353M-prototype-r3.img` を予備のmicroSDに書き込み、RG353MのTF1へ挿します。r3には起動時のplumOSロゴと、r2の物理A・Bの割り当て修正を含みます。評価時はTF2を空にして起動経路を単純にします。
2. フロントエンドが表示されたら、十字キーでカーソルを移動し、STARTでメニューを開き、Aで項目を開いてBで戻れるか確認します。表示の向きも確認します。
3. Macをロック解除して、データ通信対応のUSBケーブルでRG353MのOTG端子と接続します。macOSにアクセサリの接続許可が表示されたら許可します。

Macでの確認とアプリの転送例です。コマンドはプロジェクトのディレクトリから実行します。

```sh
(cd output && shasum -a 256 -c plumOS-353M-prototype-r3.img.sha256)
./output/adb devices -l
./output/adb shell 'cat /tmp/plumos-fe-ready; cat /proc/cmdline'
./output/adb shell 'journalctl -b -u emustation.service -u plumos-usb-adb.service --no-pager'
./output/adb shell 'tail -n 25 /run/plumos-353m/frontend-actions.log'
./output/adb shell 'mkdir -p /storage/plumos-353m/apps'
./output/adb push ./my-app /storage/plumos-353m/apps/
./output/adb shell 'ls -l /storage/plumos-353m/apps/my-app'
```

ADBはUSB専用で、試作機のrootシェルを認証なしで公開します。手元で管理する開発機用です。アプリと試作フロントエンドの設定は `/storage/plumos-353m` に置かれます。画面を使うアプリを手動で起動する際は、先に `systemctl stop emustation.service` でフロントエンドを終了し、アプリ終了後に `systemctl start emustation.service` で戻します。

## 書き込み前の実機検証

元のJELOSを起動したRG353Mで、一時サービスからフロントエンドを動かして確認しました。最初の描画完了マーカーが作成され、プロセスが内蔵液晶用のDRMと`retrogame_joypad`のevdevを開きました。USB ADBはMacからrootシェルを実行でき、テストファイルをpush・pullしてバイト一致を確認しました。その後、試作SDでの起動、表示、実ボタンによる画面遷移を[実機検証記録](../docs/validation/2026-11-22-rg353m-prototype.md)にまとめました。

## Git履歴から反映した対策

| 繰り返し出た症状 | 参照コミットと今回の対策 |
| --- | --- |
| ロゴ停止、デバイスが複数同時に消失 | RK2020 `b42f34f`・`aa28666`、Pixel2 `1f27134`。JELOSのGPT、ブート領域、カーネル、DTB、extlinux、storageを照合し、更新したSquashFSをFATから再抽出して照合する。 |
| 初回ストレージ処理やネットワーク待ちで画面が出ない | MF `8934ba5`・`2d2cce8`・`ad0af44`、mini PLUS `ee3a984`、Bubble `bac590e`、V90S `0391a28`。JELOSの既存マウント経路を使い、フロントエンドはWi-FiやTF2に依存させず、デバイス待ちとライブラリ走査に上限を設ける。 |
| 黒画面、描画の取り合い、表示と入力のずれ | Bubble `f682c81`、RK2020 `0f499d6`、Pixel2 `c55da25`。JELOSの既存サービスから1プロセスだけ起動し、画面は内蔵DSIを優先するmini PLUSのDRM描画、入力は実機のudevパスを使う。 |
| USBは見えるがADBが応答しない | Pixel2 `ecf4d16`・`758dfbd`、MFのADB管理スクリプト。FunctionFSの準備を待ってRG353MのDWC3にbindし、USB切断でbindが解除された場合は再取得する。 |
| アーカイブやビルドが成功しても起動ファイルが古い | mini PLUS `427c28a`、MMF `b4673b7`、XU20V32 `c3a3547`。実際のsystemd起動パスとADBの有効化リンクを完成イメージのSquashFSで確認する。 |

参照した履歴は **Bubble、mini PLUS、MF、pixel2_v2、RK2020、V90S V2、XU20V32、A30、MMF**。各機種のコミットを調べる際は、mini PLUSの `plumOS_gitlog_problem_solution_guide.ja.md` も併用しました。

## ビルド入力

- JELOS 20240206 RK3566のrawイメージ。元の `SYSTEM` のMD5は `44d5c32ff0154fa8375ed45eff14a9c5`。
- macOS ARM64用 Zig 0.15.2、SquashFS Tools 4.7.5（LZO有効、macOSでは `st_atim=st_atimespec`）、mtools 4.0.49。
- Debian bookworm ARM64の `libpng-dev`、`libfreetype-dev`、`libdrm-dev`、`zlib1g-dev` のヘッダ。リンク対象はJELOS由来の共有ライブラリ。
- Standalone Linux adbd `v36.0.1-linux.2` のARM64静的ビルド。使用した配布tarballのSHA-256は `ba3935056777932addc3de1cdbd25194f0942f796575b5ea5668a9ef32c95117`。[ソースとビルド情報](https://github.com/happyme531/standalone-linux-adbd/tree/v36.0.1-linux.2)

ビルドスクリプトは作業ディレクトリの `tools/`、`refs/mini-PLUS/`、`debian/sysroot/` に上記の入力があることを前提にします。`build-frontend.sh` でバイナリを作り、`build-image.sh` で既知のJELOSイメージから組み立てます。
