# RG353Mの低負荷エミュレータ音声とディスク整理

**追記:** この文書の `schedutil` 標準化とmGBA標準化は、[gpSPの描画・音声ペーシング修正](2026-11-23-rg353m-gpsp-audio-pacing.md)で取り消した。この文書は診断の経緯として残す。

2026年11月23日（JST）。内蔵スピーカーの音飛びについて、既存の試作SDをUSB ADBで更新して調べた。ユーザーは前回のSYSTEMで音量ボタンによる音量変化を実聴した。USB DACはユーザーが取り外しており、今回の測定区間は内蔵スピーカー、音量20％である。

## 原因の切り分け

BubbleのFEから起動するRetroArchのPCM状態、ALSAの `trigger_time`、DRM画面更新、CPUクロックを追跡した。`trigger_time` が1回なら起動時だけ、2回以上なら測定区間中にPCMが再始動したことを表す。これは音飛びの客観的な兆候だが、音を実際に聞く検査の代用にはならない。

| ROM / コア | 設定 | 長さ | fps | PCM開始回数 |
| --- | --- | ---: | ---: | ---: |
| Binary Land / QuickNES | ondemand | 60秒 | 58.72 | 29 |
| Binary Land / QuickNES | schedutil | 90秒 | 59.93 | 1 |
| Dr. Mario / Gambatte | ondemand | 60秒 | 56.43 | 92 |
| Dr. Mario / Gambatte | schedutil | 90秒 | 59.92 | 1 |
| Horde DX / Gambatte | schedutil | 60秒 | 59.90 | 1 |
| Densetsu no Stafy / gpSP | ondemand | 60秒 | 58.63 | 28 |
| Densetsu no Stafy / gpSP | schedutil | 90秒 | 59.72 | 4 |
| Densetsu no Stafy / gpSP | schedutil、音声バッファ256ms | 90秒 | 59.72 | 2 |
| Densetsu no Stafy / gpSP | schedutil、最低1104MHz | 90秒 | 59.72 | 6 |
| Densetsu no Stafy / mGBA | schedutil | 60秒 | 59.92 | 1 |

NESの最初の試験用スクリプトには、指定値を無視して `performance` を強制する記述があった。これを削除し、上表のNES結果は指定したガバナーで取り直した。計測した `schedutil` のクロックはNES/GB/GBCで816〜1992MHz、mGBAで1104〜1992MHzと変動しており、最大クロック固定ではない。gpSPは設定を変えてもPCM再始動が残るため、GBAの標準コアをmGBAに変更した。gpSPの選択肢は残した。

## Docker生成SYSTEMと実機

`prototype/build-bubble-system.sh` の出荷カタログでNES、GB、GBC、GBAの標準CPUポリシーを `schedutil` にした。GBAの標準プロファイルを `retroarch:mgba` にした。ビルド時にPyxelランチャーのALSAパスをRG353M用に変更するので、コンポーネントのチェックサムを変更後のファイルで更新するよう修正した。Docker検証は196のFEプロファイル、可視Apps、9コンポーネントを通過した。

- SYSTEM: `127de01f41d76542f319e1ba7235523b0145c442312d2fb298a53d72a8998ca2`
- bubble-userland.squashfs: `3b56cc88a00830f0be597889a0c3af8a15d954b7da6069bf10b21c7c540ef24f`

SYSTEMをUSB ADBで転送し、`boot-system publish` のハッシュ照合後に `trial` で起動した。`boot-system status` は `active` と `healthy` が上記SYSTEMのSHA-256を示した。ADB、Bubbleの起動判定、実機上の出荷カタログを確認した。FE経由の試験後に `boot-system keep` を実行し、`default` も同じハッシュになった。SDの再書き込み、カーネル、DTB、ブート領域、パーティションの変更は行っていない。旧 `/flash/SYSTEM` は復旧先として残した。

出荷SYSTEMでFEの `plumos-text-ui launch --execute` を使い、各ROMを45秒測定した。これらの試験はFEにプロファイルを明示して実行した。出荷カタログの標準値は別途読み出して照合した。

| FE経路 | fps | PCM開始回数 | 観測クロック |
| --- | ---: | ---: | ---: |
| NES / QuickNES | 59.89 | 1 | 816〜1992MHz |
| GB / Gambatte | 59.85 | 1 | 816〜1992MHz |
| GBC / Gambatte | 59.90 | 1 | 816〜1992MHz |
| GBA / mGBA | 59.92 | 1 | 1104〜1992MHz |

旧SYSTEMの全プロファイル短時間試験では173経路を予定し、162経路で画面更新を観測した。52経路でPCM開始2回以上、11経路でXRUNを観測した。この3秒計測は音飛びの最終判定には短いため、上表の低負荷タイトルを長時間測った。重いコア、ROM互換性、実聴、USB DACの物理切替は別途確認が必要である。

## Macの作業領域

ビルド途中でMacの空き容量が約240MiBになり、DockerのSYSTEM作成が容量不足で失敗した。未完成のビルドディレクトリ、古い試作IMGの実体4つ、圧縮版が残る古いIMGの展開済みコピー3つ、不要なDockerイメージ4つを削除した。Docker Desktopを再起動し、最終ビルド後に中間ビルドディレクトリも削除した。作業時の空き容量は約15GiB。実機で起動中の旧SYSTEMと、今回生成したSYSTEMは保持した。

参照した過去の音声検証: [plumOS-A30のシステムノート](https://github.com/game-de-it/plumOS-A30/blob/main/docs/a30-system-notes.md)、[plumOS-GKD](https://github.com/game-de-it/plumOS-GKD)。A30の結果をRG353Mに直接流用せず、RG353Mで動的ポリシーとPCMの挙動を測定した。
