# ネットワークとUSB

[English](network.md) · [ガイドの目次](README.ja.md)

Wi-Fiハードウェアが検出された機種では、`START` → `Network Settings` → `Connect Wi-Fi` でSSIDを選びます。同じメニューの `INFORMATION` でIPアドレスを確認し、`NW Service` で必要なサービスを有効にします。

| サービス | 接続方法 |
| --- | --- |
| SSH / SFTP | 本体のIPアドレス、ポート22。初期ログインは `root` / `plumos`。SFTPは利用者領域から開きます。 |
| FTP | 本体のIPアドレス、ポート21。匿名で利用者領域に接続できます。 |
| Samba | 共有名は `SDCARD`。初期ログインは `plumos` / `plumos`。共有は利用者領域を開きます。 |
| USB ADB | データ通信できる端子とケーブルでパソコンにつなぎ、`adb devices -l` で確認します。`NW Service` で切り替えられ、設定の反映に再起動が必要な場合があります。 |

初期ログイン情報はシリーズ共通で、USB ADBはrootシェルを提供します。使用するサービスを、信頼できるネットワークやパソコンで有効にしてください。
