# RG353MのWi-Fi起動

plumOS initへの移行後、JELOSの `kernel-overlays.service` 相当の処理が呼ばれず、モジュールとファームウェアへのリンクが解決できなかった。実機では内蔵SDIOのモーダルエイリアス `sdio:c07v024CdC821` が見えていたが、起動時のネットワークインターフェースは `lo` のみだった。JELOS同梱の `kernel-overlays-setup` を実行し、モーダルエイリアスを `modprobe` に渡すと `8821cs` が読み込まれ、`wlan0` が生成された。

plumOSの起動時にWi-Fiをバックグラウンドで初期化する。BubbleのWi-Fi設定を使い、無効のときは起動時の接続を実行しない。SSIDのスキャンと設定画面からの接続はBubbleの通常のネットワーク制御を通す。Wi-Fi起動処理と画面からの接続は同じロックで順序付けする。

DockerビルドではBubbleのWi-Fi制御とDHCPフック、JELOS同梱のサプリカントに対応する `wpa_cli 2.10` をSYSTEMに収録する。DHCPフックのDNS書き込み先をJELOSの `/etc/resolv.conf` の参照先に合わせ、DHCPリースの更新を維持する。接続済みのプロファイルは永続ストレージ上の `frontend/config/wpa_supplicant.conf` に保存し、次回起動で使う。SSIDやパスワードをビルドやGitに収録しない。[WPA Supplicantの配布元](https://w1.fi/releases/)

## 実機

2026年11月22日（JST）。RG353Mの既存SDにUSB ADBで転送し、SYSTEMのSHA-256 `ec3f72d8cd265b634d424e88591fecfcb550c562036e7ce912db25b361ba051d` を照合して試験起動した。カーネル起動から5.43秒で `wlan0` が生成され、6.40秒でBubbleとUSB ADBが起動準備完了になった。SSID登録前は `wpa_cli ping` が `PONG`、ネットワーク制御は `result=ready` と `wpa_state=DISCONNECTED` を返した。Bubbleと共通の制御経路で周囲のSSIDを3件検出した。修正版SYSTEMを既存SDの既定に登録し、従来の復旧用SYSTEMを保持した。

本体のBubbleでSSIDを登録した。ADBから、保存されたプロファイルが1件で権限が0600のことを確認した。通常再起動をUSB ADBから要求し、起動IDの変化と、画面を操作せず保存済みのプロファイルで `wpa_state=COMPLETED` になることを確認した。IPv4アドレス、デフォルトルート、DNS、DHCPリース管理プロセスを確認し、ゲートウェイへのpingにも応答した。BubbleとUSB ADBの準備完了はカーネル起動から6.37秒で、p5とSD2も再マウントされた。

## SDイメージ

Dockerで同じSYSTEMを使ってSDイメージを生成した。JELOSのブート領域、カーネル、DTB、extlinux設定を比較し、8 GiBの複製で初回p5作成、既存データ保持、SYSTEM更新、plumOS init復旧を確認した。gzip版SHA-256は `0efd2f455aad51aec4865becf561b1325aa3155b3c433d100ef1ed56537608bc`。
