# RGB30 r1・r2と既存機種を収録した共通SDイメージ

JELOS 20240206は `resource` パーティションのADC情報で機種を判定し、extlinuxの `FDTDIR /` で、その機種のカーネル用DTBをFATから読みます。RGB30のr1とr2は同じ機種名を使うので、RGB30の場合だけ、既存のresource DTBで利用できるI²Cバス `i2c@fdd40000` を追加で調べます。ROCKNIXのr2向けDTBと、U-Boot上流のPowkiddy用レギュレーター判定を参照しました。[ROCKNIXのr2向けDTB](https://raw.githubusercontent.com/ROCKNIX/distribution/20240411/projects/Rockchip/patches/linux/RK3566/030-rgb30r2.patch) · [U-Boot上流の判定](https://github.com/u-boot/u-boot/blob/v2025.01/board/anbernic/rgxx3_rk3566/rgxx3-rk3566.c#L373-L407)

| 判定 | Linuxに渡すDTB |
| --- | --- |
| `0x1c` のIDレジスターを読み込み可能 | 既存の `rk3566-rgb30-linux.dtb` |
| `0x1c` が応答せず、`0x40` のID1が `0x88` | `rk3566-rgb30r2-linux.dtb` |
| RGB30で識別できない | 既存のRGB30 DTB |
| RGB30以外 | JELOSが選んだ機種別DTB |

I²Cの追加処理はレジスターの読み取りだけを行います。r2用DTBは、既存のRGB30r2で実機確認したFAN53555設定を生成します。U-BootのFITはJELOSのソースとBL31 v1.42からDockerで作り、SDのp1に格納します。JELOSのIDB、`resource`、カーネル、既存7件のLinux DTB、extlinux、出荷時のGPTを維持します。[Dockerでの生成手順](../../prototype/README.md#複数機種向けのsdイメージ)

## 検証結果

- U-BootのFITを2回生成し、バイト単位で一致した。格納ペイロードのSHA-256を検査し、元のFITとBL31の6セグメント、U-Boot自身が使用する制御用DTBが一致した。
- 実際の選択関数をI²Cのモックで実行し、TCS452x、FAN53555、ID不一致、バスやチップの応答なし、RGB30以外の6機種のファイル名を検証した。
- 出荷時イメージのp1前後と副GPTを元のJELOS再ビルド版と照合した。FATとext4の検査、GPTの検査に合格した。FATから読み出したr2用DTBのSHA-256は実機で使用中のr2用DTBと一致した。
- SDの複製を使い、初回セットアップでのp5作成と再起動後の継続、既存データの維持、SYSTEMの試行と組み込みSYSTEMへの復旧を確認した。
- 既存SDで稼働しているRGB30r2では、実際にFAN53555を `0-0040` で認識し、CPU 4コアと `cpufreq-dt` が稼働している。統合IMGを使ったr1・r2の実機検証はこれから行う。

同梱SYSTEMのSHA-256は `6f4fcb9c34fc4477fbeb74a18e93cb2a202c06c679b05de8790ef411c6cf8d05`。出力は `output/rgb30-validation/unified/plumOS-RK3566.img.gz` で、圧縮ファイルのSHA-256は `8a1bf8bad82d4d9f4db0d17cfb98d8f6ed1023ddce11f2f27994abb9921c236e`。
