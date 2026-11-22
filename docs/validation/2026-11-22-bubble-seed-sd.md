# RG353M向けの初回セットアップ付きSDイメージ

2026年11月22日（JST）。RG353Mで起動したJELOS 20240206再ビルド版と、実機でルートとして起動確認したBubble入り `SYSTEM` を入力に、Bubble ARM64 Docker環境でSDイメージを生成します。`prototype/build-bubble-sd.sh` が組み立て、`prototype/verify-bubble-sd.sh` がイメージの複製を使って初回起動のストレージ処理と復旧経路を検証します。

再ビルド済みのJELOS rawイメージ、`build-bubble-system.sh` の `SYSTEM`、`build-boot-splash.sh` の生成先を渡します。

```sh
./prototype/build-bubble-sd.sh JELOS.img SYSTEM compiled/boot-splash plumOS-RK3566-RG353M.img
./prototype/verify-bubble-sd.sh plumOS-RK3566-RG353M.img
```

## 起動と初回ストレージ設定

出荷時のSDイメージは約2.05 GiBです。RockchipのIDB、U-Boot FIT、`resource.img`、JELOSの `KERNEL`、全7機種のDTB、`extlinux.conf` およびGPTの既存4エントリを維持します。`p3` に実機確認済みの `SYSTEM`、32 MiBの `p4` にセットアップと更新のスクリプトを入れます。

初回起動で `/flash` と `/storage` が同じ起動SDの `p3`・`p4` であることと、既定の開始位置・UUIDを照合します。`p4` を4 GiBに広げ、残りに利用者用 `p5` を作ります。GPTの更新後に再起動し、認識された領域でext4を拡張、`p5` をFAT32の `PLUMOS` として初期化します。`/storage/user` にマウントし、`Roms`・`BIOS`・`Images` を作ります。次回以降は既存領域をマウントします。既に別のファイルシステムの署名がある `p5` は保持します。対象は8 GB以上のSDカードです。

初回セットアップでは、BubbleのARM64 Docker環境にあるDebianの `sfdisk` 2.38.1と依存ライブラリを使います。GPTを試験した際に、JELOS同梱の `sgdisk` はデバイス指定を正常に処理できませんでした。配布イメージには `sfdisk` のライセンス情報も収録しています。

## ADB更新と復旧

初期状態ではFATの `SYSTEM` からBubbleとADBが立ち上がります。更新する `SYSTEM` を `/storage/plumos-rk3566/system/SYSTEM.partial` に置き、`boot-system publish SHA256` で照合し、`boot-system trial SHA256` で次回だけ起動できます。USB ADBの大きいファイル転送が中断した場合は、SSHと `rsync --partial --inplace` で続きから転送できます。

確認できた更新を既定にする操作は `boot-system keep` です。起動が確認されなかった場合は次回の電源投入でFAT上の出荷時 `SYSTEM` に戻ります。ADBから `boot-system stock` と再起動でも戻せます。ADB・SSHの両方が使えない場合は、電源を切ってMacにSDを接続し、`JELOS` ボリューム上の `mount-storage.sh` を改名するとFAT上の `SYSTEM` が選ばれます。コマンド本体は実機の `/storage/plumos-rk3566/system/boot-system` にあります。

## 検証結果

生成したrawイメージは2,198,863,872バイト、圧縮版は1,336,887,939バイトです。圧縮版のSHA-256は `a8785a077bd9fecf4f982cb6d8c5cdaa1c83459a6d4e575fcd591954625d2c8b` です。初期GPTの主・副ヘッダー、SD先頭16 MiB、カーネル、DTBと起動設定を入力イメージと照合しました。

Dockerで8 GiBに拡げた複製を使い、GPT更新、再接続後のext4拡張、FAT32の作成、既存ファイルの保持を確認しました。別のファイルシステムを置いた場合は処理が止まり、そのファイルシステムが残ることも確認しました。起動済みのシステムで使ったのと同じ選択処理で、更新候補の登録・試験起動用マウントと、出荷時の `SYSTEM` への復旧用マウントを確認しました。初回セットアップ付きのこのイメージのRG353M起動は、SDへの書き込み後に確認します。
