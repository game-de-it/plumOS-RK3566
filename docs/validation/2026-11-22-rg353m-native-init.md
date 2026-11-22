# RG353MのplumOS init移行

2026年11月22日（JST）。初回セットアップ済みのSDを挿したまま、USB ADBでplumOS initを導入した。JELOS 20240206のU-Boot、カーネル内のinitramfs、DTB、extlinux設定とSDのGPTを使う。カーネル、RG353MのDTB、extlinux設定のSHA-256を作業前後で照合し、p4とp5の開始位置も確認した。

## 実機結果

| カーネル起動からの経過 | systemd | plumOS init試験 | plumOS init既定 |
| --- | ---: | ---: | ---: |
| Bubbleプロセスの生成 | 17.10秒 | 3.56秒 | 3.61秒 |
| plumOS initの計測開始 | — | 3.09秒 | 3.14秒 |
| Bubble描画とADBバインドの確認 | — | 4.81秒 | 4.86秒 |

プロセス生成は同じRG353M・SD・SYSTEMの `/proc/<pid>/stat` 第22フィールドを `CLK_TCK=100` で秒換算した値。既定起動で13.49秒短縮した。時間にはU-Bootの実行を含まない。既存のライブラリキャッシュを使った通常の再起動で計測した。

- PID 1は `/usr/bin/busybox sh /storage/plumos-rk3566/init/init`。内蔵パネルの初回描画と十字キー・A決定・B戻るをユーザーが確認した。ADBのUSBコントローラは `configured`。画像ロゴの640×480フレームバッファ描画マーカーも確認した。
- `mmcblk1p5`（LBA 12615680）は `/storage/user` にFATで読み書き可能。USB ADBで42バイトをpush・pullし、同一内容であることを確認した。既存の初回セットアップ完了マーカーは `v1`。
- 一度だけのinit試験を実行し、ADBの `boot-system reboot` で再起動してsystemdとUSB ADBが復帰した。別の試験では、同一内容のSYSTEMをp4へ複製してSHA-256で登録し、更新候補がplumOS initで起動して `healthy` になることを確認した。
- `init-keep` の後、Bubbleが使う電源スクリプトをADBから呼び出して再起動した。FAT上のSYSTEMからplumOS initが起動し、Bubble・ADB・p5が使える状態を確認した。最終状態は `active=stock`、`init=plumOS`、`init-default=yes`。電源オフはコマンドの振り分けをdry-runで確認した。
- 初回セットアップは既存の `provision-storage` を使う。GPTの更新を通知する終了コード75をplumOS initが受け取り、次回のinit試験を予約してから再起動する。今回の実機はp5を保持したまま試験した。Dockerで8 GiBに広げた複製を使い、GPT更新、再接続後のext4拡張とFAT32作成、利用者データの保持、initの選択とフォールバックを検証した。RG353Mでの新規p5作成を含む一連の起動は、この版では未計測。

Docker生成のrawイメージは2,198,863,872バイト。入力JELOSとSD先頭16 MiB、GPT、カーネル、DTB、extlinux設定を照合した。

## 導入と復旧

JELOSのストレージマウントフックで、試験または既定のフラグを確認する。選択時は、initramfsの `switch_root` が実行するパスにランチャーをファイル単位でバインドする。ランチャーがplumOS initへ `exec` し、plumOS initが初回セットアップ、Bubble、ADB、同期・再起動を担当する。この起動経路のSYSTEM更新は `boot-system` が扱う。最初の試験では、JELOSのinitramfs版BusyBoxに `touch` がなく、試験フラグを消費した後にsystemdで起動した。元のinitramfsからBusyBoxを展開してアプレット一覧を照合し、フラグ作成をシェルのリダイレクトに変更した。

既存のRG353M seedには以下で導入できる。Dockerビルドで新しく作るseedには同じinitが入っているため、導入コマンドは省略できる。現在のDockerビルドでは、新規seedの初回起動からplumOS initを選択する。GPT更新による予定再起動もplumOS initへ戻る。起動失敗で `pending` が残った場合はsystemd経路で復旧できる。

```sh
./prototype/boot-system/build-native-payload.sh output/native-init
./output/adb push output/native-init /storage/plumos-rk3566/native-init-stage
./output/adb shell 'cd /storage/plumos-rk3566/native-init-stage && sh ./install-native'
./output/adb shell 'ctl=/storage/plumos-rk3566/system/boot-system; "$ctl" init-trial && "$ctl" reboot'
```

BubbleとADBを確認してから `boot-system init-keep` で既定にする。試験フラグは起動時に消費する。既定にした後でも起動失敗でフラグ `pending` が残った場合、次回は元のsystemd経路を使う。ADBから明示的に戻す場合は、以下でinitとSYSTEMの選択を既定に戻す。

```sh
./output/adb shell 'ctl=/storage/plumos-rk3566/system/boot-system; "$ctl" stock && "$ctl" reboot'
```
