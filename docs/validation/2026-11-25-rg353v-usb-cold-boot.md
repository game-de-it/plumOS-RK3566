# RG353VのUSB接続中の電源投入

SD2修正の試行起動時、利用者はUSBを接続したままだと電源が入らなかったと報告した。起動後はMacのUSB ADBと接続でき、UDCは `configured`、カーネルは接続先を `USB_CDP_CHARGER` と判定していた。

RG353VのRK817で保存値 `0x99=0x7f`、`0xa4=0x00` を確認した。JELOSのDTBは `not-save-power-en = 1` を指定している。JELOSのU-Bootはこの指定があると保存値を更新しないが、BSPカーネルはシャットダウンや再起動時、保存値が非ゼロなら電源レール設定に読み戻す。RGB30で検証済みの処理を、同じDT条件を実機で確認したRG353Vにも適用した。[RGB30の再起動対策](../boot-and-device-support.md#rgb30の再起動とusb-adb)

USBを接続したまま、保存値を消去して修正版SYSTEMに再起動した。Macから再接続でき、異なるboot ID、UDCの `configured`、保存値 `0x00/0x00`、FEとSD2を確認した。修正版SYSTEM `bb41fc6bcc9c8b8869ce8848e156ac07202d53a765fadd8cd4053b488b817da0` を既定に設定した。

JELOSのRG353V用DTBは `rockchip,uboot-charge-on = 1` も指定している。JELOSのU-Bootは給電中に充電画面を開始でき、電源キーの長押しを受けてLinuxへ進む。ROCKNIXのRK3566 Genericは上流U-Bootを使用し、PMICの電源投入理由から、USBが挿されたことと電源ボタンが押されたことを区別する。[ROCKNIXのビルド定義](https://raw.githubusercontent.com/ROCKNIX/distribution/e5fe9c2054a4906891b79a75f3903bf6730633a5/projects/ROCKNIX/devices/RK3566/packages/u-boot-Generic/package.mk) · [上流U-BootのRGxx3設定](https://github.com/u-boot/u-boot/blob/v2026.01/configs/anbernic-rgxx3-rk3566_defconfig) · [RK817の電源投入理由](https://github.com/u-boot/u-boot/blob/v2026.01/include/power/rk8xx_pmic.h#L224-L231)

従来のU-Bootを維持したまま修正版SYSTEMからシャットダウンし、USB接続を維持して利用者が通常の電源操作を行った。画面は暗いままで、MacにADBは現れなかった。約3秒の長押しではLEDが一瞬点灯したあと消えた。Linuxより前のどの段階で停止したかは、この試行からは特定できていない。

試験用のU-Bootは、RG353Vで通常の電源投入時にRK817が電源ボタンを示したとき、給電中でも充電画面の待機へ入らずLinuxに進む。給電だけの起動、明示的な充電モード、低電圧時の充電処理は既存の経路を使う。FITを検査し、変更はU-Boot本体に収まり、BL31の6セグメントと制御用DTBは一致した。試験IMGのDocker検証で、FAT、ext4、GPT、p5の作成と更新・復旧を確認した。

試験IMGは `output/rg353v-validation/usb-cold-boot/plumOS-RK3566.img.gz`。圧縮ファイルのSHA-256は `f49823028cda68d73a94308397b20a6c9878cec2990cc0b5427a00a5b2cf9c3a`。

## 修正版IMGの実機確認

利用者が試験IMGを別のSDに書き込み、RG353VでUSBを挿したまま再起動と、シャットダウン後の電源投入に成功した。直後のUSB ADBで、起動中のSDのp1および `/flash/SYSTEM` のSHA-256が試験IMGと一致することを確認した。SYSTEMはIMG同梱版が実行され、カーネル、RG353V用DTB、extlinux設定は修正前と一致した。RK817の電源投入理由は電源ボタンを示す `0x80`、電源レール保存領域は `0x00/0x00` だった。

UDCは `configured` で、plumOS init、FE、CPU 4コア、640×480の内蔵画面を確認した。p5とSD2は読み書き可能で、SD2のROM・BIOSはFEが参照する利用者ディレクトリに公開されていた。この採取は稼働中の状態を読み取った。
