# RG353Mでのエミュレータ全プロファイル試験

2026年11月22日（JST）。plumOS-Bubbleの `ec81d42c0c2c39e7a32973bfe4df9b3027512a5d` のカタログに登録された97システム・196プロファイルを対象にした。指定のROM2から各システムの代表ROMを選んだ。同一コアでもランチャーや対象機種が異なるプロファイルは個別に試した。

DockerでLibretroの114レシピが成功した。RG353M上では配備した118個のLibretro共有ライブラリがロードされ、Libretro API 1を返した。118個には別名やバージョン違いも含まれる。

試験のSYSTEMは `2cd42f7d5b9c32496279d07651da54968a50a48aa1b1846b10698aec1e343efe`。既存のSDを使い、ADBの試験起動で配備した。音量はplumOSの20段階中4に設定して保存し、内蔵スピーカー（`SPK`）で `Soft Volume Master=215,215` を確認した。各起動でも同じミキサー値を取得した。PyxelはDockerで別途ビルドしたペイロードを一時マウントして試した。

## 計測方法

- 普段の実行と同じエミュレータランチャーを起動した。監視プロセスによるFEの再起動を一時保留し、試験後に解除した。テストROM・BIOSの置き場はp5の `.plumos-emulator-matrix`、エミュレータの設定とセーブは試験用の一時領域を使用した。
- 内蔵画面のDRMページフリップ通知を約3秒間数え、毎秒の画面提示回数を計測した。エミュレータ内部の実行速度やゲームの更新頻度とは差が出る。PALなど公称値が60 Hz未満のゲームもある。
- ALSAのPCM状態とハードウェアポインタの進みを確認した。途中で `XRUN` を観測した行を表で識別できる。実機スピーカーから出る音の聴感は、ADBの計測からは確定できない。
- 物理FNと同じevdevの `BTN_MODE`（316）を送り、RetroArchのメニュー面のログ、画面提示の変化、ゲームの再開を記録した。メニュー面の記録を持たない経路では動作の変化を根拠としている。
- ファイルサイズ0のメガドライブ・PCエンジンの検体は実行に失敗した。再試験では `Bare Knuckle` と `Bomberman '93` を使用した。

## 再現用ファイル

`prototype/emulators/plan-rg353m-matrix.py` はFEの `systems.json` とROM2から試験表を作る。隣に `runtime-coverage.json` がある場合はBIOSの名前と配置も参照する。 `--adb` を指定すると実機の試験用ディレクトリへ検体とBIOSを転送する。 `prototype/emulators/run-rg353m-matrix.py` は試験表をADBで実行し、各回の結果JSONを記録する。再試験では起動待ち時間、計測時間、PicoArchの連続フレーム数を指定できる。

全行の要約は [rg353m-emulator-matrix.tsv](rg353m-emulator-matrix.tsv) に記録した。 `main` は初回試験、`followup` と `late_followup` は条件を整えた再試験、`continuous_no_fn` はメニュー操作を挟まない連続試験を示す。元の計測JSONにはエミュレータの出力も含まれる。ROM・BIOS・画面キャプチャはGitに収録していない。

## 検体を整えた再試験

- メガドライブの4経路は `Bare Knuckle` で58.60〜59.18 fpsとPCMの進行を確認した。PCエンジンは `Bomberman '93` で5経路の画面提示を確認した。RetroArchの `mednafen_pce` では約40 fpsでXRUNを検出した。
- セガCDの4経路は必要な大文字・小文字でリージョン別BIOSを配置すると、欧州版の `Fatal Fury Special` で47.58〜49.42 fpsとPCMの進行を確認できた。Neo Geo CDの `Fatal Fury` はMP3トラックを含むCUEを拒否した。ROM2内のWAVトラック版は58.93 fpsでPCMが進んだ。
- MSX・AtariではBIOSファイルを選んだ行があり、ゲームROMを使って取り直した。Cannonball・Cave Story・Dinothawrはゲームの付属データを追加し、Lutroは `lutro-pong.lutro` を使用した。
- PlayStationの `PAC-MAN_WORLD` はRetroArchとStandaloneのPCSX-ReARMedで描画とPCMを確認した。起動後の約10秒では画面提示が18.52 fpsと19.07 fpsだった。Standalone PCSX-ReARMedは別のゲームでエミュレーションがおよそ60 Hzの区間とゲーム画面が20 fpsの区間があることを先行試験で確認している。

## 検体を用意できなかった経路

22件でROM2から対応する試験用検体を用意できなかった。対象はArduboy、BK、Daphne、Flashback、Mega Duck、Neo Geo Pocket、Palm、PuzzleScript、Rick Dangerous、SG-1000（4経路）、Sharp X1、Super Mario War、TIC-80、Vectrex、VMU、Wolfenstein 3D、WonderSwan Color、X68000、ZX81。Portsの1件は試験SYSTEMにPortMasterのランチャーとランタイムがなく、ROM2の起動スクリプトもそれらを必要としていた。

