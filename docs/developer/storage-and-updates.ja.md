# SYSTEMの試験起動と復旧

[English](storage-and-updates.md) · [ガイドの目次](README.ja.md)

## 転送と試験予約

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

## 起動確認と既定への反映

再起動後は、起動中のハッシュ、フロントエンドの準備完了、変更に関係する機能を確認します。確認後に `keep` で既定へ反映します。試験予約は次の1回で消費され、`keep` する前の次回起動では前の既定または出荷時のSYSTEMが選ばれます。

```sh
adb shell 'cat /dev/plumos-system-active /tmp/plumos-fe-ready'
adb shell 'grep -E " /storage/user | /run/media/sd2 " /proc/mounts'
adb shell "$boot_ctl status"
adb shell "$boot_ctl keep"
```

## 復旧

ADBで接続できる場合は `boot-system factory` で試験予約と既定を解除し、次回起動で `/flash/SYSTEM` に戻せます。復旧用に起動確認済みのカードかカードのバックアップを保管します。ユーザー向けの `System Update` は署名済みの適合パッケージを使う別経路です。[起動先の選択処理](../../prototype/boot-system/mount-storage.sh) · [ランタイム更新とロールバック](../rk3566-runtime.md)
