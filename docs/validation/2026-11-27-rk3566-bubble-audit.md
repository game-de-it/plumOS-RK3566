# plumOS-RK3566に残るBubble表記の調査

2026年11月27日（JST）。GitHubで配布中のv0.1.0、v0.1.1、v0.1.2と、ローカルのRGB10 Max 3内蔵Wi-Fi試験イメージを調べた。出荷版3つの `.img.gz` はGitHubのSHA-256と一致した。各IMGの先頭16 MiBとp3・p4を読み取り、p3に含まれる `SYSTEM` が手元の別ファイルと一致することを確認してから、SquashFSのパス、リンク先、テキスト、バイナリの平文を調べた。Gitの現行ソース、公開リリースノート、更新ZIP、署名済みランタイム更新も照合した。実機の書き込み済みカードやユーザー設定は今回の調査対象に含めていない。

## 設定画面・配布ファイル・診断メッセージ

- フロントエンドの表示用モデル名は `RK3566`。出荷版v0.1.2の既定設定に `"model": "RK3566"` があり、起動スクリプトも `PLUMOS_DEVICE_NAME=RK3566` を渡す。FE同梱の翻訳に `bubble` の一致はなかった。同じ設定には内部の `"device": "bubble"` が残る。これは別のフィールドである。[FEの名称変更](../../prototype/brand-rk3566-frontend.py) · [FEの起動スクリプト](../../prototype/system/usr/lib/plumos-353m/start-frontend)
- 公開中の3リリースの添付ファイル名と日英リリースノートに `bubble` の表記はない。v0.1.1への手動更新ZIP内の `Install-v0.1.1.sh` には `Wait for Bubble to finish starting.` と `Reboot from Bubble` が残る。v0.1.2のランタイム更新アーカイブ内でも公開鍵の格納パスに旧名が残る。[v0.1.1の更新スクリプト](../../prototype/boot-system/install-v0.1.1.sh) · [v0.1.2の配布物](https://github.com/game-de-it/plumOS-RK3566/releases/tag/v0.1.2)
- 同梱のMusic Player、NextCommander、PyxelのREADMEやコンポーネント名に `for Bubble` が残る。Pyxel、PortMaster、PPSSPP、DraSticの起動スクリプトや音量ヘルパーは、失敗時に `Bubble Mali hardware runtime is unavailable` などを出力する。RetroArchのALSA・DRM診断にも `Bubble` が残る。Music Playerバイナリ中の `GKD Bubble` は入力デバイス名の判定に使われる。[Music Playerの入力パッチ](https://github.com/game-de-it/plumOS-Bubble/blob/ec81d42c0c2c39e7a32973bfe4df9b3027512a5d/docker/bubble-tools/patches/music-player-bubble.patch)

## OS内で旧名に依存する箇所

次の10パスは、出荷版3つとRGB10 Max 3試験版の `SYSTEM` に共通して含まれる。パスはフロントエンドのルートからの相対表記。

| 用途 | パス |
| --- | --- |
| SD2のマウント、ストレージ診断 | `bin/plumos-bubble-mount-sd2`、`bin/plumos-storage-health-bubble` |
| Wi-Fiとネットワーク | `bin/plumos-network-control-bubble` |
| PythonとPyxelの起動 | `bin/plumos-python-bubble`、`bin/plumos-pyxel-bubble-launch` |
| RetroArchの設定と入力 | `factory-defaults/retroarch/retroarch-bubble.cfg`、`factory-defaults/retroarch/retroarch-bubble-pre-v90s.cfg`、`factory-defaults/retroarch/autoconfig/udev/gkd-bubble-retrogame-joypad.cfg` |
| 更新署名の検証 | `share/update/plumos-bubble-update-public.pem` |
| 上流・権利者の記録 | `licenses/bubble-vendor-runtime-NOTICE.txt` |

- 設定に残る `pyxel:bubble` は既定の起動プロファイルID。`device_specific: bubble` はSD2 RepairとGame GearのApp情報に入る。FEの既定設定、コンポーネントのマニフェスト、設定ファイル、ランチャーが参照する名前は、変更時にまとめて照合する。
- RetroArchの起動・メニュー起動・設定マージが共通の `retroarch-bubble.cfg` を参照する。保存済み設定を引き継ぐ場合は、出荷直後の既定設定と利用者が変更した設定の両方を検証する。NextCommanderにも保存用の `bubble.cfg` がある。[RetroArchの組み立て](../../prototype/emulators/assemble-runtime.sh)
- PortMasterのアダプターでは `DEVICE_NAME="GKD Bubble"` を互換プロファイルのキーとして使用し、HarbourMasterで `miyoo-flip` に対応付ける。更新通信のUser-Agentにも `plumOS-Bubble-PortMaster/1` が残る。機種名の変更時はカタログの絞り込みとゲーム起動を確認する。[PortMasterの互換プロファイル](https://github.com/game-de-it/plumOS-Bubble/blob/ec81d42c0c2c39e7a32973bfe4df9b3027512a5d/package/portmaster-bubble/plumos/apps/portmaster/adapter/plumos_portmaster_bootstrap.py)
- v0.1.2の出荷SYSTEMの更新処理は `plumos-bubble-*.tar.gz` を探す。最新版の移行ZIPを実行した環境と、現行ソースからビルドした環境は新旧両形式を受け付ける。現行ソースの生成側は `plumos-rk3566-runtime-*.tar.gz` を出力する。更新処理と署名済みアーカイブ内の公開鍵パスは旧名を使う。現行パッケージの互換IDは機種 `rg353m`、ベンダー `rk3566-plumos-r1`。[ファイル名移行](../../prototype/update/update-filename.sed) · [更新の検証記録](2026-11-27-v0.1.2-signed-update.md)

## ブート領域、ビルドと由来の表記

- 4つのIMGで、先頭16 MiBとp3のブート設定、DTB、スプラッシュ関連ファイルに `bubble` の文字列は検出されなかった。p3の `KERNEL` に見つかった平文はMaliの `Txx_TEX_BUBBLES` 8件。v0.1.2カーネルに含まれるgzipのinitramfsも展開し、パスと内容に一致がないことを確認した。p4では `provision/start-storage` の引き渡しコメントに旧称が1件あった。今回見つかった表記の整理に、ブート方式やパーティション構成の変更は必要ない。[p4の起動処理](../../prototype/seed/start-storage)
- `build-bubble-system.sh`、`build-bubble-sd.sh`、`bubble-userland.squashfs`、Dockerタグと `PLUMOS_BUBBLE_*` の一部は開発時の名前。上流の固定リビジョンを読み出すパスやパッチ名にも使われる。出荷ファイル名やRK3566側のビルド入口と、上流ソース参照の名前を区別する。[Dockerビルド](../developer/build.ja.md)
- 上流リポジトリ名 `plumOS-Bubble`、実機名 `GKD Bubble`、ライセンス・由来の記録、ゲーム名の `Bubble Bobble` などはそれぞれ固有名として保持する。`frontend-source` の固定コミットやライセンス通知も該当する。[第三者ライセンス](../../THIRD_PARTY_NOTICES.ja.md)

## v0.2.0のリリース前に確認する項目

1. 配布物名、Appsの同梱説明、利用者が読める診断メッセージを `plumOS-RK3566`、`RK3566`、または対象機能の名前に揃える。
2. RK3566側の更新ファイル名、公開鍵パス、生成側と実行側の参照を一緒に整理する。新規のSDイメージに正式公開鍵と新しいファイル名の検出処理を含め、追加入力なしで標準のSystem Updateが次版相当を署名検証・適用・正常確定できることを確認する。
3. 内部の設定名とヘルパー名を変更する場合は、SD2、Wi-Fi、RA、Pyxel、PortMasterの起動と、設定・セーブの引き継ぎを検証する。v0.1.xカードからの更新対応と、GitHub上の旧版の扱いは、v0.2.0の公開前に決める。
