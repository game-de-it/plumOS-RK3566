# RG353MでのBubbleユーザランド検証

2026年11月22日（JST）。対象は実機起動済みのJELOS 20240206 Docker再ビルド版です。SSHで `boot=UUID=2211-3302`、`/flash/SYSTEM` のSHA-256 `b0028dc48926ad49ab2d0156fec2c64f16f406e2f463ded4cc84eb8dcaac4a83`、Anbernic RG353Mの機種名を確認しました。

Bubbleの `ec81d42c0c2c39e7a32973bfe4df9b3027512a5d` から、BubbleのARM64 Docker環境でフロントエンドとライブラリスキャナーをビルドしました。Bubbleの入力定義は実機で以前取得した A=305、B=304、X=307、Y=308 に対応します。設定・フォント・テーマ・言語ファイル、USB用adbd、RG353M向けランチャーを組み込みました。ストレージ初期化、パーティション変更、Bubble固有の周辺機器設定は、この工程では適用していません。

## 成果物と実機への適用

- `output/bubble-system/SYSTEM` はBubbleとADBを収録したSquashFSです。1,309,425,664バイト、SHA-256 `7f8197ee6a5f68b42c6270cf4c3d778b88546435ad60fb2e99c3d877dacd7f28`。起動の引き渡しにはJELOSのsystemdを使用します。
- `output/bubble-system/bubble-userland.squashfs` は同じユーザランドを収録する実機検証用のSquashFSです。13,426,688バイト、SHA-256 `aac192cc82a7792089e0b410857486212a3dd45596582522ecc257730332cbb0`。フロントエンド、スキャナー、adbd、起動スクリプトの内容が `SYSTEM` 内と一致しました。
- 実機では `/storage` に検証用SquashFSとサービス定義を配備し、`/run/plumos/bubble` に読み取り専用でマウントしました。EmulationStationを停止してからBubbleを起動し、`/tmp/plumos-fe-ready` を確認しました。実機の `/flash/SYSTEM` はJELOSのままで、完成した `SYSTEM` を使ったルートファイルシステムでの実機起動は未検証です。
- USBハブ経由でADBのシェルに接続し、40バイトのファイルをpush・pullして照合しました。再起動前後のブートIDの変化、Bubble・ADB・読み取り専用マウントの自動再開を確認しました。Mac上にはUSB機器が表示される一方、再列挙後にADB一覧から消えることがありました。MacのADBサーバーを `ADB_LIBUSB=1` で再起動し、同じ機器への接続を復旧できました。
- SD先頭16 MiBのハッシュは検証の再起動前後で `e2a6e7f2a0139d322b009116cb04da26a446b11dfe35e212f4dbeb5c455c7cee` でした。`KERNEL`・RG353M用DTB・`extlinux.conf`・`SYSTEM` も一致し、再起動後の `/flash` は読み取り専用でした。
- ユーザーが再起動後の内蔵画面でBubbleのメニュー表示と、十字キー・A（決定）・B（戻る）の操作を確認しました。同時にADB経由の `evtest` で十字キーと、Aの `BTN_EAST`（305）、Bの `BTN_SOUTH`（304）を取得しました。

## 容量

実機のFAT領域 `p3` は2 GiBで、空きは778 MiBでした。完成した1.22 GiBの `SYSTEM` を既存の `SYSTEM` と同時に置ける容量がありません。検証用SquashFSの転送は約12.8 MiBで、SD全体のイメージ転送が不要でした。

検証済みJELOSの配布用rawイメージは約2.05 GiBで、`p4` は32 MiBの状態から初回に拡張します。将来の配布用イメージでさらに小さくする場合は、まず `p3` を `SYSTEM`・カーネル・DTBを収められる容量に絞り、末尾の `p4` を小さく生成する方法があります。既存のSDのパーティションを縮める作業とは独立です。
