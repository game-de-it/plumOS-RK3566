# RG353MのSYSTEM起動と復旧

2026年11月22日（JST）。起動確認済みのJELOS 20240206を入れたSDを使用します。`p3` の空き容量は778 MiBなので、1.22 GiBの試作 `SYSTEM` は既存の `p4` 上の `/storage/plumos-rk3566/system` に置きます。JELOSのinitramfsが呼び出す `/flash/mount-storage.sh` を追加し、標準のストレージマウントを行った後にルートとして使うSquashFSを選びます。元の `/flash/SYSTEM` もカード上に残ります。

候補はSHA-256で識別します。`boot-system publish SHA256` は受信した `SYSTEM.partial` の内容を照合してから公開し、`boot-system trial SHA256` が一度だけの起動を予約します。次回のカーネル起動時に予約を消してから候補をマウントするので、試験起動中に停止しても、リセットによる次回起動でJELOSへ戻れます。公開と起動予約は別操作です。

候補から起動すると、フロントエンドが候補のルートから実行され、描画完了とUSB ADBのサービス起動を確認した時点で起動を成功として記録します。`boot-system keep` で、この実機で確認済みの候補を既定にできます。既定の候補では、起動結果が成功に更新されない場合、次の電源投入でJELOSが起動します。`boot-system stock` で既定と試験予約を解除できます。復旧時のJELOSでは、既存の `/storage` 側のADBサービスとEmulationStationを起動します。

`boot-system` は実機の `/storage/plumos-rk3566/system/boot-system` にあります。新しいビルドは `/storage/plumos-rk3566/system/SYSTEM.partial` に転送し、`publish`、`trial`、再起動の順で試せます。今回の大きいファイルの転送には `rsync --partial --inplace` とSSHを使いました。

ADBから元のJELOSに戻す操作は次のとおりです。

```sh
adb shell /storage/plumos-rk3566/system/boot-system stock
adb shell systemctl --no-block reboot
```

ADBもSSHも使えない場合は、本体の電源を切り、MacでSDの `JELOS` ボリュームにある `mount-storage.sh` を `mount-storage.sh.disabled` に改名します。このファイルが呼ばれなくなり、既存の `/flash/SYSTEM` が選ばれます。設定を戻す場合は改名を戻す前に `boot-system stock` で起動予約と既定を解除できます。

初回の候補起動で、ルートが候補に切り替わりADBが立ち上がりました。Bubbleのサービスは `jelos.target` から起動するリンクが必要でした。実機の永続サービス設定とインストーラーにリンクを追加し、状態監視サービスを起動順序に依存しない構成に変更しました。最初の候補起動中にBubbleの描画とADBで35バイトの往復転送を確認しました。

続けて起動予約を作らずに再起動し、元の `/flash/SYSTEM` が `/` になり、復旧用ADBと元のEmulationStationが起動することを確認しました。Mac側のADBサーバーはUSB再列挙後に一覧が空の場合 `ADB_LIBUSB=1` で再起動しました。

ADBから再度試験起動を予約しました。2回目は手動でのサービス起動を挟まず、Bubbleの描画、ネイティブのUSB ADB、および起動成功の記録を確認しました。`keep` 後の再起動でも、SHA-256 `7f8197ee6a5f68b42c6270cf4c3d778b88546435ad60fb2e99c3d877dacd7f28` のSquashFSがルートとして選ばれ、BubbleとADBが自動起動しました。

前後のSD先頭16 MiBのハッシュ、GPTの4パーティションの開始位置とサイズ、`KERNEL`・全7件のDTB・`extlinux.conf`・元の `SYSTEM` とMD5ファイルが一致しました。`/flash` は読み取り専用に戻っています。
