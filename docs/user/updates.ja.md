# 更新

[English](updates.md) · [ガイドの目次](README.ja.md)

## v0.1.1からの初回移行

出荷版v0.1.1では、署名付き更新を使う前に、最新版の移行ZIPでRK3566用の公開鍵と `plumos-rk3566-runtime` ファイル名への対応を導入します。以前のZIPで公開鍵を導入済みの場合も、最新版のZIPで手順を一度実行してください。

1. [v0.1.2リリース](https://github.com/game-de-it/plumOS-RK3566/releases/tag/v0.1.2)から `plumOS-RK3566-update-key.zip` と対応する `.sha256` を取得し、ZIPのSHA-256を照合します。
2. 展開した `plumOS-RK3566-update-key` フォルダを、SD1の **PLUMOS** ボリュームのルートへコピーします。
3. v0.1.1で起動し、`START` → `Apps` → `File Manager` で `Install-Update-Key.sh` を選び、**Execute** を実行します。同じフォルダの `Update-Key.log` に `OK: System Update recognizes plumos-rk3566-runtime packages.` が出たら、下の手順でv0.1.2に更新できます。

v0.1.0を使用中の場合は、先に[v0.1.1リリース](https://github.com/game-de-it/plumOS-RK3566/releases/tag/v0.1.1)の手動更新ZIPでv0.1.1へ更新します。

## 署名付きランタイム更新

1. 利用中の版に対応するRK3566用更新パッケージを入手し、チェックサムを照合します。v0.1.1からv0.1.2への更新には `plumos-rk3566-runtime-0.1.2.tar.gz` を使います。
2. SD1の **PLUMOS** ボリュームにある `updates/` にパッケージを置きます。
3. `START` → `System Settings` → `System Update` から更新を選び、再起動まで案内に従います。

この更新は署名を確認し、ランタイムのファイルを更新します。

## フルSDイメージで提供される場合

セーブと設定をバックアップし、イメージの書き込み手順に従います。[バックアップ](storage.ja.md#セーブとバックアップ) · [インストール](install.ja.md)

共通SDイメージにはv0.1.2から正式な公開鍵が入っています。出荷版v0.1.2のイメージから新規インストールした場合は、次に `plumos-rk3566-runtime` 形式の更新を使う前に、最新版の移行ZIPを一度実行してファイル名への対応を導入します。
