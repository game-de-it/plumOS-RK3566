# システム構成

[English](architecture.md) · [ガイドの目次](README.ja.md)

共通イメージはJELOS 20240206のRK3566用ブートチェーンを使います。パッチを適用したU-Boot FITは、CPUレギュレーターに応じてRGB30 r1/r2のデバイスツリーを選び、RG353VはUSB接続中の電源投入にも対応します。Linux 4.19.172とextlinux・initramfsの引き渡しを維持し、再構成したSYSTEMからplumOS init、フロントエンド、デバイスサービスを起動します。[ブート方式と機種対応](../boot-and-device-support.md) · [JELOSのソースリビジョン](../jelos-20240206-source.md)

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
