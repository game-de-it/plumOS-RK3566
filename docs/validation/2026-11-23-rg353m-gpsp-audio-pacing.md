# RG353M gpSP音声と描画ペーシングの修正

2026年11月23日（JST）。gpSPはGBAの標準コアとして必要であり、CPUガバナー変更だけを音飛び対策にしない。前回の `e9c64b4` で行ったmGBA標準化とNES/GB/GBC/GBAの `schedutil` 標準化は、この修正で取り消した。

## 履歴から特定した原因

- [plumOS-Bubble `96f9fa7`](https://github.com/game-de-it/plumOS-Bubble/commit/96f9fa79198a2f72f416ac5e66e12d4280246ac7) は、DRM page flip待ちがRetroArchの音声生成経路を止め、低負荷のNESでもALSAが `PREPARED` に戻ると記録している。修正は `video_threaded=true` で、`ondemand` のまま実聴と連続再生を確認している。
- [plumOS-V90S V2 `af5f445`](https://github.com/game-de-it/plumOS-V90S_V2/commit/af5f4457dddb8006fab8788b4ffee13c8195ec0f) も映像スレッドと実機の画面更新周期を合わせた履歴である。
- RK3566側の `579d3da` は、Bubbleのランチャーが指定するDRMの `video_threaded=true` を、`prototype/emulators/assemble-runtime.sh` で明示的に `false` に書き換えていた。前回の測定ではCPU使用率の問題と誤認した。

この書き換えを削除し、gpSPをGL/KMSの描画経路へ加えた。DRMのスレッド化だけではPCM再始動は消えるが画面更新が57fps程度に下がったため、gpSPだけ描画経路も変える必要があった。CPUは `ondemand`、音声は通常のALSA同期出力のままである。

## 実機の比較

同じRG353M、同じGBA ROM『Densetsu no Stafy』、内蔵スピーカー20％で測定した。PCM開始回数1は起動時の1回であり、測定区間中の再始動はないことを示す。画面更新はDRMイベントの観測値で、ゲーム内部のFPSとは区別する。

| 経路 | CPU | 時間 | 画面更新 | PCM開始 |
| --- | --- | ---: | ---: | ---: |
| 旧DRM、映像スレッドなし、gpSP | ondemand | 60秒 | 58.63fps | 28回 |
| DRM、映像スレッドあり、gpSP | ondemand | 90秒 | 58.91fps | 1回 |
| GL/KMS、映像スレッドあり、gpSP | ondemand | 90秒 | 59.74fps | 1回 |
| 最終SYSTEMのFE標準起動、gpSP | ondemand | 90秒 | 59.81fps | 1回 |

同じDRM映像スレッド修正で、GB Gambatteは60秒・PCM開始1回、NES QuickNESは60秒・1回、GBC Gambatteは60秒・1回になった。gpSPのGL/KMSでFN操作後にメニュー区間の画面更新を観測し、復帰後にPCMが再び進行した。メニューの実際の見え方と音声の実聴は利用者確認が必要である。

最終SYSTEMではFEの `plumos-text-ui launch gba ... --execute` を**プロファイル指定なし**で起動し、実行コマンドに `gpsp_libretro.so`、`--cpu ondemand`、追記設定に `video_driver=gl` と `video_threaded=true` が入ることを確認した。クロックは408〜1992MHzで変動しており、最大固定ではない。

## ビルドと更新

Dockerで修正済みランタイムとSYSTEMを生成した。ビルド時の検証は196のFEプロファイル、可視Apps、9コンポーネントで合格した。SYSTEMのSHA-256は `f4aca77c10734c899b540a5f5bf4332fdce812f40442dd52c4736c1b973c7818`、Bubbleユーザランドは `e8836298d79be83fb40a313f7d5df6749cbd68f62ab90ea130b904c340c32dbc`。

USB ADBで既存SDへSYSTEMを転送し、`boot-system publish` の照合後に試験起動した。FE・ADB・gpSPの90秒試験後、`boot-system keep` を実行し、`active`・`default`・`healthy` が同じ新SYSTEMのハッシュになった。SDの焼き直し、カーネル、DTB、ブート領域、パーティションの変更はない。旧 `/flash/SYSTEM` は復旧先として保持した。

ビルドに含まれるランチャーと、試験中にADBで置いたランチャーのSHA-256はともに `b707ffa3ee2230e250c58aff47d9917f97847dbce3c07b77599aaaf16b5dfe22`。試験用の別実装は残していない。

残る確認: 利用者によるgpSPの音とFNメニューの実聴・目視。重いコアの性能由来の音飛びや、USB DACの物理切替は本件の判定に含めない。
