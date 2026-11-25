# plumOS-RK3566 開発者ガイド

[English](README.md) · [ドキュメント索引](../README.ja.md) · [ユーザーガイド](../user/README.ja.md)

## システム構成

共通イメージはJELOS 20240206のRK3566用ブートチェーンを使います。パッチを適用したU-Boot FITは、CPUレギュレーターに応じてRGB30 r1/r2のデバイスツリーを選び、RG353VはUSB接続中の電源投入にも対応します。Linux 4.19.172とextlinux・initramfsの引き渡しを維持し、再構成したSYSTEMからplumOS init、Bubble、デバイスサービスを起動します。[ブート方式と機種対応](../boot-and-device-support.md) · [JELOSのソースリビジョン](../jelos-20240206-source.md)

| 領域 | 役割 |
| --- | --- |
| TF1 p1・p2 | U-Boot FITと機種判定用リソース |
| TF1 p3、`/flash` | ブートファイルと出荷時の `SYSTEM` |
| TF1 p4、`/storage` | 書き込み可能なext4。ランタイム、設定、セーブ、ログ、試験用SYSTEMを保存。 |
| TF1 p5、`/storage/user` | 初回起動時に作成するFAT32の `PLUMOS` ボリューム |
| TF2、`/run/media/sd2` | 任意のROM・BIOS用メディア。選択されたDTBの `mmc2` エイリアスでコントローラーを特定。 |
| `/usr/lib/plumos-353m/frontend` | SYSTEMに格納した出荷時ランタイム。読み取り専用の下層。 |
| `/storage/plumos-rk3566/frontend` | 書き込み可能で永続化される上層を重ねたランタイム |

内部パスの `plumos-353m` は互換性のため維持しています。選択された実機は `/proc/device-tree/model` で確認します。initramfsが呼び出す `/usr/lib/systemd/systemd` はplumOS initへのシンボリックリンクです。稼働中のinitは `/dev/plumos-native-init` または `/proc/1/exe` で確認できます。[ランタイムとストレージの記録](../rk3566-runtime.md)

## ビルドと変更箇所

- エミュレータのビルドで、固定したBubbleとV90Sの入力にRK3566用パッチを適用します。SYSTEMの組み立てでフロントエンド、エミュレータ、Apps、デバイスサービス、ARM64ユーザーランドを収録します。イメージ生成でそのSYSTEMと起動ファイルを共通SDに配置します。[Dockerビルド手順](build.ja.md)
- カタログやランチャーの変更は通常のビルド経路に入れ、フロントエンドから起動して確認します。フロントエンドとエミュレータのDRMの引き渡しを維持し、実行ファイル、マニフェスト、チェックサムをそろえます。[ランタイム検証スクリプト](../../prototype/emulators/verify-release-runtime.py)
- 共通のRetroArchパッチでは、ゲーム入力の抑制前にSELECT＋Bを判定し、内蔵のFNイベントも拾います。PicoArchと単体エミュレータは、RGB30とRK2023でSELECT＋STARTを使います。入力を変更したらRetroArchの両方の押し順と通常操作を確認します。[RetroArchのパッチ](../../prototype/emulators/retroarch-select-b-menu.patch) · [単体版のメニュー設定](../../prototype/emulators/configure-standalone-menu-chords.py)

## SYSTEMの試験起動と復旧

対応する既存SDでユーザーランドの変更を試す手順です。ゲームを終了し、ADBの対象を1台に絞るかシリアル番号を指定してから、転送先の `/storage` に必要な空きがあることを確認します。

```sh
system_file=output/release-work/system/SYSTEM
state=/storage/plumos-rk3566/system
boot_ctl="$state/boot-system"
digest=$(shasum -a 256 "$system_file" | awk '{print $1}')

adb devices -l
adb shell "$boot_ctl status; df -h /storage"
adb shell "test ! -e $state/SYSTEM.partial" &&
  adb push "$system_file" "$state/SYSTEM.partial" &&
  adb shell "$boot_ctl publish $digest && $boot_ctl trial $digest && $boot_ctl reboot"
```

再起動後は、起動中のハッシュ、フロントエンドの準備完了、変更に関係する機能を確認します。確認後に `keep` で既定へ反映します。試験予約は次の1回で消費され、`keep` する前の次回起動では前の既定または出荷時のSYSTEMが選ばれます。

```sh
adb shell 'cat /dev/plumos-system-active /tmp/plumos-fe-ready'
adb shell 'grep -E " /storage/user | /run/media/sd2 " /proc/mounts'
adb shell "$boot_ctl status"
adb shell "$boot_ctl keep"
```

ADBで接続できる場合は `boot-system factory` で試験予約と既定を解除し、次回起動で `/flash/SYSTEM` に戻せます。復旧用に起動確認済みのカードかカードのバックアップを保管します。ユーザー向けの `System Update` は署名済みの適合パッケージを使う別経路です。[起動先の選択処理](../../prototype/boot-system/mount-storage.sh) · [ランタイム更新とロールバック](../rk3566-runtime.md)

## 実機検証

各記録は試験時に使ったイメージまたはSYSTEMに対する結果です。リリース候補では、同じ機能を配布対象の成果物で確認します。

| 機種 | 検証記録 |
| --- | --- |
| RG353M | [エミュレータの試験表](../validation/2026-11-22-rg353m-emulator-matrix.md) · [Wi-Fi起動](../validation/rg353m-wifi-boot.md) · [スリープ復帰](../validation/2026-11-23-rg353m-sleep-matrix.md) |
| RG353V | [ランタイム・メニュー・Apps・電源管理](../validation/2026-11-25-rg353v-runtime.md) · [USB接続中の電源投入](../validation/2026-11-25-rg353v-usb-cold-boot.md) |
| RG503 | [ランタイムとUSB ADBの再試験](../validation/2026-11-25-rg503-runtime.md) · [SD2](../validation/2026-11-25-rg503-sd2.md) |
| RGB30 r1 / r2 | [両方の基板での共通イメージ起動](../validation/2026-11-25-rgb30-unified-image.md) · [r2のランタイム](../validation/2026-11-24-rgb30-emulators.md) |
| RK2023 | [初回起動とUSB認識](../validation/2026-11-25-rk2023-boot.md) · [ランタイム・音声・メニュー](../validation/2026-11-25-rk2023-runtime.md) |

## リリース時の確認

ソースのコミット、バージョン、成果物のSHA-256、試験した実機を記録します。候補イメージを新規カードに書き、初回ストレージ準備、電源断からの起動、再起動、シャットダウン、SD2、代表的なエミュレータとApps、音声、スリープ復帰を確認します。利用できる機種でWi-FiとUSB ADBを、画面サイズごとに表示とアスペクト比を確認します。更新パッケージを配布する場合は適用とロールバックも確認します。試験結果には、起動を確認した区間と、実際にプレイして確認した範囲を記録します。

配布物の一覧と、同梱部品の出所・ライセンス表記を残します。成果物に個人用のROM・BIOS、セーブ、実機試験用スクリプト、Wi-Fi設定、ホスト鍵、署名鍵が混入していないか調べます。ランタイム検証は起動経路と同梱ファイルを確認するためのもので、配布条件と完成イメージの実機動作も確認します。[イメージの検証手順](build.ja.md#検証と配布ファイル)
