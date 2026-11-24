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

現行のFEに登録された196プロファイルと試験表のキーを照合した。ROMセットから代表素材を用意できた174件を実行し、再試験を含めて174件の画面提示と172件のPCMポインターの進行を確認した。22件は試験素材なし。短い計測窓での描画・PCM測定で、各タイトルの全編やスピーカーの聴感評価は対象外。テスト時のシステム音量は20%。[プロファイル別結果](rgb30-emulator-matrix.tsv)

- 代表的なNES、GB、GBAでは約59 fps。Pyxelは約30 fps。PSPの『Star Soldier』は約59 fps。
- YabaSanshiroのRetroArch版は初回の短い計測で画面提示を検出できなかった。待ち時間を延ばした再試験で『The Tower』のタイトル映像とPCMを確認し、約59 fpsを記録した。
- 『The Tower』のYabaSanshiro単体版で約16 fps、Beetle Saturnで約24 fps。Beetle SaturnとVirtual JaguarとPC-FXの測定窓ではALSAのXRUNも記録した。
- 2048、TI-83の測定窓でPCMは `PREPARED`。ポインターの進行は観測しなかった。Atari 8-bitのAtari800は最初に選んだBASIC ROMでPCMが進まなかったため、『Yoomp!』で再試験した。タイトル表示、720×540の描画面、約41 fpsとPCMポインターの進行を確認した。
- 『Caverns of Mars』のヘッダーなしROMは、同じ16 KiBの複数のカートリッジ種別を旧コアが判別できず、黒画面になった。MAMEのソフトウェア一覧にあるCRC `8b9b2f5e` を照合し、標準16 KiBのマッピングを選ぶよう修正した。元のROMで720×540のタイトル表示、約40.8 fps、PCMポインターの進行、FNメニューの表示を確認した。FEの起動経路でも約41 fpsとPCMポインターの進行を確認した。[MAMEのAtari 800ソフトウェア一覧](https://github.com/mamedev/mame/blob/mame0251/hash/a800.xml#L1421-L1433)
- 同じ修正版コアでAtari 5200の『Millipede』を再試験し、タイトル表示とPCMポインターの進行を確認した。
- FreeJ2ME-PlusはシステムFontconfigが無い環境で起動時に例外が出ていた。同梱フォントを指定し、『Cento』が表示され、PCMポインターが進むことを確認した。
- RetroArch、PicoArch、DraStic、PPSSPPでゲーム中のFNメニューを確認した。
- OpenBORは初回の短い計測でXRUNを1回検出した。縦横比の修正版では、タイトル表示後の20秒で約59.7 fps、PCM開始1回とポインターの連続した進行を確認した。

## Apps

| 項目 | 実機で確認した範囲 |
| --- | --- |
| Scraping | 説明文の末尾まで表示。空の試験用キャッシュからNES 1本のCRCを照合し、サムネイルPNGを取得。 |
| File Manager | 2ペインの表示とSD2のROM一覧。 |
| Music Player | 試験WAVの一覧と再生表示。内蔵PCMの進行を確認し、WAVは撤去した。 |
| RetroArch | RGUIのメインメニューを720×720で表示。 |
| Pyxel Setup | 同梱のPyxel、pygame、NumPy、Pillowを読み込み、処理は終了コード0。 |
| PortMaster | 機種のMali GLES2で起動し、初回案内を720×720で表示。 |
| Update PortMaster | stableを照会し、インストール済みと同じ2026.06.23-0015で終了コード0。 |
| Repair SD2 | 実機で修復前の確認表示を開き、Bで戻った。 |
| Game Gear | CPUガバナーの制御が使えない状態で起動。SD2の20本とSELECTメニューを表示し、メニューからFEに戻れた。DRM画像の表示領域は720×540で上下の余白は各90 px。 |

Appsの試験中、自動入力がメニューからずれて電源オフを要求した。終了処理はランタイムのアンマウントで中断され、後続の試験では入力ごとにメニューの位置を検証した。試験SYSTEMの正常起動後、SD2が再度読み書き可能であることを確認した。

最初のエミュレータ表を取ったSYSTEMのSHA-256は `4a96a540923a0f95401ed8efcacfa478fc75e2e300cf59b0cc7ff5b5b20314d4`。Appsの修正版は `7698c019129144c63fcb76e8a2d1c99496644904ed06683ff564ef4b38531af1`。Atari800の修正を含む最終版は `960d20c102d53ceda7bd33fdc5a96d98eb52e38d71c2990215c3ca6f1fcf5469`。ARM64 Dockerで組み立て、Wi-Fi ADBで差分を送り、復元したSYSTEMのSHA-256を検証して試験起動した。最終版を既定に設定し、FEが復帰してp5とSD2が読み書きマウントされることを確認した。復旧に使えるよう、直前のSYSTEMもp4に保管した。ブートパーティション上のKERNEL、出荷用SYSTEMとDTBのハッシュは更新前後で一致した。試験後は音量設定を元の値に戻した。

Game Gearは640×480の内部描画と4:3を維持し、パネルの解像度に収まる矩形へ拡縮する。既存の並列描画で拡縮し、上下または左右の余白を黒で描く。Scrapingは説明が標準サイズで収まらない場合、その行だけ小さいフォントで描く。サムネイル名の一覧を取得できない場合のURL生成には、SYSTEM同梱のPythonを使う。PNG取得試験では、サムネイル名のキャッシュが空のまま、CRCで一致したNESタイトルのPNGを1件取得した。

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

同じJELOSカーネルのSYSTEMに含まれる `ipv6.ko` を `--ipv6-module` に渡すと、Mac側の同じ待ち受けで、ADB接続のたびに未ロードのモジュールを補う。実機再起動直後の未ロードをSSHで確認し、その後に同じ待ち受けへの `adb connect` と `adb shell` が成功した。ロード後も `wlan0` のIPv6は無効で、ADBは名前空間内のループバックで待ち受けた。

USB側では、接続したままDWC3のランタイム電源を一時的に有効化し、コントローラーが `device` モードで動作する状態でUSB gadgetの論理切断と再接続を実施した。復帰後も `DCP=1`、UDCは `not attached`、MacのUSBツリーにRGB30は現れなかった。試験後はランタイム電源の設定を元へ戻した。

内蔵スピーカーのALSA出力を測定した。USB DACは接続されておらず、実機の音と出力切替は未測定。
