# 共通SDイメージのビルド

[English](build.md) · [開発者ガイド](README.ja.md)

コマンドはリポジトリのルートから実行します。ホストにBash、Git、Python 3、`shasum`、`linux/arm64` コンテナを実行できるDockerと、ビルド領域・展開済みイメージ・圧縮イメージを保存する空き容量が必要です。イメージの生成と検証では、ループデバイスを使える特権コンテナへイメージファイルを渡します。

## 入力

| 変数 | 入力 |
| --- | --- |
| `BUBBLE_GIT` | plumOS Bubbleのコミット `ec81d42c0c2c39e7a32973bfe4df9b3027512a5d` を含むローカルGitリポジトリ |
| `V90S_GIT` | V90Sツールチェーンのコミット `bc49dafe782173f35ab557035fa96ba81564038d` を含むローカルGitリポジトリ |
| `JELOS_IMG` | 検証済みJELOS 20240206再ビルド版の展開済みイメージ。生成スクリプトはrawのSHA-256 `281bf1c1faf7f4c9d044f59677075fbb9af99d2a8d01f873c23c13587668c73f` を照合。 |
| `JELOS_SYSTEM` | 対応する入力から取り出したハードウェアサポート用SYSTEM。組み立て時にSHA-256 `b0028dc48926ad49ab2d0156fec2c64f16f406e2f463ded4cc84eb8dcaac4a83` を照合。 |
| `STATIC_ADBD` | 実行可能なARM64静的リンク版の `adbd` |
| `JELOS_UBOOT` | コミット `97c658238f7ccd436fbdede451bfd7488514a5c8` を含むローカルのJELOS U-Boot Gitリポジトリ |
| `BL31` | 対応するRockchip rkbinから取り出した `rk3568_bl31_v1.42.elf` |
| `BOOT_SPLASH_DIR` | `boot-splash.xrgb`、`provision-start.xrgb`、`provision-error.xrgb` を収めたディレクトリ。準備済み素材かmacOS ARM64用の生成スクリプトを使用。 |
| `RELEASE_VERSION` | リリース候補に付けるバージョン。 `PLUMOS_RUNTIME_VERSION` として渡します。 |

各入力は絶対パスで指定します。ソースの固定値と参照イメージの照合結果は別途記録しています。ロゴ生成スクリプトには、固定した素材を `refs/mini-PLUS` と `refs/Bubble` に、ホスト用Zigを `tools/` に置いた作業ディレクトリを渡します。出力は `compiled/boot-splash/` に生成されます。[JELOSの由来](../jelos-20240206-source.md) · [ADBの入力情報](../../prototype/README.md#ビルド入力) · [ロゴ生成スクリプト](../../prototype/build-boot-splash.sh)

## ビルド

上記の入力変数を設定し、新しい作業ディレクトリを使います。リリース候補では `PLUMOS_BUBBLE_CATALOG_FILTER` を設定せず、全カタログをビルドします。

```sh
set -eu
work="$PWD/output/release-work"
mkdir -p "$work"

./prototype/build-emulators.sh "$BUBBLE_GIT" "$V90S_GIT" \
  "$JELOS_SYSTEM" "$work/emulators"

PLUMOS_RUNTIME_VERSION="$RELEASE_VERSION" \
  ./prototype/build-bubble-system.sh "$JELOS_SYSTEM" "$BUBBLE_GIT" \
  "$STATIC_ADBD" "$work/system" "$work/emulators/runtime"

./prototype/build-rk3566-uboot.sh "$JELOS_UBOOT" "$BL31" "$work/u-boot.itb"

./prototype/build-bubble-sd.sh "$JELOS_IMG" "$work/system/SYSTEM" \
  "$BOOT_SPLASH_DIR" "$work/plumOS-RK3566.img" "$work/u-boot.itb"
```

SYSTEMの生成では `SYSTEM`、`bubble-userland.squashfs`、`SHA256SUMS`、`build-runtime-update.py` が出力されます。機種を自動判定する共通イメージには、生成したU-Boot FITを第5引数で渡します。イメージ生成の出力はrawの `.img`、`.img.gz`、`.img.sha256` です。

## 検証と配布ファイル

```sh
./prototype/verify-bubble-sd.sh "$work/plumOS-RK3566.img"
(cd "$work/system" && shasum -a 256 -c SHA256SUMS)
(cd "$work" && shasum -a 256 -c plumOS-RK3566.img.sha256)
```

SYSTEM生成時はフロントエンドのカタログ、各ランチャー、Appsの依存ファイル、コンポーネントのチェックサムを照合します。rawイメージの検証では、パーティション構成、初回セットアップ、既存ユーザーデータの保持と試験SYSTEMからの復旧をコンテナで確認します。実機試験の記録には使ったイメージのハッシュを残します。[リリース時の確認](release.ja.md)

rawイメージとして配布するときは、検証済みの `.img.gz` と対応するチェックサムを用意します。調査用にソースのコミット、ツールと入力のバージョン、圧縮前後のハッシュを保存します。

## ランタイム更新パッケージ

新規ビルドには `prototype/update/rk3566-update-public.pem` を収録します。配布用パッケージはこの公開鍵に対応するRK3566の秘密鍵を使い、署名前に秘密鍵から取り出した公開鍵が収録済みの公開鍵と一致することを確認します。秘密鍵はビルド成果物やGitに含めず、保護された場所に保管します。既存v0.1.1の移行は[ユーザー向け更新手順](../user/updates.ja.md)を参照してください。

生成された `build-runtime-update.py` は、展開したフロントエンドランタイムをパッケージ化します。特定の版を起点にする差分では `--base-dir` と `--base-version`、署名にはインストール済みランタイムの公開鍵に対応する `--signing-key` を指定します。共通ビルド間の互換性のため、パッケージの機種IDは `rg353m`、ベンダーランタイムIDは `rk3566-plumos-r1` です。引数の詳細は `build-runtime-update.py --help` で確認できます。配布前に予備カードで、署名とバージョンの照合、適用、ロールバックを試験します。ランタイムパッケージが更新するのはフロントエンド側のファイルです。ブートファイルやOS本体の変更には、必要に応じてイメージまたはSYSTEMを使用します。[ランタイム更新の仕組み](../rk3566-runtime.md)
