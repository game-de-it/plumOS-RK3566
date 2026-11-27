# 更新

[English](updates.md) · [ガイドの目次](README.ja.md)

## v0.1.xからv0.2.0へ移行する

セーブや設定をバックアップし、v0.2.0の共通SDイメージをTF1用カードに書き込んでください。[v0.2.0リリース](https://github.com/game-de-it/plumOS-RK3566/releases/tag/v0.2.0) · [データの保存先](storage.ja.md) · [インストール](install.ja.md)

## 署名付きランタイム更新

v0.2.0の共通SDイメージには正式公開鍵とRK3566用の更新処理が入っています。対応する更新パッケージが公開されたら、標準のSystem Updateで適用できます。公開鍵の手動導入は不要です。

1. 利用中の版に対応する `plumos-rk3566-runtime-<version>.tar.gz` を入手し、添付のSHA-256と照合します。
2. アーカイブをTF1の **PLUMOS** ボリュームの `updates/` に置きます。
3. `START` → `System Settings` → `System Update` を開き、自動再起動後に `Information` でランタイムのバージョンを確認します。
