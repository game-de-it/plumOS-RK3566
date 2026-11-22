# RG353Mの出荷用エミュレータランタイム

従来の全プロファイル試験では、Pyxelを別のSquashFSで一時マウントしていた。通常のDockerビルドはSDLの段階で止まり、出荷用SYSTEMにはPyxelのランチャー、Python、依存ライブラリが収録されていなかった。

現在のビルドでは、RetroArch、Libretro、PicoArch、Standalone、Pyxel、PortMaster、FreeJ2ME-Plusをすべて同じSYSTEMへ組み込む。PyxelはBubbleのPythonとSDLのビルドを使い、PortMasterはBubbleの固定版を使う。J2MEの既定は、ゲームを起動できなかったSquirrelJMEからFreeJ2ME-Plusへ変更した。JavaはDockerで作ったOpenJDKランタイムを同梱し、Java SoundにplumOSのALSA経路を渡す。[BubbleのPyxel設定の履歴](https://github.com/game-de-it/plumOS-Bubble/commit/cf99f17d76747be65cc27615de2259c3b5a13c0a) · [FreeJ2ME-Plus 1.53](https://github.com/TASEmulators/freej2me-plus/tree/52b25f75824d247c23e352625be45157bfe87620)

SYSTEM生成前にFEのカタログからカバレッジを再生成し、97システム・196経路が参照するランチャー、コア、Standaloneバイナリと、コンポーネントのチェックサムを検査する。Pyxelのランチャーを欠いた複製を検査にかけ、ビルドが失敗することを確認した。SDイメージ生成にも全7コンポーネントの存在確認を追加した。実機試験のランタイムは起動中のSYSTEMから読み込む。

## Dockerでの生成

`prototype/build-emulators.sh` がピン留めしたソースから7コンポーネントを生成し、`prototype/build-bubble-system.sh` がその `runtime` を検査して出荷用SYSTEMを作る。SDイメージ生成にはこのSYSTEMを渡す。既存SDでは `boot-system publish` と `trial` で試験起動し、動作確認後に `keep` で既定にする。

PortMasterのネイティブ実行環境では、Python専用のglibcをライブラリ検索パスから外した。起動ログ用ディレクトリは初回起動時に作成する。FreeJ2ME-PlusのJavaとJARはSYSTEMに置き、Javaのログと設定にはユーザー領域の書き込み可能な作業ディレクトリを渡す。

## 2026年11月22日の実機試験

RG353Mの既存SDへUSB ADBでSYSTEMを転送し、実機上でも全196経路と7コンポーネントのファイルを照合した。以下の10検体は最終SYSTEMの測定値で、Powermangaの行は公開設定追加前の先行SYSTEMでの結果。音量は20％、内蔵スピーカーのミキサー値は全検体で `215,215`。BubbleのテキストUIから通常の起動処理を通し、試験用の設定とセーブ領域を分けて計測した。

| FEの経路 | 検体 | DRM画面提示 | PCM |
| --- | --- | ---: | --- |
| Pyxel | Finardry（SD2） | 29.86 fps | RUNNING、ポインタ進行 |
| Pyxel | PFS（SD2） | 59.33 fps | RUNNING、ポインタ進行 |
| RetroArch / FreeJ2ME-Plus | Cento | 59.10 fps | RUNNING、ポインタ進行 |
| RetroArch / QuickNES | 悪魔城伝説（SD2） | 59.67 fps | RUNNING、ポインタ進行 |
| PicoArch / QuickNES | 悪魔城伝説（SD2） | 59.13 fps | RUNNING、ポインタ進行 |
| Standalone / DraStic | New Super Mario Bros. | 54.41 fps | RUNNING、ポインタ進行 |
| Ports / PortMaster | Playload Handheld 1.0.2（ROM2） | 59.58 fps | RUNNING、48 kHz |
| RetroArch / 2048 | 同梱項目 | 59.45 fps | PCM出力なし |
| RetroArch / Mr.Boom | 同梱項目 | 58.83 fps | RUNNING、ポインタ進行、DMA開始3回 |
| RetroArch / MAME 2003-Plus | Strider Hiryu | 59.37 fps | RUNNING、ポインタ進行 |
| Ports / PortMaster | Powermanga | 計測なし | ゲーム本体が起動直後に異常終了 |

CentoはJava側のMIDletと240×320のCanvas生成を記録し、FNでRetroArchメニューが表示され、ゲーム面に戻ることをログで確認した。CentoのTone Player初期化には警告が残った。PlayloadはMali上でのエンジン起動とプレーヤーの表示を確認した。Powermangaは初回の設定ファイル読み込み警告に続いてセグメンテーションフォルトが起きた。PortMasterは起動セッションの終了後にマウントを解除した。[PortMasterのPowermanga配布ページ](https://portmaster.games/port/?name=powermanga)

FPSは画面提示の計測値。PCM進行はスピーカーからの出力経路の動作を示す。以前の全プロファイル試験で検体を用意できなかった22経路は収録と依存ファイルを確認した。従来の速度・音切れの計測結果と、各タイトルに必要なBIOS・追加データは前回の試験記録を参照。[全プロファイル試験](2026-11-22-rg353m-emulator-matrix.md) · [修正と再試験](2026-11-22-rg353m-emulator-fixes.md)

## FEの公開設定

ファイルがそろっていても、従来は8システムをBubbleのライブラリスキャンが除外していた。ビルド時に全97システムを有効にし、製品検査も無効なシステムを検出するようにした。対応メディアのある項目が一覧に現れる。2048とMr.BoomにはSYSTEM同梱の項目を設け、通常のFE操作からRetroArchを `--no-content` で起動する。カタログが更新されたときは、既存SDでもFEのキャッシュが自動で再生成される。

最終のARM64 Dockerビルドで、従来非表示だった6システムに対応拡張子のファイルを置き、実際にFEが使うライブラリスキャナで列挙されたことを確認した。2048とMr.Boomの同梱項目は、Dockerと実機の通常ライブラリで生成され、RetroArchのゲーム面とFNメニューを確認した。MAME 2003+も供給されたROMで起動した。

Dockerで生成したSDイメージは、JELOSの先頭16 MiB、GPT、カーネル、DTB、extlinux設定を元イメージと比較した。検証用の複製を8 GiBに広げ、初回のp5作成とp4拡張、再起動後の続行、既存データ保持、SYSTEM更新、plumOS initの復旧を確認した。RG353Mでの起動確認は既存SDをUSB ADBで更新して行った。

## 最終成果物

- SYSTEM SHA-256 `07b4a8608ca276107901c5724b91c2bd76af53466afa1d7d1cf847c218e5a429`
- Bubbleユーザーランド SHA-256 `2e4194cd6e351af9627312196f767d15b1f00ac067d8fdcb7a040d4ac92aaf37`
- 2.05 GiBのraw SDイメージ SHA-256 `3576132024f19475643eeb20770b629c368de2b8d89077f21b917cea86806314`
- gzip版 SHA-256 `83fb8837755a3285f63afbe9f477efff9ed63157bea5344503974b68fcd7e940`

最終SYSTEMをADBで既定に設定し、通常再起動でも同じハッシュが選ばれた。起動準備マーカーはカーネル起動から6.21秒。plumOS init、通常のBubbleプロセス、p5・SD2の読み書きマウント、USB ADBのCONFIGURED、音量20％を確認した。試験用マウントと起動保留を解除した状態で、FEの実行ファイルをSYSTEMから参照している。復旧用SYSTEM `0218880c4a5b494a74f496f5e771cd65f6f9a9d4861f21df2ddb91ad0a1b66e6` は実機に保持した。
