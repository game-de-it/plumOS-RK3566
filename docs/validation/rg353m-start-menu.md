# RG353MのSTARTメニュー監査

2026年11月23日（JST）。RG353Mの出荷用SYSTEMとBubbleの固定リビジョン `ec81d42c0c2c39e7a32973bfe4df9b3027512a5d` を比較した。実機の `menus.json` はBubbleとSHA-256が一致する。Appsは監査済みのため対象外とした。実機のFEバイナリをテキストモードで操作し、設定を変更する試験には `/run` の一時設定を使用した。音量の試験後は保存値の8に戻した。

## UI Settings

- Refresh TOPの実行、UI Mode、Show Empty Systems、Favorites On TOP、Recent On TOP、ROM Cursor Wrap、Open Last ROM At Boot、Sort Systems、Sort ROMs、Scan On Enterの保存を確認した。最後のROMの自動起動そのものはこの監査で扱っていない。
- Theme SettingsではTheme、TOP Layout、Transition、Time、Axis、Easingの操作を確認した。Name、Status、Layout、Fontはテーマ情報として表示される。

## System Settings

| 項目 | 実機結果 |
| --- | --- |
| Volume | 8から9へ操作して実行時の適用成功を確認した。 |
| Audio Output | Speaker / Headphoneを表示する。Headphoneを保存しても、端子未接続時のミキサーはSPKのまま。現在の出力経路はメニューの選択値よりもジャック検出に従う。 |
| Brightness | 値の保存後に `runtime apply failed`。RG353Mのバックライトは `/sys/class/backlight/backlight/brightness` を公開しており、試験中の読み戻し値は77のままだった。 |
| Lid Suspend | On / Offを保存できる。実機の入力一覧に蓋・ホールセンサーがなく、設定に対応する実機動作は確認できない。 |
| Lumination、Display Color | どちらも `Not Supported`。Display Color配下のContrast、Hue、Saturationは開けない。接続中のDSIコネクターには4つのDRMプロパティがあり、各50を読み戻せる。FEがこれらを使う処理は `device_id=bubble` に限られている。 |
| Time Settings | Current Time、Automatic Time、Sync Now、RTC Status、Timezone、Manual Timeは表示される。Automatic Timeの有効化とSync Nowは `plumos-time-sync` が未収録のため同期に失敗。RTCの読み取りは動作する。Timezoneの選択値はFEに反映され、読み取り専用の `/etc/TZ` への反映は失敗した。Manual Timeの年・月・日・時・分とApplyを表示し、年の下書き変更を確認した。Applyによる実機時計の変更は監査範囲外。コード上、RTCへの保存も同じ未収録のヘルパーに依存する。 |
| Language | 日本語への切替を一時設定で確認した。 |
| System Update | メニューから更新ヘルパーが起動し、適合する署名付きパッケージがないと表示した。適用と再起動を伴う試験は今回の範囲外。 |
| Factory Reset | `No Defaults Installed` のみ表示。出荷時のRetroArch・PicoArch・Standalone用の既定値は収録済みだが、RG353Mとして起動したFEは別名のディレクトリを参照する。リセット用の `plumos-factory-reset` も未収録。All Emulator Settingsと個別3項目は使えない。 |
| Storage Check | 状態取得は動作した。今回はカーネルがp5のアンマウント警告を記録しており、メニューは `Dirty - repair required` と表示した。読み書きマウント中のp5に対して、この操作でfsckを完走したことは確認できない。 |
| INFORMATION | Device Model、plumOS、Vendor、Kernel、GPU、Display、Audio、Storage、Storage Health、Memory、Base OSを表示。GPUは `PowerVR GE8300`、Displayは `sunxi backlight` と誤表示する。実機のGPUドライバーはMali-G52を報告し、画面はRockchip DSI。 |

## Network Settings

- Wi-Fiの接続状態を読み取り、Connect Wi-FiからSSID検索の結果画面まで確認した。INFORMATIONでは接続状態、IPアドレス、電波強度、リンク速度、周波数を表示した。
- NW ServiceにはSSH、FTP、SFTP、Samba、ADBが表示される。各項目は実機のFEで切り替えできず、INFORMATIONにはすべて `Not Installed` と表示された。 `plumos-network-services` は未収録。USB ADBはplumOS initから起動しており、実際のUSB接続は `configured` だった。

## Performance Settings、Help、電源

- Performance SettingsのSystem切替、CPU Governorの保存、Reset to Defaultを確認した。NESの既定値はPerformanceで、試験設定ではOndemandへの保存と既定値への復帰ができた。
- Helpの表示を確認した。掲載されているWi-Fi/SSHの救援画面は現行FEで無効化されている。
- RebootとShutdownの確認から、plumOS init用の電源ヘルパーまで、実機でdry-runを通した。
