# RK3566のシステムと更新

RG353Mでは実機確認済みのJELOS 20240206のU-Boot、extlinux、カーネル、DTB、initramfsを使う。initramfsの `switch_root` が要求する `/usr/lib/systemd/systemd` は、plumOS initへのシンボリックリンクとして収録する。出荷用 `SYSTEM` はBubbleのアプリレイヤーとARM64 Docker環境のユーザーランドから新規に生成する。JELOSのルートファイルシステム、systemd本体、EmulationStation、スワップ設定は組み込まない。

Linux 4.19.172とRG353Mに対応するRealtek 8821CSのカーネルモジュールとファームウェア、Maliのベンダーライブラリは、同じピン留め済みの入力から個別に取り出す。対応ファイルの抽出範囲は [SYSTEM組み立てスクリプト](../prototype/build-runtime-system.sh) にある。

## 通常の更新

設定・ログ・セーブ・インデックスは従来のディレクトリに保存する。そこへ出荷時のBubbleのファイルを読み取り専用の下層としてマウントする。最初の起動では旧ランチャーが作ったアセットへのシンボリックリンクを外す。利用者用のp5とTF2のマウント先は共通で、ライブラリの再走査とUUID別キャッシュには元のBubbleのヘルパーを使う。

通常のランタイム更新はBubbleと同じ署名検証とファイル単位のジャーナルで処理する。パッケージ対象は `rg353m`、ランタイム識別子は `rk3566-plumos-r1`。更新ファイルをp5の `updates` に入れ、FEのシステム更新から選択できる。次回の起動で交換を行い、FE描画とADBの準備を確認して確定する。確定前に再起動すると変更ファイルを戻す。

Dockerビルドで生成する `build-runtime-update.py` はRK3566向けの更新パッケージを作る。差分の生成には `--base-dir` で前版のアプリレイヤーを指定し、対応する署名鍵を `--signing-key` で渡す。ビルドには公開鍵を収録する。ランタイムパッケージはブート領域やカーネルを変更しない。

## 開発用のADB復旧

`/flash/SYSTEM` は出荷時のplumOSで、通常の起動と復旧の両方に使う。開発中だけ、USB ADBで `SYSTEM.partial` を転送し、`boot-system publish SHA256` と `boot-system trial SHA256` で次の1回を予約できる。起動が完了しなければ次回は `/flash/SYSTEM` が選ばれる。 `boot-system factory` で試験予約と既定の候補を解除できる。出荷イメージに旧版のルートファイルは置かない。

## 2026年11月23日の確認

- RG353Mの既存SDへ、USB ADBの試験起動で新しい `SYSTEM` を導入した。試験起動でFE、USB ADB、保存済みWi-Fiへの自動接続、p5とSD2の読み書きマウントを確認してから、起動パーティションの `SYSTEM` を更新した。
- 更新後は `/flash/SYSTEM` からplumOS initで起動した。最初の起動ではカーネル起動から6.98秒でFEとADBの準備が完了した。SD2のUUIDで一覧を保存し、同梱タイトルを含む843件を登録した。
- 旧版の整理後も通常再起動でき、7.16秒でFEとADBが準備完了した。DraSticの『Newスーパーマリオブラザーズ』で57.24 fps、PyxelのPFSで59.58 fpsのDRM画面提示を計測し、どちらもPCMポインターの進行を確認した。
- 起動確認後にp4の旧 `SYSTEM` と旧サービス定義を整理し、`/storage` の空きは3.5 GiBになった。移行前の起動用 `SYSTEM` と以前の旧ビルドはMac上でハッシュを照合した。ログの保存・削除方針は従来どおり。
- 署名付き更新はDocker内のext4で受理、適用、未確定状態からのロールバック、動作確認後の確定を検証した。配布用SDイメージは先頭16 MiB、GPT、カーネル、DTB、extlinux設定を元イメージと照合した。8 GiBに拡張した複製でp5の初回作成、継続起動、既存データ保持、試験用 `SYSTEM` から出荷時のplumOSへの復帰を確認した。

`SYSTEM` のSHA-256は `96b0c529a9012ff61be20f8a4771e9b502578027385147e884555d0a77dd0eb0`。圧縮SDイメージは `e351ea3935e9e097daf542d95c7dd0eff8d7d628ce97f64c88c26a3003a3ed38`。
