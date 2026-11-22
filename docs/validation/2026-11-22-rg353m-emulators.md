# RG353Mのエミュレータと音声ルーティング

2026年11月22日（JST）。Bubbleの `ec81d42c0c2c39e7a32973bfe4df9b3027512a5d` を入力に、RetroArch 1.22.2、PicoArch、Standalone PCSX-ReARMed・YabaSanshiro・DraStic・PPSSPP・OpenBORをARM64 Dockerでビルドした。PicoArchはBubbleが固定したV90Sのツールチェーンを使う。Standalone用GPUランタイムは検証済みJELOS 20240206のSYSTEMから取得した。ROMとBIOSは指定されたROM2の検証用コピーをADBで転送した。GitとSDイメージにROMやBIOSは収録していない。

## 実機で再現した経路

| FEの実行経路 | ROM2の検証ROM | DRMのフレーム提示 | FNと音声 |
| --- | --- | --- | --- |
| RetroArch / QuickNES | Binary Land（NES） | 約60.0 fps | 内蔵画面・音声・FNメニューを目視確認。ADB計測でもゲーム→メニュー→ゲームとPCM再開を確認 |
| PicoArch / QuickNES | Binary Land（NES） | 約60.0 fps | 内蔵画面・FNメニューを目視確認。報告された音切れを調査し、リングバッファ補正後の3,600フレームで音声アンダーラン0 |
| Standalone / PCSX-ReARMed | Choro Q Wonderful!（PS1） | 約60 fpsの区間と約20 fpsの区間 | エミュレーションはどちらも約60 Hz。FN時の音声停止と復帰後のPCM再開をADBで確認 |
| PicoArch / mGBA | 伝説のスタフィー（GBA） | 約59.8 fps（コア公称59.73 Hz） | 描画・PCMを確認。連続試験で713サンプル、再試験で715サンプルのアンダーラン（48 kHz換算で各約15 ms）。聴感の確認候補 |
| Standalone / PPSSPP | Star Soldier（PSP） | 約60.0 fps | ゲームの起動、描画とPCM、FNがSDLのGuideボタンとして届くことを確認 |

ディスプレイは640×480・60 HzのDSI。FPSはプレイ区間約6秒の `drm_vblank_event_delivered` を、同一CRTCの連番と時刻で集計した。PS1はエミュレータからパネルへの提示レートを示す。音声のADB判定にはALSAハードウェアポインタとエミュレータのバッファ計測を用いた。聴感の確認結果は表に記した範囲。

- RG353MのFNは `BTN_MODE`（316、SDL/RetroArchのボタン10）。PicoArchはevdevのコードを、RetroArchとPCSXはジョイスティックの番号を使用する。
- RetroArchは起動後に黒画面になった。JELOSのDSI背景面がzpos 6、RGB565のゲーム描画面がzpos 4で重なっていた。RG353Mではゲーム・メニューの面をzpos 7にし、表示を確認した。ソフトウェアDRMは同期描画とし、NESの既定CPUポリシーを `performance` に設定した条件で361回／6.014秒だった。
- PicoArchの音声は、リングバッファに初期余裕を設け、残量に応じて音声のリサンプル比を微調整する。初期余裕だけの試作は3,600フレームで3,066サンプルの不足があり、補正後の同じ長さの試験は0だった。44.1 kHzのコア音声はハードウェア側の48 kHzに合わせて出力した。
- PCSX-ReARMedはJELOS同梱のKMSDRM SDL2を使用する。統合SYSTEMの `PLUMOS_BUBBLE_PROFILE_SECONDS` とDRMイベントを照合すると、Choro Q Wonderful!の低い区間でもエミュレーションは毎秒60回進行し、ゲームが更新した画面は毎秒20枚だった。すべてのシーンが60枚を描画するという判定にはしていない。
- 内蔵音声はBubbleの `plumos_output` とSoft Volume Masterを通す。RG353MのRK817は起動時に `Playback Path=SPK` を確認し、ヘッドホン検出時は端子のマイク有無に応じて `HP`・`HP_NO_MIC` を選ぶ。ヘッドホンの物理抜き差しは今回未検証。
- Bubbleのランチャーが使う `grep` や `taskset` を備えたARM64静的BusyBoxをSYSTEMへ収録した。アプレット呼び出しを有効にするため、ビルド時にも実機と同じ名前の `busybox` として起動し、必要なアプレットを検査する。

## Dockerビルドへの組み込み

```sh
./prototype/build-emulators.sh BUBBLE_GIT V90S_GIT JELOS_SYSTEM OUTPUT
./prototype/build-bubble-system.sh JELOS_SYSTEM BUBBLE_GIT STATIC_ADBD SYSTEM_OUT OUTPUT/runtime
./prototype/build-bubble-sd.sh JELOS_IMG SYSTEM_OUT/SYSTEM BOOT_SPLASH_DIR PLUMOS.img
./prototype/verify-bubble-sd.sh PLUMOS.img
```

Docker seedは初回からplumOS initを選び、失敗時にsystemdへ復旧する。GPTの初回更新とp5作成、既存データ保持、起動フラグのフォールバックを8 GiB相当の複製イメージで検証する。実機のエミュレータ検証には既存SDへのADB配備を使用した。

検証用SYSTEMには上記のStandalone 5本と、QuickNES・mGBA・PCSX-ReARMedのLibretroコア3本を収録する。ビルドスクリプトの既定はBubbleの全Libretroレシピで、`PLUMOS_BUBBLE_CATALOG_FILTER` で指定したコアだけをビルドできる。表は列挙したROMとプロファイルの実機試験を示す。

実機のinit更新中に、実行中のinitを置き換えるとext4が読み取り専用化を拒否する事象があった。インストーラは旧inodeへのハードリンクを起動中だけ保持し、次の起動で除去する。更新候補SYSTEMの試験起動と既定化、通常のADB再起動を実機で確認した。

## 検証済み成果物

- 圧縮SDイメージは `output/emulator-port/final/plumOS-RK3566-RG353M-emulator-test.img.gz`。rawは2,198,863,872バイト、圧縮版は1,573,263,810バイト。圧縮版SHA-256は `356a380ea52040445f325ec3f5d7a25f368bbc578f43d4e0e5749617e3ae1a69`。
- 実機の既定SYSTEMのSHA-256は `0218880c4a5b494a74f496f5e771cd65f6f9a9d4861f21df2ddb91ad0a1b66e6`。選択を保持して再起動後、PID 1はplumOS init、ADBは `configured`、p5は `/storage/user` に読み書き可能で、音声は `SPK`。実機のSD上のp5と設定を使って検証した。
- 全114件のLibretroレシピは別のDockerビルドで処理しており、この記録時点で48件の完了を確認した。検証用イメージに含めたコアと実機で試した組み合わせは上記の通り。
