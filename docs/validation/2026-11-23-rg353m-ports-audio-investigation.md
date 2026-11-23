# RG353M Portsの無音調査（継続中）

2026-11-23（JST）。利用者からPortsゲームの無音報告を受けた。SD2の`Roms/PORTS`には`Apotris.sh`のみがあり、`apotris/assets`には音楽モジュールと効果音WAVが存在する。ApotrisのAArch64実行ファイルはSDL2を利用する。ゲームの`log.txt`には`Failed to open PWM`とセグメンテーションフォルトが残る。実行ファイル内のPWM文字列は振動機能を指しており、この警告を無音の原因と断定できない。

現行のPortMasterゲーム用ランチャーは、起動時に`plumos-audio-output prepare`を実行し、`ALSA_CONFIG_PATH=/run/plumos-353m/audio/asound.conf`、`AUDIODEV=plumos_output`、`SDL_AUDIODRIVER=alsa`を子プロセスへ渡す。Apotris側のスクリプトにはこれらを上書きする記述がない。RA、PICO、OpenBORのUSB DAC再生は別試験で確認済み。Portsで実際にALSA PCMが開かれるかは未確認である。

他経路の監査では、Pyxelランチャーに旧`/run/plumos/audio/asound.conf`の既定値が残っていた。`prototype/emulators/assemble-runtime.sh`でRK3566の実行時ルートを参照するよう修正した。RA、PICO、単体エミュレータのランチャーは管理対象のALSA設定を参照する。

本体はWi‑FiのFTP/SSHへ応答し、MacはUSB ADBインターフェースを列挙するが、ADBプロトコルは`offline`である。Mac側のADB再起動、ケーブル抜き差し、USBデバイスのリセットでは回復しなかった。FTPは利用者領域のファイル転送のみで本体コマンドを実行できず、SSHは公開鍵認証のみで利用可能な鍵がない。共有領域へ`plumos-ports-audio-report.sh`を置き、File Managerで実行するとPortMasterログとPCM状態を記録して監督下の`adbd`を再起動するようにした。実機のログが取れてから原因の確定と修正を続ける。
