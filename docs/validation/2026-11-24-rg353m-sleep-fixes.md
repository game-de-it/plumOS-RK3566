# RG353Mの単体エミュレータとPyxelのSleep修正

2026-11-24。前回の [Sleep試験](2026-11-23-rg353m-sleep-matrix.md) で残った4件を、同じRG353MとSDで再試験した。本体はUSB ADB接続中（ACオンライン）で、電源メニューから `mem` に入り、RTCで復帰させた。

## 修正の根拠

- **PCSX-ReARMedとYabaSanshiro**。以前の起動確認 (`579d3da`) ではJELOSのSDL2を使用していた。独立したユーザーランドを導入した `80b9822` 以降、同じ `/usr/lib/libSDL2-2.0.so.0` はDockerのDebianツールチェーン由来になっていた。そのSDL2で起動失敗を再現した。DRM仲介を外した比較でも再現し、PCSXではカーソルIOCTLの `ENXIO` を観測した。Pyxel用にビルド済みのGLES専用KMSDRM SDL2を両方の単体エミュレータに指定すると、同じ内容で描画が始まった。
- **DraStic**。ARM32のDraSticが64ビットのALSAルーターを開いていた。Dockerで同じルーターをARM32向けにもビルドし、32ビット実行ファイルが読むALSA設定からそのプラグインを指定した。描画用の64ビットrunnerは従来のALSA設定を使用する。
- **Finardry**。ゲームを一時停止する間、電源メニューがゲームと同じevdevを別々に開いていた。電源メニューの表示中はゲームパッドを専有し、メニューを閉じた時点で解放する。別のevdev読取り口でメニュー操作が配信されないことを確認した。電源ボタンは既存の経路で処理する。

## USB ADB

試験開始前、MacのUSBツリーに `RG353M ADB` があり、`adb devices` は空だった。MacのADBサーバーを停止して立ち上げると、RG353Mの電源・ケーブル・FEに触れずに復旧した。今回の切断前のUSB転送ログは採取できておらず、過去のFunctionFS再接続不具合と同じ原因かは未確定。Sleepの試験では復帰時に既存のgadget再起動がログに残り、Mac側に新しいADB transportが現れた。

## 既存SDへの更新と終了処理

既存SDでは過去のテストで書き込み層の `lib` がopaqueになっており、SYSTEMのARM32プラグインが隠れていた。音声設定の生成時に、AArch64・ARM32のペアが揃うSYSTEM側のプラグインを優先するようにした。実機では試験用の書き込み層も片付けた。

DraSticを電源メニューの終了経路で停止すると、停止自体が成功しても作業用のoverlayとbind mountが残り、`/storage` の読み取り専用への切替が失敗して再起動が取り消された。ランチャーはDraSticとrunnerを個別に待ち、初回の終了シグナルを受けた後は再送に中断されずにマウントを解放する。実機の同じ終了経路で、TERM後の残存マウントが8件から0件になった。

## ビルド

Dockerで生成した最終SYSTEMのSHA-256は `bd5fb410d5ffdee01c240034445e1606748e3e4a8fcc88e376480efd9c209458`。196件のFE起動プロファイル、表示対象のApps、9コンポーネントのチェックサム、ARM64・ARM32のALSAプラグインを検証した。実機側の作業領域を確保するため、Mac側に同じSHA-256のコピーがあることを確認し、起動選択に使われていない古いSYSTEMを1本だけSDから削除した。

USB ADBで最終SYSTEMを転送し、実機の `boot-system publish` が照合した後に `trial` で起動した。起動中に見える修正ファイルの内容はSYSTEM内のハッシュと一致した。カーネル・RG353M DTBのSHA-256とSDのパーティション構成は試験起動の前後で一致した。p5は `/storage/user` にマウントされ、SDは再書き込みしていない。

## 実機結果

| 経路 | 検体 | 最終SYSTEMでの確認 |
| --- | --- | --- |
| PCSX-ReARMed | Choro Q Wonderful! | 起動して電源メニューからSleep。復帰後も同じPCSXプロセスがDRMを保持し、内蔵PCMがRUNNING。 |
| YabaSanshiro | The Tower | EGL/GBM初期化成功。復帰後も同じプロセスでDRMと内蔵PCMが動作。 |
| DraStic | New Super Mario Bros. | ARM32のALSAルーターで起動。復帰後に同じrunnerで描画とPCMを確認。TERM終了後の作業マウントは0件。 |
| Pyxel | Finardry | 電源メニューからのSleep後も同じプロセスが描画を続け、内蔵PCMがRUNNING。 |

4件とも電源メニューで送った方向キーがゲーム側のevdev読取り口へ配信されず、復帰後に送った入力は再び配信された。確認はDRM、PCM、プロセス、合成入力の記録に基づく。音の聴感と物理ボタンでの復帰は今回の試験項目に含めていない。先行試験ではDungeon Antiqua、PPSSPP、OpenBOR、RetroArch gpSP、File Managerの復帰も確認した。

最終SYSTEMを `boot-system keep` で既定にし、`active`、`default`、`healthy` の一致を確認した。試験アプリの終了後にFEが復帰し、USB ADB、Wi-Fi接続、p5のマウントを確認した。試験中に使った中間SYSTEMも、既定や復旧候補に選ばれていないことを確認してSDから取り除いた。
