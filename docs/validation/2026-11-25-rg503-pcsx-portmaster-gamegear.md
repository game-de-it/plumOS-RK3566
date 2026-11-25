# RG503のPCSX-ReARMed・PortMaster・Game Gear追加試験

RG503の内蔵画面は960×544。既存SDで起動し、Wi-Fi SSHから操作した。

## PCSX-ReARMed単体版

『チョロQワンダフォー！』で、実機のevdevにFN相当の `BTN_MODE` を送った。従来の起動スクリプトではSDL 2を先に `LD_PRELOAD` していたため、PCSXの `SDL_PeepEvents` がSDL 2の同名関数に結びついていた。SDL 1.2とSDL 2ではこの関数のABIが異なる。PCSXの起動時はMaliとDRM共有のプリロードを維持し、SDL 1.2互換ライブラリに同梱SDL 2の読み込みを任せるようDockerビルドのソース準備を修正した。

同じゲーム、同じ本体で起動スクリプトだけを切り替えた。修正後は `SDL_PeepEvents` が `libSDL-1.2.so.0` に結びつき、FNの押下・解放がボタン10として届いた。1回目のFNで `Resume game` を含むメニューを画面キャプチャで確認した。2回目で同じプロセスの描画と内蔵PCMが再開した。表示はメニュー前59.31 fps、復帰後58.12 fps。

修正を組み込んだSYSTEMのSHA-256は `f360fab5aa4d1b8e123ee608b3ca6913a38d61ac917070d0f605a7dd23abb365`。従来SYSTEMをDockerで展開し、起動スクリプトを差し替え、対応するチェックサムの項目を更新してSquashFSを再生成した。転送後に実機でもSHA-256を照合し、SDを焼き直さず `boot-system trial` で起動した。診断用のプリロードなしで、BubbleのPlayStation一覧から『チョロQワンダフォー！』を起動。FNでメニューを開き、再度FNを押すと同じPIDでゲーム画面と内蔵PCMの `RUNNING` に戻った。単体版のメニューから終了してBubbleへ戻った後、`boot-system keep` で修正版を実機の既定に設定した。

## PortMaster

BubbleのAppsからPortMasterを起動した。カタログの読み込みと初回案内のカウントダウンが完了した後、実機のB相当入力で `Are you sure you want to exit PortMaster?` を表示した。Aで終了を確定すると、PortMasterのプロセスとセッションロックが消え、Bubbleへ戻った。同梱のPortMasterでこの手順が通ることを確認した。

## Game Gear

Bubbleの `2df4cda` は原寸のSTN応答と出力解像度でのパネル描画を分け、`bc1262b` は出力解像度で光のにじみを描く第3パスを追加している。RG503の標準は `08f551c` と `97ed867` に由来するB3。MFの `4ed77d6`、Bubbleの `6526d4c` と `96f9fa7` にあるDRMのフレーム提示間隔と音声の対策も照合した。試験したRK3566のGLES経路はすでに `video_threaded=true` を使っていた。

SD2の『Columns』をRetroArchのGenesis Plus GXで起動し、各条件で起動10秒後から15秒間、DRMのフレーム提示を数えた。全条件で同じCPUガバナー `ondemand` を使用し、内蔵PCMは `RUNNING` のまま進行した。

| LCDシェーダー | 表示fps |
| --- | ---: |
| 標準B3の3パス | 49.46 |
| STN応答とパネル描画の2パス、試験用 | 53.22 |
| 既存の `panel-only` | 50.76 |
| `off` | 54.65 |

標準B3と `off` で5.19 fpsの差があり、B3の出力解像度で行う描画が低下の一因。第3パスを外すと3.76 fps改善した。RetroArchの終了時統計でも、描画スレッドのドロップは標準B3で255件、2パスで128件だった。コアの申告値は59.92 fps。シェーダーを外してもそこまで届かず、残る差の原因は未特定。標準プリセットと起動時のCPU設定は今回の比較前の値を採用した。

## SD2の検体

TF2の `/dev/mmcblk2p1` 上に、Bubbleが使う `/storage/user/Roms/psx/` 経由で `PAC-MAN_WORLD.cue` とその実体 `PAC-MAN_WORLD.img`、および『チョロQワンダフォー！』の `chroQW.img` を配置し、元のファイルと一致することを確認した。Game Gearの `gamegear/Columns [V1.0].gg` もSD2にある。検体はSD2に保持する。

SD2のFATが未正常アンマウントと記録されていたため、起動時は既存のライブラリ索引が使われた。一時索引を作って既存844件がすべて見えることを確認し、Bubbleの `START` → `UI Settings` → `Refresh TOP` を実行した。PlayStation一覧に `chroQW` と `PAC-MAN_WORLD` が表示され、更新後の索引をSD2用キャッシュにも記録した。`PAC-MAN_WORLD` には `.cue` と `.img` の2行がある。詳細欄が `.cue` の行から単体版で起動し、オープニングの映像と内蔵PCM、FNメニューを確認した。