## PicoArchの連続音声試験

| 検体 | コア | 完走フレーム | 画面提示 | 音声バッファの不足 |
| --- | --- | ---: | ---: | ---: |
| Binary Land | QuickNES | 3,600 | 59.38 fps | 0サンプルフレーム |
| 伝説のスタフィー | mGBA | 3,600 | 59.39 fps | 43サンプルフレーム（48 kHzで約0.9 ms） |

音量は20％。音声バッファの不足数はPicoArchの診断カウンター。FNを開いた別試験では、メニュー表示中にゲームが音声を生成しない区間もこのカウンターに入ったため、連続再生の値にはメニュー操作を挟まない計測を使った。両検体ともキャプチャでゲーム画像を確認した。

## 結果と残った問題

| 実行経路 | カタログ | 実機で試験 | 画面提示を確認 | 起動・描画の問題 | 検体・依存関係待ち |
| --- | ---: | ---: | ---: | ---: | ---: |
| RetroArch | 153 | 131 | 127 | 4 | 22 |
| PicoArch | 36 | 36 | 36 | 0 | 0 |
| Standalone | 5 | 5 | 3 | 2 | 0 |
| Pyxel | 1 | 1 | 1 | 0 | 0 |
| Ports | 1 | 0 | 0 | 0 | 1 |
| 合計 | 196 | 173 | 167 | 6 | 23 |

画面提示を確認した167件のうち164件でPCMポインタが進んだ。105件で57〜61 fpsを計測し、18件で直近の計測中にXRUNを検出した。画面提示とPCMの計測だけでは、ゲーム中の画面の内容やスピーカーから聞こえる音を全件で判定できない。試験後も音量は20％に維持した。

| 起動・描画に問題が残った経路 | 結果 |
| --- | --- |
| PS1 / SwanStation | `Choro Q Wonderful!` のIMGと `Pac-Man World` のCUEでコンテンツ読み込みに失敗 |
| NDS / DraStic | 読み取り専用のランタイム内に `backup` を作ろうとして終了 |
| Saturn / Standalone YabaSanshiro | EGL/GBMの表示初期化に失敗 |
| CPS2 / FBA 2012 CPS2 | `ssf2tu.zip` と `ssf2u.zip` で旧コアが要求する親セットが足りず起動失敗 |
| Channel F / FreeChaF | 必要なBIOSを開けず、`tents_CF.bin` はHLEで未対応の処理に遭遇 |
| J2ME / SquirrelJME | `Cento.jar` でJVMエラー `-7`。DRMイベントは発生したが、ゲーム起動は確認できなかった |

`Strider Hiryu` の互換セットを使うとアーケードのMAME 2003 Plus、MAME 2003 Xtreme、MAME 2000、MBA Miniはいずれも画面提示とPCMを確認できた。MSXのblueMSXは、外部BIOSの代わりに試験SYSTEM同梱のデータを使う条件で `Usas` の画面提示とPCMを確認した。

目視・聴感確認を行う場合は、表の起動失敗とは別に、起動後の問題が測れた組み合わせが候補になる。 `AeroGauge`（Mupen64Plus-Next）ではXRUN、同じ作品のParaLLEl N64では16.62 fpsを観測した。 `Bomberman '93`（mednafen_pce）では40.06 fpsとXRUN、 `Image Fight`（FBNeo）では27.02〜27.59 fpsとXRUNを再現した。SaturnのRetroArch版ではYabaSanshiroが7.23 fps、Beetle Saturnが再試験で17.63 fpsだった。その他の候補はTSVの `display_fps` と `pcm_states` から確認できる。

FN操作では、画面提示を確認したRetroArch 127件でメニュー面またはメニューによる音声停止・再開を記録した。PicoArch 36件はFNの前後で画面提示が低下して復帰し、StandaloneのPCSX-ReARMedでも同じ変化を記録した。PPSSPPとOpenBORは映像とPCMの進行を確認できたが、FNメニューが開いたかは画面提示とPCMの計測から判定できなかった。Pyxelの対象アプリにはエミュレータ共通のFNメニューを適用していない。

試験終了後に一時マウントを解除し、FEの再起動と描画準備、p5の読み書き、USB ADBの `CONFIGURED`、内蔵スピーカーの `215,215` を確認した。全コア版SYSTEMはADBで試験起動した状態。再起動時の既定は作業前の `0218880c4a5b494a74f496f5e771cd65f6f9a9d4861f21df2ddb91ad0a1b66e6`。
