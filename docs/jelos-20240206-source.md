# JELOS 20240206のソース確認（RK3566）

手元の `JELOS-RK3566.aarch64-20240206.img.gz` の `SYSTEM` から `/etc/os-release` を読み出しました。`BUILD_ID` は `f8cac7b92040d734506e238f5a44560a4f0e81b0`、`HW_DEVICE` は `RK3566`、`HW_ARCH` は `aarch64` です。公式GitHubの `20240206` タグが同じコミットを指すことを `git ls-remote` とローカルのGitで確認しました。[公式リリースタグ](https://github.com/JustEnoughLinuxOS/distribution/releases/tag/20240206)

## 入手したビルド入力

| 対象 | 固定したバージョン | 参照元 |
| --- | --- | --- |
| ディストリビューションのビルド設定と初期化スクリプト | `f8cac7b92040d734506e238f5a44560a4f0e81b0` | [JELOS配布元](https://github.com/JustEnoughLinuxOS/distribution/tree/f8cac7b92040d734506e238f5a44560a4f0e81b0) |
| RK3566 BSPカーネル 4.19.172 | `c741d56477939654bb4056be240f93d1ad1ae91e` | [ビルドレシピ](https://github.com/JustEnoughLinuxOS/distribution/blob/f8cac7b92040d734506e238f5a44560a4f0e81b0/projects/Rockchip/packages/linux/package.mk#L24-L29) · [カーネル](https://github.com/JustEnoughLinuxOS/rk356x-kernel/commit/c741d56477939654bb4056be240f93d1ad1ae91e) |
| RK3566用U-Boot | `97c658238f7ccd436fbdede451bfd7488514a5c8` | [ビルドレシピ](https://github.com/JustEnoughLinuxOS/distribution/blob/f8cac7b92040d734506e238f5a44560a4f0e81b0/projects/Rockchip/packages/u-boot/package.mk#L20-L23) · [U-Boot](https://github.com/JustEnoughLinuxOS/rk356x-uboot/commit/97c658238f7ccd436fbdede451bfd7488514a5c8) |
| BusyBoxの上流ソース | `1.36.1` | [JELOSのパッケージ設定](https://github.com/JustEnoughLinuxOS/distribution/blob/f8cac7b92040d734506e238f5a44560a4f0e81b0/packages/sysutils/busybox/package.mk#L6-L13) · [BusyBox配布元](https://busybox.net/downloads/busybox-1.36.1.tar.bz2) |
| Rockchipの起動用バイナリ | `3aafb4dd13a750ab226604875d7938284d4ee9f1` | [rkbinのビルド指定](https://github.com/JustEnoughLinuxOS/distribution/blob/f8cac7b92040d734506e238f5a44560a4f0e81b0/packages/tools/rkbin/package.mk) · [RK3566のファイル指定](https://github.com/JustEnoughLinuxOS/distribution/blob/f8cac7b92040d734506e238f5a44560a4f0e81b0/projects/Rockchip/devices/RK3566/options#L27-L42) |

入手物は `output/jelos-20240206-sources/` に置きました。カーネルには大文字と小文字だけが異なるファイル名があり、Mac上の通常の作業ツリーでは一部のファイルが衝突しました。保存した `rk356x-kernel-c741d56477939654bb4056be240f93d1ad1ae91e.tar.gz` はGitオブジェクトから生成し、アーカイブ内のコミットIDと、大文字・小文字が異なる両方のファイルが含まれることを確認しました。展開・ビルドには大文字小文字を区別するファイルシステムを使います。

rkbinからは、RK3566用のDDR `rk3566_ddr_1056MHz_v1.16.bin`、SPL `rk356x_spl_v1.12.bin`、BL31 `rk3568_bl31_v1.42.elf` を取得しました。これらはJELOSのビルドが取り込む配布バイナリです。個別のバイナリを生成したソース及び配布イメージ全体の再ビルドは未確認です。[JELOSのブートローダー組み立て](https://github.com/JustEnoughLinuxOS/distribution/blob/f8cac7b92040d734506e238f5a44560a4f0e81b0/projects/Rockchip/bootloader/install)

## 実物のイメージとの照合

- `KERNEL` 内のinitramfsから取り出した `/init` は、公式の `packages/sysutils/busybox/scripts/init` に当時のレシピどおり `JELOS`、`RK3566`、`KERNEL` を代入したものとバイト単位で一致しました。`/functions` も対応するソースと一致しました。[initramfsのソース](https://github.com/JustEnoughLinuxOS/distribution/blob/f8cac7b92040d734506e238f5a44560a4f0e81b0/packages/sysutils/busybox/scripts/init) · [ビルド時の置換](https://github.com/JustEnoughLinuxOS/distribution/blob/f8cac7b92040d734506e238f5a44560a4f0e81b0/packages/sysutils/busybox/package.mk#L228-L241)
- RG353MのSD初期化を調べる対象は、固定したカーネルの `rk3566-rg353m-linux.dts` およびDesignWare MMCドライバーです。[RG353MのDTS](https://github.com/JustEnoughLinuxOS/rk356x-kernel/blob/c741d56477939654bb4056be240f93d1ad1ae91e/arch/arm64/boot/dts/rockchip/rk3566-rg353m-linux.dts) · [MMCドライバー](https://github.com/JustEnoughLinuxOS/rk356x-kernel/blob/c741d56477939654bb4056be240f93d1ad1ae91e/drivers/mmc/host/dw_mmc.c)
- Internet Archiveには同じファイル名のミラーが複数あり、`_202403` のメタデータにある圧縮ファイルのSHA-1 `ad3576f4f66dec744a27db0c240b2a957ee21e6d` が手元のファイルと一致しました。別アイテムのSHA-1は異なります。圧縮前の中身の比較は行っていません。ソースの特定には公式Gitタグとイメージ内の `BUILD_ID` を使いました。[一致したミラーのメタデータ](https://archive.org/metadata/jelos-rk-3566.aarch-64-20240206.img_202403) · [別のミラーのメタデータ](https://archive.org/metadata/jelos-rk-3566.aarch-64-20240206.img)

## Dockerでの未改変ビルド

2026年11月22日（JST）に、固定コミットの `Dockerfile` から Ubuntu 22.04 の ARM64 ビルド環境を作成しました。Dockerの環境にホスト用の `g++` を追加しました。ソースはDockerのLinuxボリュームに置き、追跡対象ファイルに変更がないことを確認してから、`CUSTOM_VERSION=20240206 THREADCOUNT=2 make RK3566` を開始しました。このターゲットは `ARCH=arm` の互換ビルドに続いて `ARCH=aarch64` の配布イメージを生成します。DockerのUbuntuパッケージは環境作成時の版です。[公式Dockerfile](https://github.com/JustEnoughLinuxOS/distribution/blob/f8cac7b92040d734506e238f5a44560a4f0e81b0/Dockerfile) · [RK3566のビルドターゲット](https://github.com/JustEnoughLinuxOS/distribution/blob/f8cac7b92040d734506e238f5a44560a4f0e81b0/Makefile#L52-L54)

ダウンロード元が利用できない入力は、同じバージョンまたはGitコミットをDockerのソースキャッシュに置きました。GNU configのアーカイブはLibreELECが公開しているハッシュに一致しました。Debianの `bdf2psf` はSnapshotから1.223を取得しました。DraSticは当時のフォークに保存されたアーカイブを使用し、同梱ファイルとストリップ後の実行ファイルが元のJELOSの `SYSTEM` 内にあるファイルにバイト単位で一致することを確認しました。代替取得先とハッシュはローカルの `output/jelos-20240206-rebuild/alternate-sources.tsv` およびDockerの `/work/sources` に記録しています。[GNU configのハッシュ](https://github.com/LibreELEC/LibreELEC.tv/blob/master/packages/devel/configtools/package.mk) · [Debian Snapshotの1.223](https://snapshot.debian.org/package/console-setup/1.223/) · [DraSticアーカイブのコミット](https://github.com/RetroGFX/UnofficialOSAddons/commit/0f91d91aec9893efe53a9c284d681ea6692f20ac)

比較処理は配布イメージで事前に確認しました。主・副GPTのCRC、パーティションの位置と型、IDB領域、U-Boot FIT、機種識別用 `resource.img`、ブートパーティション上の `KERNEL`・`SYSTEM`・各DTBを照合します。`extlinux.conf` はp3・p4の実UUIDとの一致を検査し、イメージ生成時のUUIDを正規化した内容も比較します。再ビルド品と実機の検証結果は完成後に追記します。
