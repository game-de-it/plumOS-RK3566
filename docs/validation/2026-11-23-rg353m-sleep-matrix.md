# RG353MのSleep追加試験

2026年11月23日（JST）。試験機の既定SYSTEMは `fc01b5ed99c5745be0ee701e1f4ceed7e1c5c52e477e34d382187d61a1daba02`（`2253bc1`）。USB ADB給電中（`ac/online=1`）に `mem` とJELOS由来の `mem_sleep=s2idle` を使用した。SDの再書き込みは行っていない。

単体エミュレータ、ゲーム、外部Appsは出荷用ランチャーとplumOS-Bubbleと同じDRMブローカーで起動した。電源キーと十字キー・Aのevdevイベントを送り、電源メニューからSleepを選んだ。RTCで復帰させ、起動ID、描画プロセスのPIDと開始時刻、DRMの描画面とフレームバッファ、ALSAの再生状態を前後で比較した。復帰後に入力を送り、入力デバイスの保持と、取得できた範囲で描画やアプリの反応を照合した。Apps内の設定・結果画面は実際のFEのSTARTメニューから開いた。

## エミュレータとゲーム

| 経路 | 検体 | 結果 |
| --- | --- | --- |
| SA / PPSSPP | Star Soldier | PID 30306のまま復帰。画面更新、ALSA `RUNNING`、内蔵パッドのFDを確認。 |
| SA / OpenBOR | Dragon Ball | PID 497のまま復帰。画面更新、内蔵パッドのFDを確認。音のある場面でPCMが `RUNNING`。 |
| SA / PCSX-ReARMed | chroQW | 起動時にSDLが `drmModeSetCursor` で失敗し終了。再試験も同じでSleepは未到達。 |
| SA / YabaSanshiro | The Tower | 起動時にSDLのGBM/EGLサーフェス作成に失敗し終了。再試験も同じでSleepは未到達。 |
| SA / DraStic | New Super Mario Bros. | 起動時にARM32のALSAがARM64の `libasound_module_pcm_plumos_hotplug.so` を開いて `ELFCLASS64` エラー。終了コード134。Sleepは未到達。 |
| RA / gpSP（GLES） | 伝説のスタフィー | PID 2270のまま復帰。画面更新とALSA `RUNNING` を確認。復帰後にFNを送り、メニュー遷移に伴う描画・PCM停止を観測。 |
| Pyxel | Dungeon Antiqua | PID 12415のまま復帰。画面更新、ALSA `RUNNING`、内蔵パッドのFDを確認。 |
| Pyxel | Finardry | 電源メニュー経由で2回とも、本体の復帰後にアプリの描画・音声が戻らず、再試験ではランチャーが終了コード0を返した。電源メニューを通さず同じ `mem` とRTCを使った比較では、PID 14257のまま画面・PCMが復帰した。 |
| Ports | Apotris | PID 22377のまま復帰。DRM制御権、画面更新、ALSA `RUNNING`、内蔵パッドのFDを確認。 |

## Apps

| 項目 | 結果 |
| --- | --- |
| File Manager | PID 18202のまま復帰。描画面と内蔵パッドのFDが戻った。 |
| Music Player | 一覧画面で復帰。検証専用WAVを再生中に再試験し、PID 5833で描画とALSA `RUNNING` を確認。WAVは試験後に削除した。 |
| RetroArch | ゲーム未起動のRGUIでPID 20927のまま復帰。描画面と内蔵パッドのFDを確認。 |
| Game Gear | 一覧画面でPID 22322のまま復帰。描画更新と内蔵パッドのFDを確認。 |
| PortMaster | PID 24796のまま復帰。描画更新、ALSA `RUNNING`、内蔵パッドのFDを確認。 |
| Scraping | 設定画面からSleep。同じFEプロセスで設定画面へ戻り、Bでメニューへ戻った。 |
| Pyxel Setup | 同梱のPythonモジュールの検証が成功。結果画面からSleepし、同じFEプロセスの結果画面に戻り、BでTOPへ戻れた。 |
| Update PortMaster | 既にstable版 `2026.06.23-0015` が入っていることを確認。結果画面からSleepし、同じFEプロセスの結果画面に戻り、BでTOPへ戻れた。 |
| Repair SD2 | 実行確認の画面からSleep。同じFEプロセスとAppsの同じ項目に戻り、Bで離脱できた。SD2の修復は実行していない。 |

描画・PCM・入力の確認は実機の状態とADBから送った入力に基づく。物理ボタンでの復帰、実聴、全コア・全タイトルの総当たりは今回の追加試験の範囲外。PCSX-ReARMed、YabaSanshiro、DraSticは起動を直した後にSleep試験が必要。Finardryは同じ起動経路で直接のSleepと電源メニュー経由の結果が分かれており、終了の原因は未確定。
