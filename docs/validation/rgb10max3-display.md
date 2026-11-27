# RGB10 Max 3の内蔵画面

v0.1.2の実機写真では、Bubbleの上辺が本体の右側に表示されている。JELOS 20240206で使用するRGB10 Max 3用のBSPデバイスツリーは、DSIのネイティブモードを720×1280としている。JELOSはSDL2のKMSDRMにパネルの向きを渡し、librgaで回転していた。現在のROCKNIXのRK3566設定はSwayを起動し、パネルの向きを表示サーバーで扱う。Linuxのメインラインにもこの機種固有のパネル向きが登録されている。 [ROCKNIXのRK3566表示設定](https://github.com/ROCKNIX/distribution/blob/0f4806b59bfd1d3e6b17e3a632e95ced82a28719/projects/ROCKNIX/packages/hardware/quirks/platforms/RK3566/090-ui_service) · [ROCKNIXのパネル向きの説明](https://rocknix.org/contribute/quirks/) · [Linuxのデバイスツリー](https://github.com/torvalds/linux/blob/master/arch/arm64/boot/dts/rockchip/rk3566-powkiddy-rgb10max3.dts)

plumOSではRGB10 Max 3の縦型表示に合わせ、横長の各ピクセル `(x, y)` をネイティブ座標の `(y, width - 1 - x)` に配置する。Bubbleの共有DRMレンダラーを使う画面とPicoArchに共通の補正を適用する。RetroArchのソフトウェアDRM経路ではコアの回転を維持し、ゲーム・RGUI・OSDをパネルに合わせる。DraSticの描画ランナーはゲームとメニューの合成時に回転し、PPSSPPの直接表示Vulkan経路はネイティブのスワップチェーンに回転して描画する。

Bubble、PicoArch、RetroArch、DraSticの描画ランナー、PPSSPPをARM64 Dockerでビルドした。Bubbleの変換は1280×720のフレーム、端数のあるタイル、パディング付きストライドで全画素の位置と境界外書き込みがないことを確認した。

対象機での表示、フレームレート、各エミュレータの操作は修正後未検証。RetroArchのKMS GLES経路と、PCSX-ReARMed・OpenBOR・Pyxelなど個別のSDL/GLES経路には今回の補正は適用されない。
