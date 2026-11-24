# RGB30のエミュレータとAppsの実機検証

RGB30の内蔵パネルは720×720。RG353Mと同じ起動経路を使い、既存SDのSYSTEMを試験起動で更新した。更新後はp5とTF2の `mmcblk2p1` を読み書きでき、起動後にWi-Fiへ自動接続した。

## 表示

DRMのフレームバッファから画像を取得し、表示矩形と合わせて確認した。PCMの状態とハードウェアポインターの進行を同時に記録した。

| 経路 | RGB30での表示 |
| --- | --- |
| RetroArch / QuickNES | NESの描画面は720×551、上端84 px。コアのアスペクトとクロップを反映した上下中央配置。 |
| RetroArch / Gambatte | GBの10:9を720×648で表示。上下36 pxずつの余白。 |
| RetroArch / gpSP | GBAの3:2で上下中央に表示。 |
| RetroArch / Genesis Plus GX | Game GearのLCDプリセットは640×480。上下120 px、左右40 pxずつの余白。 |
| PicoArch / QuickNES | 4:3の720×540、上端90 px。旧版は640×480を左上に配置していた。 |
| PicoArch / gpSP | GBAの3:2の画面を720×480で中央に配置。上下の余白は120 px前後。 |
| DraStic | 4:3の720×540、上端90 px。旧版は640×480を左下に配置していた。SDLの実表示サイズに合わせてGLESビューポートを設定した。 |
| PPSSPP | PSPの480×272の比率で720×408相当に配置。上下約156 pxの余白。 |
| Pyxel / Finardry | 画面の比率を維持して720×675で中央に配置。表示先の解像度はfbdevから取得する。 |
| RetroArch / FreeJ2ME-Plus | `Cento.jar` を540×720で表示。左右90 pxずつの余白。 |
| OpenBOR / Dragon Ball | 正方形の画面で縦方向の引き伸ばしを解消。720×540、上下90 pxずつの余白。 |
| Ports / Playload | 個別のゲームランタイムが720×720を取得。文字と操作ガイドを確認した。 |

RetroArch、PicoArch、Pyxelは、RGB30でCPUガバナーの `policy0` が公開されない場合も起動できるようにした。利用可能な機種では従来のガバナー設定と復帰を行う。旧試験でSD上に置いたRetroArchランチャーとPicoArchバイナリは、SHA-256が一致するものを初回マウント時に退避した。既存SDの更新でも、SYSTEMの収録物を使うことを実機で確認した。

## 起動試験

現行のFEに登録された196プロファイルと試験表のキーを照合した。ROMセットから代表素材を用意できた174件を実行し、再試験を含めて174件の画面提示と171件のPCMポインターの進行を確認した。22件は試験素材なし。短い計測窓での描画・PCM測定で、各タイトルの全編やスピーカーの聴感評価は対象外。テスト時のシステム音量は20%。[プロファイル別結果](rgb30-emulator-matrix.tsv)

- 代表的なNES、GB、GBAでは約59 fps。Pyxelは約30 fps。PSPの『Star Soldier』は約59 fps。
- YabaSanshiroのRetroArch版は初回の短い計測で画面提示を検出できなかった。待ち時間を延ばした再試験で『The Tower』のタイトル映像とPCMを確認し、約59 fpsを記録した。
- 『The Tower』のYabaSanshiro単体版で約16 fps、Beetle Saturnで約24 fps。Beetle SaturnとVirtual JaguarとPC-FXの測定窓ではALSAのXRUNも記録した。
- 2048、Atari 8-bitのAtari800、TI-83の測定窓でPCMは `PREPARED`。ポインターの進行は観測しなかった。
- FreeJ2ME-PlusはシステムFontconfigが無い環境で起動時に例外が出ていた。同梱フォントを指定し、『Cento』が表示され、PCMポインターが進むことを確認した。
- RetroArch、PicoArch、DraStic、PPSSPPでゲーム中のFNメニューを確認した。
- OpenBORは初回の短い計測でXRUNを1回検出した。縦横比の修正版では、タイトル表示後の20秒で約59.7 fps、PCM開始1回とポインターの連続した進行を確認した。

## Apps

| 項目 | 実機で確認した範囲 |
| --- | --- |
| Scraping | 設定画面を表示。英語フッターの長い説明が右端で切れる。 |
| File Manager | 2ペインの表示とSD2のROM一覧。 |
| Music Player | 試験WAVの一覧と再生表示。内蔵PCMの進行を確認し、WAVは撤去した。 |
| RetroArch | RGUIのメインメニューを720×720で表示。 |
| Pyxel Setup | 同梱のPyxel、pygame、NumPy、Pillowを読み込み、処理は終了コード0。 |
| PortMaster | 機種のMali GLES2で起動し、初回案内を720×720で表示。 |
| Update PortMaster | stableを照会し、インストール済みと同じ2026.06.23-0015で終了コード0。 |
| Repair SD2 | 実機で修復前の確認表示を開き、Bで戻った。 |
| Game Gear | CPUガバナーの制御が使えなくても起動できるよう修正。SD2の20本を一覧表示。一覧は640×480を左上に描画するため、正方形画面用の配置に課題が残る。 |

Appsの試験中、自動入力がメニューからずれて電源オフを要求した。終了処理はランタイムのアンマウントで中断され、後続の試験では入力ごとにメニューの位置を検証した。試験SYSTEMの正常起動後、SD2が再度読み書き可能であることを確認した。

実機で検証した最終SYSTEMのSHA-256は `4a96a540923a0f95401ed8efcacfa478fc75e2e300cf59b0cc7ff5b5b20314d4`。これを既存SDの既定に設定し、FEの表示とSD1のp5・SD2の読み書き、試験前の音量設定を確認した。

## USBと試験用の接続

既存のUSBケーブルを接続した状態で、RGB30の充電器検出は `DCP=1`、`SDP=0`、UDCは `not attached`。ADB gadgetとFunctionFSは起動していた。gadgetの再起動とソフトウェアでのUSBロール変更後も同じ状態だった。MacからUSB ADBを開くには、データ接続として列挙される必要がある。

Wi-FiのSSHを使い、別のネットワーク名前空間でADBをループバックに限定して起動した。MacのループバックからSSH経由で接続し、`adb shell` と `push`、`pull`、転送ファイルのSHA-256を確認した。USBの抜き差しやSDイメージの再書き込みを伴わず、SYSTEMの更新と実機検証に使った。

`prototype/adb-over-ssh.py` は、この経路をSSHで認証済みのMacから開く。ADBプロセスは接続ごとに独立し、USB FunctionFSと実機のストレージマウントから分離する。`adb push` と `adb pull` は `/run` などの一時領域を使用し、実機のマウントを参照するシェルコマンドは `busybox nsenter -t 1 -m -n` で実行する。RGB30でSSH接続、ADB通信、ファイル往復と切断を確認した。

SSHのホスト名を `rgb30` として登録済みの場合の操作。

```sh
python3 prototype/adb-over-ssh.py root@rgb30
# 別のターミナルで実行
adb connect 127.0.0.1:15555
adb -s 127.0.0.1:15555 shell busybox nsenter -t 1 -m -n /bin/sh
```

IPv6モジュールが未ロードの起動では、同じJELOSカーネルのSYSTEMに含まれる `ipv6.ko` を `--ipv6-module` に渡す。試験ではモジュールをロードした後も `wlan0` のIPv6は無効で、名前空間内のループバックのみでADBが待ち受けた。

内蔵スピーカーのALSA出力を測定した。USB DACは接続されておらず、実機の音と出力切替は未測定。
