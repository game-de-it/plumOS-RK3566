# RG353M: ゲーム中のUSB DAC抜き差し

2026-11-23（JST）。ユーザー報告: USB DACを抜いてもゲーム中にスピーカーへ戻らない。旧ALSA設定は`plumos_output`を起動時に選んだ`hw:<card>,0`へ直結していた。再生中のPCMがその物理カードに固定されていたため、設定ファイルを更新しても開いたゲームには反映されなかった。

## 修正

plumOS-MFの音声経路履歴（`fb93d91`から`0095017`まで）を確認し、最新のALSA ioplugをRG353Mへ移植した。MFで追加されたUSB切断時のブロッキングPCM回復、SDLの固定poll fd、再生準備状態からの再開も取り込んだ。RG353MではRK817のカードID`rockchiprk817co`を探し、`Auto`と`USB DAC`はUSB優先、`Speaker`と`Headphone`は内蔵を選ぶ。RK817のヘッドホン／スピーカーミキサー設定は既存の監視を使う。

ALSAの公開名`plumos_output`、`plumos_pyxel`、`default`を同じ論理PCMへ接続した。切替後の内蔵PCMが`PREPARED`で止まらないよう、物理経路の交換時に無音の1周期を送り再生クロックを起動する。音量0〜20は以前のSoft Volume Master v2のdB曲線と同じQ15ゲインでプラグイン内に適用する。FE用のミキサー制御と音量ボタンの保存値は維持し、起動時のコントロール生成は`plumos_softvol`を指定する。ソースとMITライセンスは`prototype/emulators/audio-router/`に置き、DockerビルドでARM64プラグインを生成する。

## 実機検証

- SDは焼き直さずADBで試験し、同じ`aplay` PID 31197でRK817→CX31993→RK817を確認した。各経路の物理PCMが`RUNNING`で再生位置を進めた。最初の試作ではUSBから戻ったRK817が`PREPARED`で止まり、無音1周期で再開する修正後に解消した。
- Docker生成の`SYSTEM`はSHA-256 `1d2ee3cce46d13c9eea2ca3586e08c4d3650d3098eff89e7e957e14c39ef2538`。実機で試験起動し、`boot-system`の`active`・`healthy`・`default`が同じハッシュになった。ADBとFEも起動した。カーネル、DTB、ブート領域、パーティションは変更していない。旧`/flash/SYSTEM`を復旧先として残した。
- 新SYSTEMでFE経由のNES/QuickNES、GBA/PicoArch gpSP、OpenBORは起動し、いずれも画面とPCM再生位置を確認した。PicoArchは8秒計測で59.48 fps、PCM開始1回。OpenBORは約56.65 fpsで、途中にPCMの開き直しを1回観測した。
- NES「Binary Land」をFEから起動し、RetroArch PID 11556を維持したままDACを挿して抜いた。DAC接続中はCX31993のPCMが`RUNNING`でユーザーがゲーム音を聴取。抜いた後はRK817 PCMが`RUNNING`で再生位置が進み、ユーザーがスピーカーからのゲーム音を聴取した。
- NESの30秒fpsは新経路53.48、RetroArchを直接物理PCMで開く比較54.13、旧ソフトボリューム経路54.85だった。同じ新SYSTEMで旧経路でも低かったため、今回の切替プラグイン固有の低下とは判定しない。fpsの差は別途継続調査する。OpenBORでは短時間のXRUNを1回観測しており、全エミュの音切れがないことを示す試験ではない。

生データは`output/audio-hotplug-*-results.json`に保存した。音量値は試験後に保存値12へ戻し、FEとADBを復旧した。
