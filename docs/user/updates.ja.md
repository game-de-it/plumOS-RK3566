# 更新

[English](updates.md) · [ガイドの目次](README.ja.md)

## v0.1.xからv0.2.1へ移行する

セーブや設定をバックアップし、v0.2.1の共通SDイメージをTF1用カードに書き込んでください。[v0.2.1リリース](https://github.com/game-de-it/plumOS-RK3566/releases/tag/v0.2.1) · [データの保存先](storage.ja.md) · [インストール](install.ja.md)

## 署名付きランタイム更新

v0.2.0の共通SDイメージには正式公開鍵とRK3566用の更新処理が入っています。現在のランタイムが `0.2.0` の場合、同梱の公開鍵を使って標準のSystem Updateからv0.2.1へ更新できます。[v0.2.1リリース](https://github.com/game-de-it/plumOS-RK3566/releases/tag/v0.2.1)

1. `plumos-rk3566-runtime-0.2.1.tar.gz` を入手し、添付のSHA-256と照合します。
2. アーカイブをTF1の **PLUMOS** ボリュームの `updates/` に置きます。
3. `START` → `System Settings` → `System Update` を開き、自動再起動後に `Information` でランタイムのバージョンを確認します。
