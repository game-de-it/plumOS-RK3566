# RG353M向けの初回セットアップ付きSDイメージ

2026年11月22日（JST）。RG353Mで起動したJELOS 20240206再ビルド版と、実機でルートとして起動確認したFEを含む `SYSTEM` を入力に、plumOS-Bubble ARM64 Docker環境でSDイメージを生成します。`prototype/build-bubble-sd.sh` が組み立て、`prototype/verify-bubble-sd.sh` がイメージの複製を使って初回起動のストレージ処理と復旧経路を検証します。

再ビルド済みのJELOS rawイメージ、`build-bubble-system.sh` の `SYSTEM`、`build-boot-splash.sh` の生成先を渡します。

```sh
./prototype/build-bubble-sd.sh JELOS.img SYSTEM compiled/boot-splash plumOS-RK3566-RG353M.img
./prototype/verify-bubble-sd.sh plumOS-RK3566-RG353M.img
```

## 起動と初回ストレージ設定

出荷時のSDイメージは約2.05 GiBです。RockchipのIDB、U-Boot FIT、`resource.img`、JELOSの `KERNEL`、全7機種のDTB、`extlinux.conf` およびGPTの既存4エントリを維持します。`p3` に実機確認済みの `SYSTEM`、32 MiBの `p4` にセットアップと更新のスクリプトを入れます。

初回起動で `/flash` と `/storage` が同じ起動SDの `p3`・`p4` であることと、既定の開始位置・UUIDを照合します。`p4` を4 GiBに広げ、残りに利用者用 `p5` を作ります。GPTの更新後に再起動し、認識された領域でext4を拡張、`p5` をFAT32の `PLUMOS` として初期化します。`/storage/user` にマウントし、`Roms`・`BIOS`・`Images` を作ります。次回以降は既存領域をマウントします。既に別のファイルシステムの署名がある `p5` は保持します。対象は8 GB以上のSDカードです。

初回セットアップでは、plumOS-BubbleのARM64 Docker環境にあるDebianの `sfdisk` 2.38.1と依存ライブラリを使います。GPTを試験した際に、JELOS同梱の `sgdisk` はデバイス指定を正常に処理できませんでした。配布イメージには `sfdisk` のライセンス情報も収録しています。

## ADB更新と復旧

初期状態ではFATの `SYSTEM` からFEとADBが立ち上がります。更新する `SYSTEM` を `/storage/plumos-rk3566/system/SYSTEM.partial` に置き、`boot-system publish SHA256` で照合し、`boot-system trial SHA256` で次回だけ起動できます。USB ADBの大きいファイル転送が中断した場合は、SSHと `rsync --partial --inplace` で続きから転送できます。

確認できた更新を既定にする操作は `boot-system keep` です。起動が確認されなかった場合は次回の電源投入でFAT上の出荷時 `SYSTEM` に戻ります。ADBから `boot-system stock` と再起動でも戻せます。ADB・SSHの両方が使えない場合は、電源を切ってMacにSDを接続し、`JELOS` ボリューム上の `mount-storage.sh` を改名するとFAT上の `SYSTEM` が選ばれます。コマンド本体は実機の `/storage/plumos-rk3566/system/boot-system` にあります。

## 検証結果

生成したrawイメージは2,198,863,872バイト、圧縮版は1,336,887,939バイトです。圧縮版のSHA-256は `a8785a077bd9fecf4f982cb6d8c5cdaa1c83459a6d4e575fcd591954625d2c8b` です。初期GPTの主・副ヘッダー、SD先頭16 MiB、カーネル、DTBと起動設定を入力イメージと照合しました。

Dockerで8 GiBに拡げた複製を使い、GPT更新、再接続後のext4拡張、FAT32の作成、既存ファイルの保持を確認しました。別のファイルシステムを置いた場合は処理が止まり、そのファイルシステムが残ることも確認しました。起動済みのシステムで使ったのと同じ選択処理で、更新候補の登録・試験起動用マウントと、出荷時の `SYSTEM` への復旧用マウントを確認しました。初回セットアップ付きのこのイメージのRG353M起動は、SDへの書き込み後に確認します。

## RG353Mでの初回起動と通常起動

書き込み後のカードにUSB ADBで接続しました。再起動をまたぐ最初のGPT変更は、実機の `original.sfdisk` と `target.sfdisk` を照合して確認しました。カーネルの `mmcblk1p5` の開始位置はLBA 12615680です。再起動後のjournalには、`resize2fs` が `/dev/mmcblk1p4` を4,194,304個の1 KiBブロックへ拡張し、`mkfs.fat` の後に `user partition ready` を記録したことが残っていました。最初のGPT変更を行ったブートのjournalは揮発性です。

- `/dev/mmcblk1p5` はFAT32、ラベル `PLUMOS`、約109.2 GiBで、`/storage/user` に読み書き可能でマウントされました。`Roms`・`BIOS`・`Images` を確認し、USB ADBでこの領域に40バイトのファイルをpush・pullして内容を照合しました。
- FEは `/storage/user` を使って97件のシステム定義を読み込み、初回描画マーカーを生成しました。ADBの `fcc00000.dwc3` は `configured` でした。その次の起動でp5は再度マウントされ、通常起動のjournalに再フォーマットや再拡張のログはありませんでした。
- 起動画面の履歴では `c62e66a` が文字ロゴを差し替え、`557a862` がplumOS-Bubbleの画像を描画する `post-sysroot.sh` とフレームバッファ描画プログラムを導入しました。初回セットアップ付きseedではこのフックと共通ロゴの収録が漏れていました。実機へADBで追加し、再起動時に640×480 XRGB8888フレームバッファへ描画したことを確認しました。内蔵画面にplumOSの画像ロゴが表示されたことをユーザーが確認しました。
- Dockerビルドにも同じフックを追加しました。`output/bubble-sd/plumOS-RK3566-RG353M-logo.img.gz` のSHA-256は `3e4c9d60a76526a4c4f7156e779188e07fb197d5cf3cf53161de189cee7df323` です。ロゴの収録に加え、8 GiBに拡張した複製での初回処理・再セットアップ不要の通常マウント・更新時と復旧時のSYSTEM選択を再検証しました。
- このseedの実行中のPID 1は `/usr/lib/systemd/systemd`、既定ターゲットは `jelos.target` です。通常起動で `emustation.service` はカーネル起動から約16.8秒で始まり、クリティカルチェーンには `network.target`・`sshd.service`・`jelos-autostart.service`（4.44秒）が残っていました。`emustation.service` は移植したplumOSのFEを起動します。JELOSのinitramfsの汎用更新処理 `check_update` も残っています。
- 設計コミット `37c1111` とPID 1の試作 `2a6c9a2` では、JELOSのU-Boot、カーネル、DTB、initramfsを使い、固定された `switch_root` 呼び出し先からplumOSのinitへ渡します。移行対象はsystemd、`jelos.target`、JELOSのユーザランド自動起動・電源管理・汎用更新です。plumOSのinitがp5のセットアップとマウント、FEの監視、電源操作、ADB復旧を担い、通常起動ではネットワークやROM走査を待たずにFEを描画できる状態を目指します。このseedはその前の検証段階です。[起動・初回セットアップ設計](../plumos-rk3566-design.md)
