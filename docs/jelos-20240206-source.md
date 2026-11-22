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

PortAudioの取得先も消失していました。Software HeritageのGitエクスポートからツリーと元のコミット `64d1bf913433d7a2835526b80a93487d5038cb8e` を復元しました。元のアーカイブと同じ接頭辞を指定して `git archive --format=tar` で展開用アーカイブを生成し、`gzip -n -6` で圧縮すると、JELOSのレシピに固定されたSHA-256 `c33e48217a844cca3b66ab88571b90beefb8fcb6967177951d4dc283587bf834` と一致しました。Yaba Sanshiroはフォークに残る同じコミットを取得し、レシピのブランチ名とサブモジュールのコミットを揃えました。[PortAudioの保存コミット](https://archive.softwareheritage.org/swh:1:rev:64d1bf913433d7a2835526b80a93487d5038cb8e/) · [Yaba Sanshiroの保存コミット](https://github.com/sydarn/yabasanshiro/commit/c7618d2ecbf77b1e8188fa8af4fa1cfb34833a72)

配布版 `KERNEL` のバージョン文字列はLinux 4.19.172、GCC 12.3.1（20240103）、GNU Binutils 2.41です。GCCのレシピが取得する12.3.0のアーカイブには、JELOS自身のパッチで12.3.1（20240103）の変更が適用されます。配布版から埋め込みカーネル設定も抽出し、比較項目に加えました。[GCCの公式レシピ](https://github.com/JustEnoughLinuxOS/distribution/blob/f8cac7b92040d734506e238f5a44560a4f0e81b0/packages/lang/gcc/package.mk) · [20240103版へのJELOSのパッチ](https://github.com/JustEnoughLinuxOS/distribution/blob/f8cac7b92040d734506e238f5a44560a4f0e81b0/packages/lang/gcc/patches/gcc-sync-to-12.3.1-01032024.patch)

### 32ビット互換ビルドでの先行照合

最初の実行は `fakeroot` の取得処理が既定ブランチの履歴から固定コミットを見つけられず停止しました。取得済みリポジトリにある `305c8a1b5396554a67794f3fe6e4990a24a810f9` を直接チェックアウトして再開し、`fakeroot:host` のビルドが完了しました。JELOSのソースとバージョン固定は維持しています。[fakerootの固定コミット](https://salsa.debian.org/clint/fakeroot/-/commit/305c8a1b5396554a67794f3fe6e4990a24a810f9)

互換ビルド中に生成したRG353M用DTBと同梱6機種用のDTBを元の配布イメージから読み出したものと照合し、全7件がバイト単位で一致しました。RG353M用DTBのSHA-256は `4e811ea7a0ff4e5d233c58d9da6f4793bac4ebd9dd1411f5c27a9b92645061c5` です。互換ビルドのinitramfs内の `/init` と `/functions` も配布版とバイト単位で一致しました。カーネル設定の差分は、コンパイラのターゲット名とinitramfsのビルド時パスの2行でした。これらは64ビット配布イメージの完成前に得た結果です。

互換ビルドで生成された `resource.img` を配布元の `p2` と比較すると、差分は8個のインデックスエントリのハッシュ欄にある未使用領域の計64バイトでした。各エントリの `hash_size` は20で、格納されたSHA-1と読み出した内容が双方で一致しました。比較時にハッシュ長より後ろをゼロ化すると、パーティション全体が一致しました。カーネルの生成ツールが32バイト欄の先頭20バイトだけを書き、U-Bootが `hash_size` の長さだけを読み込むことを確認しました。[resource.img生成ツール](https://github.com/JustEnoughLinuxOS/rk356x-kernel/blob/c741d56477939654bb4056be240f93d1ad1ae91e/scripts/resource_tool.c#L1470-L1497) · [U-Bootの読み込み処理](https://github.com/JustEnoughLinuxOS/rk356x-uboot/blob/97c658238f7ccd436fbdede451bfd7488514a5c8/arch/arm/mach-rockchip/resource_img.c#L152-L162)

### 64ビット版で生成したブート部品の照合

32ビット互換ビルドの全198工程が完了しました。64ビット版の工程で生成した部品を、配布イメージから読み出した同じ領域・ファイルと比較しました。

| 部品 | 比較結果 |
| --- | --- |
| LBA 64のIDBローダー | VendorStorage直前までの領域がバイト単位で一致 |
| `p1` のU-Boot FIT | BL31の6セグメントとU-Boot用DTBは一致。FITの日時とU-Boot本体は差分あり。両方で全ペイロードの格納SHA-256を検証 |
| `p2` の機種選択データ | 8エントリの内容とSHA-1が一致。ハッシュの未使用バイトを正規化すると領域全体が一致 |
| `p3` に収録するLinux | Linux 4.19.172、GCC 12.3.1（20240103）、GNU Binutils 2.41。埋め込みカーネル設定の差はinitramfsのビルド時絶対パスのみ。カーネルバイナリにはビルド日時・ホスト名などの差あり |
| 機種別DTBと初期化スクリプト | 全7件のDTBと、再ビルド版カーネルに埋め込まれた `/init`・`/functions` がバイト単位で一致 |

通常ビルドから分けた比較用コピーで、タグのソースおよび公式レシピが適用した状態を保ち、U-Bootに埋め込まれるユーザー名と日時だけを配布版と揃えました。生成した `u-boot-nodtb.bin` は配布イメージのFITに含まれるU-Boot本体とSHA-256 `af37d3549426270c2193ffc808b47d3167b4d6058b05ba539f6252be5739e562` が一致しました。通常ビルドにはこの比較用の環境変数を渡していません。[U-Bootのユーザー名を付加する処理](https://github.com/JustEnoughLinuxOS/rk356x-uboot/blob/97c658238f7ccd436fbdede451bfd7488514a5c8/scripts/setlocalversion) · [U-Bootのビルド日時設定](https://github.com/JustEnoughLinuxOS/rk356x-uboot/blob/97c658238f7ccd436fbdede451bfd7488514a5c8/Makefile#L1387-L1414)

64ビット版のBoost取得は、旧URLがアーカイブの代わりにHTMLを返したため停止しました。公式アーカイブから1.83.0を取得し、公開SHA-256 `6478edfe2f3305127cffe8caf73ea0176c53769f4bf1585be237eb30798c3b8e` と一致した入力で再開しました。SDイメージ全体の整合性と実機起動の検証は64ビット版のパッケージ生成後に行います。[Boostの公開チェックサム](https://archives.boost.io/release/1.83.0/source/boost_1_83_0.tar.bz2.json)

`rtmpdump` の旧URLもHTMLを返しました。フォークから指定Gitコミットを取得し、同じツリーのアーカイブを生成して `rtmpdump` の工程を通過しました。同じ配布元の `edid-decode` にも、指定コミットを保存しているミラーを使用しました。[rtmpdumpの固定コミット](https://github.com/mirror/rtmpdump/commit/c5f04a58fc2aeea6296ca7c44ee4734c18401aa3) · [edid-decodeの固定コミット](https://github.com/oe-mirrors/edid-decode/commit/5f723267e04deb3aa9610483514a02bcee10d9c2)

LLVMではDockerのメモリ不足でコンパイラが強制終了しました。JELOSのビルド並列数を `CONCURRENCY_MAKE_LEVEL=3` に抑え、LLVMが内部で起動するCMakeビルドにも `CMAKE_BUILD_PARALLEL_LEVEL=2` を設定して、保存済みの中間生成物から再開しました。

LLVMはホスト用の残りを1ジョブで、RG3566向けライブラリを2ジョブでビルドして完了しました。通常のイメージ生成を再開し、両方の完了済みビルドを利用しました。

PortMasterのレシピが直接取得する旧 `compat.zip` にもダウンロード失敗がありました。当時のフォークに残るアーカイブ（SHA-256 `e0c493f24ec1d94a79c3554811f5b9c9c863d6ab0988649bd64d7f6a4e44626f`）を取得し、収録される47件すべてが配布版の `/usr/lib/compat` とバイト単位で一致することを確認しました。Docker側で該当する1件の取得を検証済みのアーカイブに振り替え、レシピに変更を加えずPortMasterの組み込みが完了しました。[互換アーカイブの保存コミット](https://github.com/RetroGFX/UnofficialOSAddons/commit/351c27e6bb0b07a7f920cf303f72b8ba78fed17d)

`mame-lr` のビルド中にもメモリ不足による強制終了が発生しました。DockerのLinux VMに5 GiBの一時スワップを追加し、保存済みのオブジェクトを使って同じレシピを再開しました。

既にRG353Mで起動したJELOSのSDカードから採取した先頭16 MiBも、元の配布イメージと照合しました。IDB、U-Boot FIT、`resource.img` の領域はバイト単位で一致しました。差分があったのは、初回起動後のストレージ拡張を反映する保護MBRとGPT、およびVendorStorageの25バイトです。再ビルドの比較基準には配布イメージを使います。
