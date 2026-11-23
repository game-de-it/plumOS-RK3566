# RG353Mの映像スレッド修正後の抽出音声試験

2026年11月23日（JST）。[gpSP音声修正](2026-11-23-rg353m-gpsp-audio-pacing.md)を含むSYSTEM `f4aca77c10734c899b540a5f5bf4332fdce812f40442dd52c4736c1b973c7818` で、ほかのRetroArchコアにも音声再始動の改善があるか調べた。

以前の全プロファイル試験で、画面が出てPCM開始が複数回あり、画面更新が50fps以上だったRetroArch経路を候補とした。システムIDを整列し、乱数シード `35323` で8システムを抽出した。各システムの候補プロファイルも同じ乱数列で1つ選んだ。ROMパスと個別の計測値は [結果TSV](rg353m-random-audio-2026-11-23.tsv) に記録した。試験計画とJSON原本は `output/rg353m-random-audio-plan.json` と `output/rg353m-random-audio-results.json` に保存した。

すべてUSB ADBで実機のFEを一時停止し、ROM・設定・セーブを試験領域に分離して、通常のランチャーから起動した。内蔵スピーカーの音量は20％、CPUガバナーは各試験とも **ondemand** とした。ALSA PCM状態・ハードウェアポインタ・開始時刻とDRM画面更新を45秒間採取した。計測中にCPUクロックは全経路で408〜1992MHzの間を変動した。

| システム / コア | 旧SYSTEMのPCM開始¹ | 新SYSTEMのPCM開始² | 新SYSTEMの画面更新 |
| --- | ---: | ---: | ---: |
| Neo Geo / FBA 2012 Neo Geo | 2 | 1 | 58.81fps |
| PICO-8 / Fake-08 | 11 | 1 | 57.44fps |
| NGPC / Mednafen NGP | 2 | 1 | 58.26fps |
| GBC / TGB Dual | 8 | 1 | 59.15fps |
| ColecoVision / blueMSX | 4 | 1 | 57.10fps |
| PC Engine / Mednafen PCE Fast | 3 | 1 | 59.07fps |
| MSX / fMSX | 4 | 1 | 58.30fps |
| Atari 7800 / ProSystem | 3 | 1 | 56.14fps |

¹ 旧SYSTEMは約3秒の抽出試験。² 新SYSTEMは45秒の試験。PCM開始1回はゲーム開始時のみで、追加の再始動なし。8経路すべてでPCMは `RUNNING`、ハードウェアポインタは進行した。旧試験も今回も各経路のCPUガバナーは `ondemand` だった。

この結果は、抽出した8経路の音声再始動を解消するために`performance`や`schedutil`への変更が不要であることを示す。画面更新が60fps未満の経路は残る。PCM状態だけではサンプル内容の欠落や実際の聞こえ方は判定できない。PicoArchと単体エミュレータはRetroArchの映像スレッド設定を使わないため、この8経路の結果をそのまま当てはめない。全エミュの安定性を証明する試験ではない。

試験後にバインドマウントと一時停止フラグを解除し、BubbleのプロセスとADBの接続を確認した。SYSTEMの `active`・`default`・`healthy` は同じハッシュである。SDの再書き込みは行っていない。
