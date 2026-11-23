# RG353M USB DAC: RA・PICO・SA の音声試験

2026-11-23（JST）。RG353MのOTG端子へCX31993 USB DACを接続し、USBハブ経由のADBで実機を計測した。初回再起動後、`/proc/asound/cards` はDACをカード0、RK817をカード1として検出した。Audio Output設定は`auto`で、`/run/plumos-353m/audio/output.status`は`mode=usb_dac`、`physical_pcm=hw:0,0`を示した。各エミュレータの起動後にも同じ出力先を読み、内蔵スピーカー側のPCMを誤計測しないようにした。

試験には既存のROM検体を使用し、通常のplumOSランチャーで起動した。試験中だけ音量を20％に設定し、終了後に元の値18へ戻した。CPUガバナーは各ゲーム起動中`ondemand`で、計測中のクロックは408〜1992 MHzの範囲で変動した。ROM、設定、セーブは既存のマトリクス試験と同じ一時領域へ分離した。

| 経路 | 検体 | 計測時間 | 画面更新 | USB PCM | 再生開始時刻 | 追加の音声指標 |
| --- | --- | ---: | ---: | --- | ---: | --- |
| RA / gpSP | Densetsu no Stafy (GBA) | 60秒 | 59.74fps | `RUNNING`、ポインタ進行 | 1回 | 計測中の再始動なし |
| PICO / gpSP | 同上 | 60秒 | 59.65fps | `RUNNING`、ポインタ進行 | 1回 | 4500フレーム完了、内部音声不足0フレーム |
| SA / OpenBOR | Dragon Ball | 開始後15秒から60秒 | 59.88fps | `RUNNING`、ポインタ進行 | 1回 | プレイ中の再始動なし |

OpenBORの最初の90秒の測定では、起動から約9秒後にPCMの開始時刻が1回変わった。ゲームの初期遷移と重なるため、開始後15秒から測り直した。この再試験では60秒間再始動はなかった。最初の遷移が実際に聞こえる音切れかどうかは、この計測だけでは判定できない。

以上の区間ではUSB DAC側のPCM停止や再始動は検出されず、PICOの音声不足カウンタは0だった。RAとOpenBORには音声サンプルそのものを録音するループバックがないため、耳で聞こえる微小な音切れを完全に否定する測定ではない。OpenBOR開始直後の切り替えについては実聴確認が残る。

試験計画とJSON原本は`output/usb-dac-audio-plan.json`、`output/usb-dac-audio-results.json`、`output/usb-dac-sa-retest-results.json`、`output/usb-dac-sa-steady-results.json`に保存した。計測プログラムは`prototype/emulators/probe-rg353m-route.py`である。試験後はFEが再起動し、`validation-hold`は消え、USB DACの自動選択と元の音量値18を確認した。
