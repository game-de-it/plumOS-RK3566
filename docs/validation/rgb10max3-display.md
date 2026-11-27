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

RGB10 Max 3での確認は未実施。実機でのRGA転送、画面の向き、フレームレートは上記の試験で確認する。
