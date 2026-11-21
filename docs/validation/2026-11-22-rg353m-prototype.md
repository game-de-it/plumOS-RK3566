# RG353M 試作SDの実機検証

2026年11月22日（JST）。対象は `plumOS-353M-prototype.img`（SHA-256 `9f1a0f132d3a89cb4f133b1b53fdfea3b42cd1e7db8aacbc6d7c258717ec178a`）。mini PLUSのフロントエンドは `baa7143a0bddb1aef5ebc8ee0c8c3358a6aa8d35`。

| 項目 | USB ADBで確認した結果 |
| --- | --- |
| 試作SDからの起動 | 実機モデルはAnbernic RG353M、Linux 4.19.172。試作のフロントエンドリビジョンを読み取れた。 |
| マウント | `/flash` はmmcblk1p3のFAT32、`/` は読み取り専用SquashFS、`/storage` はmmcblk1p4の読み書き可能なext4。初回拡張後の `/storage` は53.9 GiB。 |
| フロントエンド | `emustation.service` はactive。97件のシステム定義をロードし、ライブラリスキャンとインデックス書き出しを完了。 |
| 表示 | フロントエンドが最初の描画完了マーカーを作成。内蔵DSI-1に 640×480 のフレームバッファが割り当てられ、DRMの出力がactive。 |
| USB ADB | `plumos-usb-adb.service` はactive。FunctionFSは `fcc00000.dwc3` にbindし、USBはconfigured。Macからシェルで起動ログを取得。46バイトのテストファイルをpush・pullし、バイト一致を確認。 |
| 起動後のsystemd | 採取時点でfailedのユニットは0件。 |
| ゲームパッド | `retrogame_joypad` からSTART (315)、十字キー上 (544)・下 (545)・右 (547)、フェイスボタンの押下・解放を採取。STARTでトップからメニューへ遷移し、上下でカーソルが0 → 1 → 0と移動。初回の操作ログはフロントエンド上の論理アクションで、その後の押下試験で物理A・Bの逆転を特定した。 |

## A・Bマッピングの修正

本体に印字された A → B → X → Y の順に押して、初版と修正版のevdevコードおよびアクションをUSB ADBで照合しました。

| 本体の印字 | evdevコード | 初版のアクション | 修正版のアクション |
| --- | --- | --- | --- |
| A | 305 (`BTN_EAST`) | `b` | `a` |
| B | 304 (`BTN_SOUTH`) | `a` | `b` |
| X | 307 (`BTN_NORTH`) | `x` | `x` |
| Y | 308 (`BTN_WEST`) | `y` | `y` |

実測と一致するmini PLUSのビルド時設定 `PLUMOS_MINI_PLUS_INPUT` を有効にしました。修正版バイナリをADBで転送し、systemdの一時設定で稼働中のフロントエンドを交換しました。稼働プロセスのバイナリをSHA-256で照合し、AでトップからROM一覧へ進み、Bでトップへ戻ることを画面操作とログの両方で確認しました。XとYのアクションも印字どおりでした。

現在の初版SDに対する一時設定は再起動で解除されます。修正版SDイメージの `SYSTEM` には、この変更を組み込んだバイナリを収録します。

修正版イメージは `plumOS-353M-prototype-r2.img`（SHA-256 `8272d9110c12b1b6ef62a49c61bb757fdb95703b46387f7afe29f2080854a023`）。FAT32から `SYSTEM` を再抽出し、収録したフロントエンドが実機で検証した修正版バイナリとバイト単位で一致することを確認しました。

## 起動時のplumOSロゴ

実機からADBで採取した `/etc/issue` に、起動時のJELOSのブロック文字が入っていました。カーネル内のinitramfsを展開し、`load_splash` が `SYSTEM` の `/etc/issue` を既存のコンソールへ出す箇所を確認しました。r3では `SYSTEM` 内のこのファイルをplumOSの文字ロゴに差し替えています。U-Bootやカーネルの変更は不要です。

ビルドでは、完成イメージのFAT32から `SYSTEM` を読み戻し、収録した `/etc/issue` をソースと比較します。r3を書き込んだSDでの起動時目視確認は未実施です。

r3のSHA-256は `62120d0cf4740dc48162484e1dd57c18d00d0315daef681753e6c0665cbbbc22`。FAT32から読み戻したロゴはソースと一致し、フロントエンドとADBのバイナリはr2とバイト単位で一致しました。

### 既存SDへのADB更新

初版の試作SDを挿した状態で、USB ADBからr3の `/etc/issue` とA・B修正済みフロントエンドを約1.6 MBの差分として転送しました。JELOSの `post-sysroot.sh` は、ブート時に `load_splash` が走る前に、この2ファイルを読み取り専用の `SYSTEM` の該当パスへバインドします。

同じSDのまま `systemctl --no-block reboot` を実行し、新しいブートIDとADBの再接続を確認しました。再起動後の `/etc/issue` と実行中のフロントエンドのSHA-256は、転送したファイルと一致しました。フロントエンドとADBはactiveで、初回描画完了マーカーが作成されました。
