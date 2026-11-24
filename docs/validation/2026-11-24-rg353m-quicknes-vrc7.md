# QuickNESでのLagrange Point起動

Lagrange PointはKonami VRC7a（マッパー85、NES 2.0サブマッパー2）を使用する。[VRC7の仕様](https://www.nesdev.org/wiki/VRC7)

QuickNESの固定リビジョン `058d665` はVRC7のマッパーとFM合成を実装済み。今回のROMにはNES 2.0の既定の拡張機器番号がバイト15に入っている。旧ローダーはバイト15が0以外だとヘッダーの上位マッパー情報を捨てるため、85を5と判定していた。NES 2.0のヘッダーを識別し、従来の補正は旧iNES形式にだけ適用する。拡張マッパー番号または拡張ROMサイズを必要とするヘッダーは明示的にエラーにする。[固定リビジョンのVRC7実装](https://github.com/libretro/QuickNES_Core/blob/058d66516ed3f1260b69e5b71cd454eb7e9234a3/nes_emu/Mapper_Vrc7.cpp)

ROMは編集せず、保有の `Lagrange Point (Japan).nes` と `LagrangePoint.nes` で検証した。旧コアではブート画面を抜けず、修正コアでは両方でタイトルと名前入力画面が出た。DockerのLibretro試験で日本語版の名前を入力し、オープニングを経て最初の操作画面まで進んだ。Binary Landは同じ入力で修正前後のPCMとフレームが一致した。FM出力だけを0にした診断用コアとの比較で、演奏時にVRC7がPCMへ混ざることを確認した。

本番カタログのDockerビルドでQuickNESだけをビルドし、パッチのSHA-256を記録した。最終SYSTEMのSHA-256は `a36e56daa17f63bcc33cfab8baf23064bdfeaf4169d3ed3b44c5ad9e4b1853d5`。USB ADBで転送して試験起動し、既定のSYSTEMに設定した。

RG353Mの通常のFE起動プロファイルを経由し、RetroArchで `Lagrange Point (Japan).nes`、PicoArchで `LagrangePoint.nes` を起動した。両方でDRM描画、内蔵スピーカーPCMのポインター進行、FNメニューへの切替と復帰を測定した。検証中のセーブ領域は一時ディレクトリに分離した。試験用SYSTEMの転送前に、Macに同一ハッシュのコピーがある旧候補SYSTEMをSDから1本取り除いた。

## Stereo Panning

同じゲーム入力で、最初の操作場面を含む25秒分（1,100,819ステレオフレーム）の出力を比較した。QuickNESの `Non-Linear` では左右差が0、`Stereo Panning` では1,098,423フレームで左右が異なった。VRC7だけを無音にした比較用ビルドとの差分にも左右差があり、FMの成分にもステレオ効果がかかることを確認した。

QuickNESはNES本体の2つのパルス音を左右に配分する。VRC7の6音は中央にミックスされ、左右で異なるエコーが加わる。FMの各音を個別の左右位置へ振り分ける実装ではない。[QuickNESのエフェクト実装](https://github.com/libretro/QuickNES_Core/blob/058d66516ed3f1260b69e5b71cd454eb7e9234a3/nes_emu/Effects_Buffer.cpp)

RG353Mの既存ALSA出力へ同じPCMの一部を流し、RK817への書き込み直前で左右を別々に取得した。PCMは2チャンネルのままRUNNINGとなり、入力と同じチャンネルの相関は左右とも0.99998以上だった。試験ではLibretroの呼び出し側からコアオプションを指定し、出力経路の検証には本体の音量設定を使用した。USB DACやアナログ出力の実聴は今回の試験項目に含めていない。
