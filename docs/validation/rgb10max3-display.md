# RGB10 Max 3の内蔵画面

v0.1.2の実機写真では、Bubbleの上辺が本体の右側に表示されている。JELOS 20240206で使用するRGB10 Max 3用のBSPデバイスツリーは、DSIのネイティブモードを720×1280としている。JELOSはSDL2のKMSDRMにパネルの向きを渡し、librgaで回転していた。現在のROCKNIXのRK3566設定はSwayを起動し、パネルの向きを表示サーバーで扱う。Linuxのメインラインにもこの機種固有のパネル向きが登録されている。 [ROCKNIXのRK3566表示設定](https://github.com/ROCKNIX/distribution/blob/0f4806b59bfd1d3e6b17e3a632e95ced82a28719/projects/ROCKNIX/packages/hardware/quirks/platforms/RK3566/090-ui_service) · [ROCKNIXのパネル向きの説明](https://rocknix.org/contribute/quirks/) · [Linuxのデバイスツリー](https://github.com/torvalds/linux/blob/master/arch/arm64/boot/dts/rockchip/rk3566-powkiddy-rgb10max3.dts)

plumOSではRGB10 Max 3の縦型表示に合わせ、横長の各ピクセル `(x, y)` をネイティブ座標の `(y, width - 1 - x)` に配置する。Bubbleの共有DRMレンダラーを使う画面とPicoArchに共通の補正を適用する。RetroArchのソフトウェアDRM経路ではコアの回転を維持し、ゲーム・RGUI・OSDをパネルに合わせる。DraSticの描画ランナーはゲームとメニューの合成時に回転し、PPSSPPの直接表示Vulkan経路はネイティブのスワップチェーンに回転して描画する。

Bubble、PicoArch、RetroArch、DraSticの描画ランナー、PPSSPPをARM64 Dockerでビルドした。Bubbleの変換は1280×720のフレーム、端数のあるタイル、パディング付きストライドで全画素の位置と境界外書き込みがないことを確認した。

## KMS GLESとSDL2

RetroArchのKMS GLES経路は、コア・シェーダー・メニューを1280×720のEGLサーフェスに描画し、最終フレームをlibrgaで回転して720×1280のDRMバッファーへ転送する。PCSX-ReARMed、OpenBOR、Pyxelは、同じ転送処理を組み込んだSDL2を使用する。Pyxelのアスペクト補正は実際のEGL描画サイズを使う。回転はRGB10 Max 3の縦長DSIモードでのみ有効になり、HDMIと他機種は従来の向きで描画する。専用SDL2は対象機の3経路でのみ選択する。 [JELOSのlibrga](https://github.com/JustEnoughLinuxOS/linux-rga/tree/df26244eb0c3991df319d4276ab80e8c0bf91f64) · [ROCKNIXのパネル向きの説明](https://rocknix.org/contribute/quirks/)

ARM64 DockerでRetroArch、SDL2、Pyxelの表示アダプターをビルドした。疑似GBM/RGA試験で機種・DSI/HDMI・縦横判定、270度の指定、入出力の寸法とストライド、FDの解放、フリップ成功時のバッファー切替を確認した。

### 共通SDイメージ

v0.1.2のSYSTEMをベースにARM64 Dockerで試験イメージを生成した。v0.1.2と先頭16 MiB、初期GPT、KERNEL、DTB、extlinux設定が一致することを確認した。初回のp5作成、再起動後のセットアップ継続、利用者データの保持、SYSTEM更新と復旧、フロントエンドの196起動プロファイルを検証した。

| 配布ファイル | SHA-256 |
| --- | --- |
| `plumOS-RK3566-rgb10max3-test.img.gz` | `d02fc1f03e45a1458eae2357c86dc912b5f3804e4c4f8bf2bed3e4b70a3e11a5` |

### 実機で確認する項目

- Bubbleの縦横と操作、テキスト・グラフィック・ギャラリーモードの表示
- RetroArchのGLES経路で起動するコアのゲーム画面、メニュー、Core Providedのアスペクト比
- PCSX-ReARMedとOpenBORのゲーム画面とメニュー、Pyxelのアスペクト比
- 各経路を終了した後のBubbleの描画と、HDMI接続時の表示

RGB10 Max 3の実機利用者から、試験イメージで画面の向きが直ったと報告を受けた。個別のエミュレータやフレームレートについては詳細な結果を受け取っていない。

## 音声と電源オフの追加試験

実機利用者から、設定のシャットダウンで本体が再起動し、再起動の項目は通常どおり再起動するとの報告を受けた。また、音声出力をスピーカーに設定すると無音で、ヘッドフォンを選ぶと内蔵スピーカーから鳴った。

- **音声**はJELOS 20240206の機種別設定と照合し、内蔵スピーカーをRK817の `HP`、ヘッドフォンを `SPK` に割り当てた。自動設定ではジャックの検出結果にこの対応を適用する。 [JELOSの機種別音声設定](https://github.com/JustEnoughLinuxOS/distribution/blob/f8cac7b92040d734506e238f5a44560a4f0e81b0/packages/hardware/quirks/devices/Powkiddy%20RGB10%20Max%203/050-audio_path)
- **電源**は、メニューからのシャットダウンが `poweroff`、再起動が `reboot` としてplumOS initへ渡されることを確認した。収録DTBの `rockchip,rk817` と `not-save-power-en = 1` を確認し、RGB30・RG353Vと同じ機種限定の対策を適用した。古い電源レール設定をBSPカーネルが復元するのを防ぐため、非ゼロの保存値を電源操作前に消去する。報告機の保存値とUSB給電状態は未採取のため、今回の再起動の原因は実機確認待ち。 [JELOSのRK817処理](https://github.com/JustEnoughLinuxOS/rk356x-kernel/blob/c741d56477939654bb4056be240f93d1ad1ae91e/drivers/mfd/rk808.c#L1049-L1088) · [U-Bootの電源レール保存に関する議論](https://lore-kernel.gnuweeb.org/u-boot/PH0PR19MB997338A34AEEDDAF76FF8D1B95A5762@PH0PR19MB997338.namprd19.prod.outlook.com/T/)

ARM64 Dockerで、音声設定とジャック検出の組み合わせ、機種・PMIC・DT条件での書き込み制限、保存レジスターの読み戻し、シャットダウンと再起動の別経路を試験した。試験SDのブート領域、初期GPT、カーネル、DTBと主要な表示バイナリを前回の表示試験版と照合した。初回のp5作成、再起動後のセットアップ継続、SYSTEMの更新と復旧も確認した。

| 配布ファイル | SHA-256 |
| --- | --- |
| `plumOS-RK3566-rgb10max3-power-audio-test.img.gz` | `8e84196199fb285144985a9c63d7bd8f285ed11bfccfa7cdbfe4585d593ae975` |

実機では、スピーカー、ヘッドフォン、自動切替と、バッテリー駆動時・USB給電時それぞれのシャットダウンと再起動を確認する。シャットダウン後にロゴが再表示された場合は、利用者領域の `Logs/rgb10max3-power.log` を採取する。ログには直近20件の要求、起動ID、USB給電状態、電源操作前のRK817保存値、起動時のPMIC理由が残る。

利用者から、追加試験版で音声と電源オフの問題が解消したと報告を受けた。

## 内蔵Wi-Fi

ROCKNIXの機種資料では内蔵無線をRTL8723DSと記載している。試験SDのJELOS BSPカーネル用DTBでは、SDIOホストとカードの電源シーケンスが有効だった。JELOS 20240206の参照SYSTEMから `8723ds.ko` を取得し、4.19.172のARM64用であること、SDIO ID `024c:d723` と `024c:d724` を受け付けること、Wi-Fi用のファームウェアがモジュールに内蔵されていることを確認した。JELOSの `rtl8723d_fw` と `rtl8723d_config` はBluetooth用で、Wi-Fiの組み込みファームウェアとは別に扱う。 [ROCKNIXの機種資料](https://rocknix.org/devices/powkiddy/rgb10-max-3/) · [JELOSのWi-Fiドライバー](https://github.com/JustEnoughLinuxOS/rk356x-kernel/tree/c741d56477939654bb4056be240f93d1ad1ae91e/drivers/net/wireless/rockchip_wlan/rtl8723ds) · [JELOSのBluetoothファームウェア定義](https://github.com/JustEnoughLinuxOS/distribution/blob/f8cac7b92040d734506e238f5a44560a4f0e81b0/packages/kernel/linux-firmware/RTL8723DS-firmware/package.mk)

モジュールは共通イメージ内の機種専用ディレクトリに置いた。Network SettingsはRGB10 Max 3の機種名と該当するSDIO IDが揃ったときにのみ読み込む。RTL8821CS搭載個体は従来のSDIO経路で読み込み、既存の `wlan0` があればそのまま使用する。ARM64 Dockerの模擬試験で、起動、スキャン、接続、Wi-FiをOFFにした場合と他機種のドライバー選択を確認した。

Dockerで共通SD試験イメージを生成し、前回の試験版とブート領域、初期GPT、カーネル、DTB、既存モジュールのエイリアスとファームウェアを照合した。初回のp5作成とSYSTEMの更新・復旧も確認した。

| 配布ファイル | SHA-256 |
| --- | --- |
| `plumOS-RK3566-rgb10max3-wifi-test.img.gz` | `f99fcef37a2b0897b2787d2b2a3497fdf64d4562ad54e5ca6306fb0d342c2b82` |

実機ではドングルを外した状態で `START → Network Settings → Connect Wi-Fi` から2.4 GHzのSSIDを選び、IPアドレスの取得と再起動後の自動再接続を確認する。
