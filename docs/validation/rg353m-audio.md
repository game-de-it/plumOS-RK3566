# RG353MのUSB DACと音量ボタン

2026年11月23日（JST）。保存済みのAudio Outputが `Auto` または `USB DAC` のときは、ALSAが認識したUSB再生PCMを選ぶ。USB再生PCMがなければRK817内蔵出力を選ぶ。`Speaker` と `Headphone` は内蔵側を指定する。再生中のUSB DAC抜き差しにも対応し、ゲームを開いたまま出力先を切り替える。実機結果は[再生中USB DAC切替](2026-11-23-rg353m-live-usb-dac-hotplug.md)に記録する。

USBと内蔵PCMは同じ0〜20の音量値とRG353M用のdB曲線を使う。ALSAのSoft Volume MasterはFEの音量制御用として保持し、ゲームPCMのゲインは再生中切替プラグイン内で適用する。RG353MのDTBには `gpio-keys` の音量キーがあり、上が115、下が114。plumOS initがplumOS-Bubbleのボタン監視を音量専用で起動するため、FEを離れている間も音量を調整できる。長押しは繰り返しを適用し、操作が落ち着いてから音量を保存する。PyxelもRG353Mの共通ALSA設定を参照する。

| 確認 | 結果 |
| --- | --- |
| カーネルと入力定義 | 検証に使っている4.19.172の設定で `CONFIG_SND_USB_AUDIO=y`、`CONFIG_SND_PROC_FS=y` を確認した。RG353MのDTBバイナリで音量キーと自動リピートを確認した。 |
| ARM64 Docker | plumOS-Bubbleの固定リビジョンにパッチを適用し、FEと音量監視をコンパイルした。生成した `SYSTEM` に音量監視、出力選択、音量操作の実行ファイルを確認した。 |
| USB機器の選択 | 模擬ALSAデバイスでUSB再生PCMの選択、録音専用USB機器の除外、Speaker/Headphoneの指定、USB取り外し後の内蔵出力への復帰を確認した。 |
| 音量入力 | ARM64バイナリにLinux入力イベントを渡し、単押し、カーネルの重複リピートの除外、長押し、保存を確認した。既存設定に音量キーがない場合も他の設定が残った。 |
| RG353Mの音量経路 | 稼働中のRG353Mで、生成済みの音量監視を隔離設定で起動した。実機の `gpio-keys` に上下のイベントを送り、保存値が4 → 5 → 4、RK817のSoft Volume Masterが215 → 221 → 215になった。試験後に元の音量を復元した。 |
| RG353MのUSB DAC | OTG接続のCX31993を `hw:2,0` として選んだ。48 kHz・ステレオの試験音を `plumos_output` で再生し、USB側のPCMが `RUNNING` の間に実機の入力ノードから音量を変更した。共通ミキサーで221と215を読み戻した。DAC接続中も `Speaker` 指定で内蔵PCM `hw:0,0` が選ばれた。 |

上表のraw 215/221は当時の音量曲線の記録。後続の[小音量向け曲線の調整](2026-11-23-rg353m-volume-curve.md)で現在の割り当てを変更した。

## ADBの再接続調査

MacはUSBハブ経由でRG353Mを列挙し、ADBのインターフェースと両方向のバルクエンドポイントを取得した。Mac側のADBを再起動し、標準USBバックエンドとlibusbの両方で `offline` を観測した。libusbのトレースではMac側の `CNXN` 送信開始まで見え、応答パケットは取得できなかった。Wi-Fiでは本体のping応答を確認した。NW Serviceを有効にした後、SSHは公開鍵認証まで、Sambaは `SDCARD` 共有へのアクセスまで成功した。TCP ADBは引き続き接続拒否だった。USBの列挙より後のADB接続確立段階で止まっている。

Samba経由で本体のログとデバイス状態を取得した。ケーブル切断時にadbdは `Cannot send after transport endpoint shutdown` でUSBトランスポートを終了した。その後DWC3はUSBを再構成し `configured` に戻った。FunctionFSのep0〜ep2を開いたままのadbdが残っていたが、新しいADB接続は成立しなかった。NW ServiceのADBスイッチは次回の起動ポリシーを更新する動作のため、動作中のadbdの再初期化にはならない。adbdだけを終了するとplumOS initがFunctionFSとadbdを起動し直し、MacからのADBシェル接続が復帰した。本体のuptimeと起動ログは継続していた。

実機では稼働中のOSに生成済みバイナリを転送して試験した。完全な `SYSTEM` での起動、ボタンの物理押下、DACの聴感確認は未実施。生成した `SYSTEM` のSHA-256は `a5e996da2b97794b3ab0840a770696a6576c4ed7038f267d71c4f4c2c705b100`。
