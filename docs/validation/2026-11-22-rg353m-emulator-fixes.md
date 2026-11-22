# RG353Mのエミュレータ再試験と修正

2026年11月22日（JST）。全プロファイル試験で検出した起動、入力、音声の問題を再試験した。SDはUSB ADBで更新し、音量は20％で計測した。修正の設計には、同じRK3566を搭載するBubbleと、ALSAの検証履歴があるV90S V2を参照した。[plumOS-Bubble](https://github.com/game-de-it/plumOS-Bubble/tree/ec81d42c0c2c39e7a32973bfe4df9b3027512a5d) · [plumOS-V90S V2の音声修正](https://github.com/game-de-it/plumOS-V90S_V2/commit/1e4deef4a79abe0f632266423d93e9b46cb67649)

## 起動とFNメニュー

| 経路 | 対処と確認 |
| --- | --- |
| DraStic | Bubbleの `47d8438`、`a97d26c`、`958cc16` を参照した。SYSFSから実際の内蔵ゲームパッドを選択し、ARMHFの入力ドライバーにFNのevdevコード316を渡した。SYSTEM内のランタイムには一時書き込み層を重ね、セーブと設定は従来の永続領域を使う。『New スーパーマリオブラザーズ』で描画、PCM、FNでメニューに入り、Bでゲームに戻ることを確認した。元の検体はDraSticがゲームカードヘッダーを拒否した。 |
| Standalone YabaSanshiro | Bubbleの `4a8285f` とPPSSPPのMali対処 `0d8d1ee` を参考に、JELOS同梱のSDLと単一のMaliライブラリをロードした。『The Tower』でEGL/GBMの初期化、描画とPCMを確認した。内蔵パッドのメニューをraw button 17からRG353MのFN（10）に合わせた。SDL画面にYaba Sanshiro 2.10.4 Menuが表示され、もう一度FNを押すとゲーム画面に復帰した。通常の画面提示は約15〜16 fpsで、CPUをperformanceにしても改善しなかった。 |
| PPSSPP | 『Star Soldier』でFNの直前・直後にSDLの画面を取得した。タイトル画面の上にContinue・Save stateなどのポーズメニューが表示された。 |
| OpenBOR | 内蔵ゲームパッドのFNをOpenBORのポーズ操作に割り当てた。同じボタンが通常のスクリーンショット操作に入らないよう分けた。『Dragon Ball』のプレイ中にFNを押し、画面上のPAUSE・Continue・End Gameを確認した。 |

## ROMとファームウェア

- SwanStationは『Pac-Man World』のCUEと正しいBIOSの読み込みを追跡した。追跡なしの個別試験で58.66 fps、組み立て済みSYSTEMの再試験で58.57 fpsとPCMの進行を確認した。再起動直後の失敗はinitの共有メモリ設定で解消した。
- CPS2専用FBA 2012は親セットの `armwar.zip` と `batcir.zip` で起動し、59.06〜59.18 fpsとPCMの進行を確認した。元のクローンセットは親セットを要求する。
- FreeChaFはBubbleの `4aaa90d` に記録された2本のBIOSと同じMD5になることを確認した。ROM2内の `cfbios.bin` を1,024バイトずつに分け、利用者領域のBIOSディレクトリへ配置した。『Tents』で58.12 fpsとPCMの進行を確認した。実機の利用者領域だけに配置した。
- SquirrelJMEでは `squirreljme.sqc` を試験領域へ用意すると、エラー `-7` を解消し、RatufaCoat 0.3.0のライブラリ初期化まで進んだ。『Cento』はゲーム起動まで確認できず、PCMは進まなかった。現行の固定ソースには音声コールバックを登録する処理はあるが、サンプルを送る処理がない。BubbleのJ2MEは従来どおり未サポート扱い。

## 音声バッファと画面提示

Bubbleの `95169fe` と `020e221` で確認されたN64用のperformance設定を出発点にした。V90Sの `1c2f26c` と `1e4deef` の経緯も照合した。ALSAのバッファ設定を64 msから128 msに変更するだけでは、N64とPCエンジンのXRUNが残った。

| 経路と検体 | ALSAスレッドありの15秒計測 |
| --- | --- |
| 『AeroGauge』・ParaLLEl N64 | Rice・320×240の試験設定で53.47 fps、PCM開始1回、観測XRUNなし |
| 『AeroGauge』・Mupen64Plus-Next | 52.26 fps、PCM開始1回、観測XRUNなし |
| 『Bomberman '93』・mednafen_pce | 36.65 fps、PCM開始1回、観測XRUNなし |
| 『Image Fight』・FBNeo | 29.90 fps、PCM開始1回、観測XRUNなし |

比較用SYSTEMには上記4コアの既定ALSA経路にスレッド版を選ぶ処理を加えた。ParaLLEl N64のRiceは試験用に指定し、ゲーム互換性に関わる映像プラグインの既定値は従来どおりとした。画面提示の遅さは残っており、音声の判定にはALSAの状態、ハードウェアポインタ、DMAの開始回数を使った。RetroArchのスレッド版ALSAは、キューにサンプルが足りない区間を無音で埋める。PCMがRUNNINGでも、ゲーム音が連続するとは限らない。

## 比較用SYSTEMのDocker組み立てとADB試験起動

`prototype/build-bubble-system.sh` で、RG353M用に再ビルド済みのJELOS SYSTEMと修正済みランタイムを組み立てた。Standalone 865ファイル、PicoArch 13ファイル、Libretro 1,425ファイルのコンポーネントハッシュを照合した。生成物のSHA-256は次のとおり。

| 生成物 | SHA-256 |
| --- | --- |
| SYSTEM | `7e4b668eb262723698a2914e5c21ae87dc9add7efdd96c4bff104445d404d680` |
| bubble-userland.squashfs | `974573a33b3c7624730074222e124419841dfc95f575017905ff3c3e7707cecc` |

USB ADBでSYSTEMを転送し、`boot-system publish` で実機側のSHA-256を照合した。`boot-system trial` で起動して、plumOS initとBubbleの起動判定を確認した。各経路の試験前に内蔵スピーカーを20％に設定し、ALSAミキサーの `215,215` を確認した。

| 経路 | 画面提示（fps） | PCM状態 | DMA開始数 |
| --- | ---: | --- | ---: |
| PCエンジン mednafen_pce | 37.87 | RUNNING | 1 |
| PS1 SwanStation | 起動失敗 | — | — |
| PSP PPSSPP | 59.46 | RUNNING | 1 |
| N64 ParaLLEl N64 | 26.07 | RUNNING | 1 |
| N64 Mupen64Plus-Next | 57.72 | RUNNING | 1 |
| NDS DraStic | 58.66 | RUNNING | 1 |
| Saturn YabaSanshiro | 16.40 | RUNNING | 1 |
| アーケード FBNeo | 29.94 | RUNNING | 1 |
| CPS2 FBA 2012 CPS2 | 58.67 | PREPARED, RUNNING | 3 |
| OpenBOR | 55.08 | RUNNING, closed | 2 |
| Channel F FreeChaF | 57.88 | PREPARED, RUNNING | 4 |

SwanStationは試験SYSTEMの初回起動直後の検体で再度失敗した。同じSYSTEMでファイルアクセスを追跡した再試験は59.33 fpsで成功し、CUE、イメージと `scph5500.bin` を開いた。起動失敗は初回再試験の値として残した。

## 音切れと描画の切り分け

同じROM、音量20％で、通常ALSAとスレッド版ALSAを比較した。スレッド版はDMAの再始動を抑えたものの、低い画面提示が残った。BubbleにはGL/KMSのスレッド描画経路があるため、これを使い通常ALSAへ戻す試験を追加した。

| 経路 | DRM・通常ALSA | GL/KMS・通常ALSA | GL/KMSのPCM開始数とXRUN |
| --- | ---: | ---: | --- |
| PCエンジン / mednafen_pce | 40.06 fps | 59.38 fps | 1回 |
| アーケード / fbneo | 27.59 fps | 54.75 fps | 1回 |
| Saturn / beetle_saturn | 16.58 fps | 23.39 fps | 29回, XRUNあり |
| Virtual Boy / mednafen_vb | 29.66 fps | 50.01 fps | 1回 |
| アーケード / mame2003_plus | 27.12 fps | 59.67 fps | 1回 |
| アーケード / mame2000 | 57.41 fps | 59.40 fps | 1回 |
| MAME 2003 Plus / mame2003_plus | 25.92 fps | 58.94 fps | 2回 |
| ScummVM / scummvm | 29.28 fps | 59.15 fps | 1回 |
| Supervision / potator | 54.55 fps | 59.59 fps | 1回 |
| Amiga / puae | 31.40 fps | 49.66 fps | 1回 |
| Amiga / km_puae_xtreme_amped | 31.74 fps | 49.87 fps | 1回 |
| Jaguar / virtualjaguar | 17.94 fps | 25.84 fps | 29回, XRUNあり |
| MicroW8 / uw8 | 16.23 fps | 23.17 fps | 29回, XRUNあり |
| PC-FX / mednafen_pcfx | 24.55 fps | 45.97 fps | 29回, XRUNあり |
| Uzebox / uzem | 26.93 fps | 52.76 fps | 25回 |

GL/KMSへの切り替えはPCエンジン、FBNeo、Virtual Boy、MAME 2000、MAME 2003 Plus、ScummVM、Supervision、Amigaの9コアに適用した。Virtual Boy、FBNeoの『Image Fight』、今回のAmigaのコア報告値はそれぞれ50.27 Hz、55.00 Hz、50.00 Hz。Beetle Saturn、Jaguar、MicroW8、PC-FX、Uzeboxでは、GL/KMSを試しても速度不足やPCMの再始動が残った。

スレッド版のキュー不足をRetroArchの試験ビルドで計測した。起動後約8秒を除いた観測区間では、『Bomberman ’93』の出力バイトの46.1％と『Image Fight』の45.2％が無音補填だった。N64の『AeroGauge』はParaLLEl N64で6.3％、Mupen64Plus-Nextで26.4％、『Mario Kart 64』はParaLLEl N64で8.4％、Mupen64Plus-Nextで21.6％だった。製品設定はBubbleのN64用performanceと通常ALSAの組み合わせを使う。

『Binary Land』のQuickNESは、通常ALSAで60秒間を計測した。59.93 fps、PCMがRUNNING、DMA開始1回で、メニュー操作を挟まない区間にXRUNは観測しなかった。Bubbleの先行試験では別のNESタイトルで5分の実聴も行っていた。[BubbleのNES連続試験](https://github.com/game-de-it/plumOS-Bubble/commit/aafce33e00d80c47d0dfe862bb6ec7090e0fa075)

2048、Gong、Numeroの固定ソースはlibretroのオーディオコールバックを登録するが、フレーム実行時にサンプルを送らない。Numeroの試験検体と同じROM2ディレクトリには必要なTI-83のBIOSがなかった。[BubbleのNumero検証](https://github.com/game-de-it/plumOS-Bubble/commit/d379c6be4ae4d81afea099ad1719b3e790ee61c9)

Atari 800は、Bubbleで音声を実聴できた『Yoomp』を再使用した。ROM2の生ディスクを試験領域に `Yoomp.xfd` として置き、PAL設定で48.97 fps（コア報告49.86 Hz）とPCMの進行を確認した。元の `CavernsOfMars.rom` は同じ試験でPCMがPREPAREDのままだった。[BubbleのAtari800検証](https://github.com/game-de-it/plumOS-Bubble/commit/f6bafb7a4f3e632d375a89e70f2cd8c9e1e6d496)

## 最終SYSTEM

9コアのGL/KMS経路、DraStic・YabaSanshiro・OpenBORの修正を含むSYSTEMをDockerで組み立てた。コンポーネントと生成物のSHA-256を照合し、USB ADBで既存SDへ転送した。

- SYSTEM `38fd4c188950e3cc31f60750970b71b386eab9f131ba9a859a94de990f5b1d4d`
- bubble-userland.squashfs `d035cc55c15cef2b1583b34514f9c0bca861c299dfe87c78897a479a4dd8cc5d`

最終SYSTEMを試験起動し、20経路を内蔵スピーカー20％で再計測した。退避した旧initでは、再起動後の最初のSwanStation起動で失敗した。19経路で画面提示とPCMの進行を確認した。

| システム | プロファイル | 画面提示 | PCM |
| --- | --- | ---: | --- |
| psx | `retroarch:km_duckswanstation_xtreme_amped` | 起動失敗 | — |
| nds | `standalone:drastic` | 56.03 fps | RUNNING。DMA開始1回 |
| saturn | `standalone:yabasanshiro` | 19.30 fps | RUNNING。DMA開始1回 |
| psp | `standalone:ppsspp` | 55.06 fps | RUNNING。DMA開始1回 |
| openbor | `standalone:openbor` | 55.03 fps | RUNNING。DMA開始2回 |
| cps2 | `retroarch:fbalpha2012_cps2` | 59.43 fps | RUNNING。DMA開始1回 |
| channelf | `retroarch:freechaf` | 58.99 fps | RUNNING。DMA開始2回 |
| pcengine | `retroarch:mednafen_pce` | 59.70 fps | RUNNING。DMA開始1回 |
| n64 | `retroarch:parallel_n64` | 27.38 fps | RUNNING, XRUN。DMA開始3回 |
| n64 | `retroarch:mupen64plus_next` | 54.86 fps | RUNNING, XRUN。DMA開始4回 |
| arcade | `retroarch:fbneo` | 54.31 fps | RUNNING。DMA開始1回 |
| neogeo | `retroarch:fbneo` | 59.24 fps | RUNNING。DMA開始1回 |
| virtualboy | `retroarch:mednafen_vb` | 49.80 fps | RUNNING。DMA開始1回 |
| arcade | `retroarch:mame2003_plus` | 59.22 fps | RUNNING。DMA開始1回 |
| arcade | `retroarch:mame2000` | 59.33 fps | RUNNING。DMA開始1回 |
| mame2003plus | `retroarch:mame2003_plus` | 59.24 fps | RUNNING。DMA開始1回 |
| scummvm | `retroarch:scummvm` | 58.81 fps | RUNNING。DMA開始1回 |
| supervision | `retroarch:potator` | 59.09 fps | RUNNING。DMA開始1回 |
| amiga | `retroarch:puae` | 49.30 fps | RUNNING。DMA開始1回 |
| amiga | `retroarch:km_puae_xtreme_amped` | 49.72 fps | RUNNING。DMA開始1回 |

PCエンジン版『Bomberman ’93』は59.70 fps、FBNeo版『Image Fight』は54.31 fps、ScummVMは58.81 fpsだった。9コアすべてでPCMはRUNNINGを維持し、観測区間のDMA開始は1回だった。N64の2経路では再試験でもXRUNを確認した。

### SwanStationの再起動直後の失敗

同じ最終SYSTEMとROMで旧initから再起動し、DraSticより先にSwanStationを起動した。straceでは共有メモリの `openat("/dev/shm/swanstation_…")` が `ENOENT` だった。以前SwanStationが動いた起動では、先にDraSticが `/dev/shm` を作っていた。

plumOS initでフロントエンドより先に `/dev/shm` をtmpfsでマウントするよう修正した。Dockerでビルドしたinitペイロードのうち `init`（SHA-256 `817f72e12bd5d61614cec1b549e0898dc46e9245a88910f79b4075e4bf7b63e8`）をADBでハッシュ照合し、旧ファイルを退避して置き換えた。次の再起動直後にSwanStationを最初に起動し、追跡なしで『Pac-Man World』の59.34 fps、PCMの進行、DMA開始1回を確認した。

SwanStationの再試験後に最終SYSTEMを既定にし、通常再起動を確認した。次回起動予約なしで同じSYSTEMとplumOS initが選ばれた。起動準備マーカーはカーネル起動から5.32秒で、Bubbleの描画、USB ADBのCONFIGURED、p5の読み書きマウント、音量20％を確認した。旧SYSTEMは `0218880c4a5b494a74f496f5e771cd65f6f9a9d4861f21df2ddb91ad0a1b66e6` として、旧initは `/storage/plumos-rk3566/init/init.pre-shm-backup` として実機に残した。
