# RG353M Portsの無音とApotris起動失敗

2026-11-23（JST）。SD2の`Roms/PORTS`にはApotrisだけがある。音楽モジュールと効果音WAVは揃っていた。USB DACはCX31993（card 0）、PortMasterランチャーは`ALSA_CONFIG_PATH=/run/plumos-353m/audio/asound.conf`、`AUDIODEV=plumos_output`、`SDL_AUDIODRIVER=alsa`を渡していた。

## 他シリーズの履歴

- [plumOS-Bubble PortMaster受け入れ記録](https://github.com/game-de-it/plumOS-Bubble/commit/5b4adad)では、Apotrisの`Failed to open PWM`は表示・音声を妨げず、25回のPCM標本が全て`RUNNING`だった。したがってPWM警告だけを無音原因と扱わない。
- [MF PortMaster音声ランタイム修正](https://github.com/game-de-it/plumOS-MF/commit/186fab8)はSDL mixer、modplug、fluidsynthなどの依存ライブラリを補完した。RG353MのPortMaster実行時ライブラリリンクはこれらを含む。
- [V90S OpenAL音声経路修正](https://github.com/game-de-it/plumOS-V90S_V2/commit/db183c0)は、`AUDIODEV`を無視してALSAの`default`を開くポートを扱う。RG353MのALSA設定は`pcm.!default`も管理経路へ向けている。

## 実機での切り分け

USB ADBを復旧し、PortMasterランチャー経由でApotrisを試験した。インターポーザでSDL呼び出しを観測した結果、SD2に入っていたApotris v4.2.0は`SDL_CreateWindow`と`SDL_CreateRenderer`に成功し、ゲームパッド初期化後のゲーム本体内で`SIGSEGV`を起こした。`SDL_OpenAudioDevice`は呼ばれず、USB DAC PCMは`closed`のままだった。16秒のFE実行試験も`pcm_progress=false`であった。ゲームパッド追加イベントを除外しても、元のセーブを一時的に外しても同じ箇所で落ちた。JELOS標準SDL2への差し替えは描画初期化に失敗したため対策にならない。

[PortMasterの履歴](https://github.com/PortsMaster/PortMaster-New/commits/main/ports/apotris/apotris/Apotris.aarch64)では、2026-10-19にv4.2.0へ更新され、その前はv4.1.0だった。公式PortMasterの[更新前コミット](https://github.com/PortsMaster/PortMaster-New/commit/134ee23c0f08)からAArch64実行ファイルを取得し、元のゲーム本体に一時的にbind mountして同じSD2の資産・ランチャー・USB DACで比較した。v4.1.0は28秒間クラッシュせず、`SDL_OpenAudioDevice dev=default id=2`を呼び、USB DACの`/proc/asound/card0/pcm0p/sub0/status`が`RUNNING`、owner PIDがApotris、`hw_ptr=712253`、`appl_ptr=714752`になった。終了後はPCMが`closed`に戻った。これはRG353M上でv4.2.0の起動互換性が失われたことを示す。PCMの進行は確認できたが、今回は利用者による聴感確認を行っていない。

SD2の`Apotris.aarch64`を公式v4.1.0へ差し替えた。元のv4.2.0本体は同ディレクトリの`Apotris.aarch64.v4.2.0.bak`、元のセーブは`Apotris.sav.v4.2.0.bak`に保存した。診断中にv4.1.0がセーブを書き換えたため、元のセーブをMac側のバックアップから復元し、SHA-256 `a9026da4f679fdf323464b2054100b4c3d9b56615c2de62ef9177d582c19c436`を確認した。v4.2.0本体のSHA-256は`3fe5e66ed7c184f7cda3ae6161f5004f4937a16dd4a19b51b5f463ffc42fc7ec`、適用したv4.1.0は`86ba76c37c45ba56271a51c01688a90c37bf27d067d302b994fbb0e8216d0c06`。PortMasterからApotrisを更新するとv4.2.0が再導入される可能性がある。

## 他の音声経路

既存のUSB DAC実機結果ではRetroArch gpSP、PicoArch gpSP、単体OpenBORが`RUNNING`かつPCMポインタ進行を記録済み。OpenBORの一度の開き直しは利用者の聴感で音切れなし。別のFE試験ではNeoGeo、PICO-8、NGPC、GBC、ColecoVision、PC Engine、MSX、Atari 7800のRetroArchコア全てでPCMが`RUNNING`かつ進行した。PortMaster、RA、PicoArch、単体エミュレータの実機ランチャーを監査し、いずれも管理対象ALSA設定を参照していた。PyxelのDocker組み立て元だけ旧`/run/plumos/audio/asound.conf`を既定値にしていたため、`prototype/emulators/assemble-runtime.sh`でRK実行時ルートに修正した（コミット`1280926`）。実機にあるPyxelランチャーは既に修正済みの経路だった。

繰り返し起動診断でPID 1のFE再起動上限に達したため、診断後に`/usr/lib/plumos-353m/start-frontend`からFEを手動起動した。ADBの`reboot`とシェルの`reboot`は稼働時間をリセットしなかった。起動コードを確認し、手動FEを終了して`plumos-safe-shutdown --reboot`でPID 1へ正式な電源要求を送った。再起動後の稼働時間は20秒、PID 1配下のFE PID 332が起動し、`/tmp/plumos-fe-ready`、ADB、SD2の`/storage/user/Roms`マウント、USB DAC card 0を確認した。ゲーム本体とセーブのハッシュも再起動前と一致した。
