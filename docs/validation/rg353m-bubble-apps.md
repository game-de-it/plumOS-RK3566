# RG353MのBubble Apps

Bubbleの固定リビジョン `ec81d42c0c2c39e7a32973bfe4df9b3027512a5d` にある9項目を対象にした。出荷用SYSTEMで不足していたNextCommander、Music Player、Game Gear、スクレイピングのHTTPSランタイム、SD2修復用のFATチェッカーをBubbleのDockerビルドから収録した。Appsの公開項目が参照するランチャーと実行ファイルをSYSTEM生成前に検査する。[BubbleのApps実装](https://github.com/game-de-it/plumOS-Bubble/blob/ec81d42c0c2c39e7a32973bfe4df9b3027512a5d/package/frontend-bubble/plumos/config/frontend/apps.json)

- NextCommanderはアプリのリソースディレクトリから日本語フォントを読み込む。
- Music Playerは有効なSDのMusicフォルダーとSD2を検索し、plumOSの内蔵音声経路を使う。
- Game GearはBubbleのDRMフロントエンドを使い、キャッシュとROM一覧から選択したゲームをRetroArchへ渡す。
- Pyxel Setupは個別のrequirementsがあるときだけ追加パッケージをセットアップする。既定ではSYSTEM同梱のPythonモジュールを読み込んで検証結果を表示する。
- ScrapingはLibretroのCRC照合を使い、サムネイル一覧を取得できない場合は照合した正式名からPNGを取得する。[Libretroのデータベース](https://github.com/libretro/libretro-database) · [Libretroのアートワーク](https://github.com/libretro-thumbnails)
- Repair SD2はRG353Mの通常のTF2アンマウント・再マウント経路を再利用する。DockerのFAT32検証用イメージではチェックの前後でファイル内容が一致し、コードページ936と読み書き状態で再マウントされた。ext4は修復対象外として停止した。実機の利用者カード上のファイルシステムには修復を書き込んでいない。
- PortMasterはSDL2の画像用ライブラリだけをランタイムへ接続する。NextCommander専用のglibcをPortMasterの検索パスから除外する。

## 2026年11月22日の検証

| Apps項目 | 確認結果 |
| --- | --- |
| Scraping | 実機のメニューから設定画面へ遷移。最終SYSTEMの実機ではCRC一致まで確認したが、PNG取得時に名前解決がタイムアウトした。Dockerでは同じランタイムとROMで512×743のPNG取得に成功。 |
| File Manager | 実機のAppsから起動し、DRMと内蔵コントローラーを取得。最終SYSTEMでフォントの読み込みエラーが解消され、QuitでAppsに戻った。 |
| Music Player | 実機のAppsから起動。SD1の検証用WAVを一覧から再生し、内蔵コントローラーと `plumos_output` の48 kHz出力、Bでの復帰を確認。検証WAVは削除した。 |
| RetroArch | 実機のAppsからRGUIメニューを表示し、Quit RetroArchでAppsに戻った。 |
| Pyxel Setup | 実機でPyxel、pygame、NumPy、Pillowを読み込み、結果画面を表示した。 |
| PortMaster | 最終SYSTEMでMali/DRM画面とコントローラーを初期化し、Appsに戻った。実機ネットワークでは外部カタログの一部がタイムアウトした。機種フィルターはBubble由来の互換プロファイルを使用する。 |
| Update PortMaster | 実機で公式stableを照会し、インストール済みの2026.06.23-0015と一致。更新不要の結果画面を表示した。 |
| Repair SD2 | 実機の確認画面と、Dockerの検証用FAT32イメージでの検査と復帰を確認した。 |
| Game Gear | 実機でSD2上の20本を一覧に表示。ColumnsをRetroArchに渡し、終了後にGame GearとAppsへ戻った。 |

最終SYSTEMのSHA-256は `a7a597638d690d2a9fd2f4b0e3f796f1f50cd6dd165065b656bedcb85876fb5c`。USB ADBで既存SDを更新して既定に設定し、通常の再起動で同じSYSTEMが選ばれた。plumOS init、Bubble、USB ADB、p5とSD2の読み書き、保存済みSSIDへの自動接続を確認した。
