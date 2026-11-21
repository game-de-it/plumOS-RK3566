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
