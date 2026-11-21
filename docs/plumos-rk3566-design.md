# plumOS-RK3566 基本設計

2026年11月22日。最初の実機対象はRG353Mです。現行のJELOSベース試作は、起動、表示、入力、USB ADBの基準として使います。この文書は次の実装が従う設計です。

## シリーズとして守ること

- 機種ごとの動作が確認されたブートローダー、カーネル、DTBを使います。引き渡し後のPID 1、FE、ランチャー、設定、電源処理はplumOSが管理し、対応機種のユーザランドにsystemdを要求しません。
- 電源投入からFEを操作できるまでを短くします。内蔵画面とゲームパッドを使う最初の画面を優先します。Wi-Fiの接続、時計同期、転送サービス、SD2の探索、全ROM走査、画像取得は後から行います。ゲームやSD2のない状態でもメニューを操作できます。
- 読み取り専用のSystem、plumOSが管理する書き込み可能なRuntime、利用者のROM・BIOS等を分けます。利用者に見える構成を共通化し、パーティション番号やファイルシステムはブート基盤に合わせます。
- 描画を担当するプロセスを一つにします。ロゴ、FE、エミュレーター、アプリの間で画面の所有権を明示的に渡します。電源処理では書き込みを止めて同期し、ストレージを安全に閉じてから再起動・電源断します。
- 機種固有の画面、入力、音声、USB、電源の設定は機種プロファイルに持ちます。JELOSが同じイメージからDTBを選べる機種も、初回ストレージ準備とFEの受け入れは機種ごとに確認します。

Bubble／mini PLUSではplumOSの `/init` がFEを監視します。Pixel2 v2ではplumOSの初期化を経てBusyBox initに渡します。MFはstockのPID 1の下でplumOSの監視プロセスを起動し、A30／MMFもstockのMainUIに到達する経路からplumOSに渡します。共通点はFEとRuntimeの所有権、表示の優先、既存起動基盤の活用です。[mini PLUSのinit](https://github.com/game-de-it/plumOS-mini-PLUS/blob/baa7143a0bddb1aef5ebc8ee0c8c3358a6aa8d35/rootfs/mini-plus-frontend/init) · [Pixel2 v2のinit](https://github.com/game-de-it/plumOS-pixel2_v2/blob/19e135ba996de5d7b7a7ea915edca5eadc43d225/rootfs/pixel2/sbin/init) · [MFの監視プロセス](https://github.com/game-de-it/plumOS-MF/blob/0095017c39226ad1c22bf8df852202673075936d/docs/validation/2026-07-24-mf-system-supervisor.md) · [MFでFEを前倒しした変更](https://github.com/game-de-it/plumOS-MF/commit/ad0af44)

## ブートからFEまで

| 段階 | RK3566での設計 |
| --- | --- |
| Boot ROMからカーネル | JELOSのRockchipブート領域、U-Boot、DTB自動選択、カーネルと組み込みinitramfsを流用する。 |
| initramfsからSystem | JELOSのinitramfsが `boot` と `SYSTEM` を開く。フレームバッファが使える段階で共通ロゴを表示し、Systemに引き渡す。 |
| PID 1 | SystemのplumOS initとBusyBoxで、永続領域、デバイス、起動ログ、FEの監視、電源処理を管理する。FEの失敗を回数制限付きで再試行し、繰り返し失敗したら診断が可能な復旧状態へ進む。 |
| FEの初回描画 | 有効なキャッシュまたは空の初期カタログでトップを描き、物理ボタンを受け付ける状態にする。初回描画と入力受付を確認できてからreadyを記録する。 |
| 通常のサービス | USB ADB等の開発用サービスやWi-Fi・転送サービスの待ちをFEの起動条件から外す。SD2の準備とライブラリ更新は非同期に扱い、読み取り可能なメディアだけをFEに通知する。 |

### JELOSの引き渡し口

組み込みinitramfsは `switch_root` の実行先を `/usr/lib/systemd/systemd` に固定しています。初回の旧マーカーがある場合は `--unit=fs-resize.target` も渡します。カーネルをバイト単位で維持するため、新しいSystemのそのパスにはplumOS initへ `exec` する互換エントリを置きます。再起動後の実行プロセスはplumOSのPID 1です。既存のsystemdサービス、`jelos.target`、`systemctl` 依存は移行対象です。互換エントリは旧引数を明示的に処理し、旧JELOSの自動拡張・更新に委譲せず、設計した初回準備・復旧分岐へ渡します。後段のJELOS更新フックの扱いも配布用seedの受入項目に含めます。[JELOSのinitramfs](https://github.com/JustEnoughLinuxOS/distribution/blob/f8cac7b92040d734506e238f5a44560a4f0e81b0/packages/sysutils/busybox/scripts/init)

## 初回セットアップと専用画面

新規配布seedでは、既存のJELOS互換GPT `p1`～`p3` を維持します。`p4` をext4の管理Runtimeとして初回に所定サイズへ拡張し、残りの領域に `p5` をFAT32で作成して `/storage/user` にマウントします。Runtimeの暫定サイズはBubbleと同じ8 GiBです。最小カード容量はSystemの実測サイズと利用者領域に必要な容量で決定します。ROM・BIOS・画像はFAT32側、設定・ライブラリ状態や管理ファイルはRuntime側に置きます。現在の試作SDは既存の `p4` がSD末尾まで使っているため、ADB開発では現行レイアウトを使います。新しいパーティション構成を試すときは専用seedを使用します。

初回処理はplumOS initによるサービス起動前に行います。起動元SDを `boot` と `disk` の情報、実マウント、GPTの位置で特定し、seedの印と容量を確認します。開始・初期化対象・完了を永続化し、再起動時に実際の境界やラベルと照合して再開します。bootと利用者領域が想定と違う場合は処理を止め、画面とログに止まった段階を残します。初期化対象は新規に確保した領域です。通常起動では完了情報と実レイアウトを照合して、FEまで進みます。

画面は次の順に描きます。

1. **共通起動ロゴ**。フレームバッファを使えるようになった時点で表示します。
2. **初回セットアップ開始**。新規seedまたは中断からの再開を、通常起動と区別して表示します。
3. **処理中**。システム領域の確認・拡張・検証、利用者領域の作成・確認を、実際の処理に対応するラベルと進捗で表示します。
4. **初回セットアップ完了**。両領域のマウントと必要なディレクトリ作成を確認してから表示します。その後FEへ引き渡します。
5. **エラー**。失敗した工程、再試行または診断に必要な手がかりを表示します。表示の成否とストレージ処理の成否は別々にログに残します。

初回は進捗を読み取れる全画面表示を使います。通常起動の経路は共通ロゴからFEへ直接進みます。mini PLUSでは部分描画が初期userspaceで見えない事例があり、全画面化して初回セットアップ画面を実機で確認しています。[Bubbleの進捗フレーム生成](https://github.com/game-de-it/plumOS-Bubble/blob/ec81d42c0c2c39e7a32973bfe4df9b3027512a5d/scripts/build-bubble-external-initramfs.sh) · [mini PLUSの初回表示検証](https://github.com/game-de-it/plumOS-mini-PLUS/blob/baa7143a0bddb1aef5ebc8ee0c8c3358a6aa8d35/docs/validation/2026-10-31-mini-plus-firstboot-progress.md)

## 実機で確認した基準

起動済みのBubbleにSSHで接続し、PID 1がBusyBoxによる `/bin/sh /init` であること、System Aから起動していること、8 GiBの `p3` とFAT32の `p4` がそれぞれ `/storage` と `/storage/user` にマウントされていることを確認しました。保存済みの `first-boot.log` にはext4の拡張、FAT32領域の作成と確認、Systemへの引き渡しが記録されています。実機の外部initramfsにはセットアップ開始、拡張、利用者領域作成、検証、エラーの描画フレームが収録されていました。今回のBubbleは初回セットアップ済みのため、画面の切り替わり自体は保存ログと収録素材から確認しました。

| 同じ定義で採取した指標 | Bubble | 現行RG353M試作 |
| --- | ---: | ---: |
| カーネル起動から稼働中のFEプロセス生成まで | 約4.53秒 | 約13.99秒 |

数値は `/proc/<pid>/stat` のプロセス開始時刻です。電源投入、最初の描画、操作可能になった時刻は別の指標です。現行RG353MではJELOSの自動マウント完了が約11.2秒で、FEのライブラリ走査は39 msでした。現時点で優先するのはFEに到達するまでの待ち順と、起動に必要な処理範囲です。

## 検証の順序

1. **Systemへの引き渡し**。RG353MでplumOSのPID 1、初回描画、ゲームパッド、ADB、正常終了・再起動を確認します。まずレイアウト変更を伴わない試作で、起動と終了を独立して検証します。
2. **通常起動の計測**。現行試作と同じRG353M・SD条件で複数回コールドブートし、電源投入、ロゴ表示、PID 1到達、FE初回描画、最初の入力応答を別々に記録します。初回セットアップの時間を分け、通常起動でFEを操作できるまでの中央値を現行試作より短くします。Wi-Fi未接続とSD2不在でも同じ経路で測ります。
3. **新規seedの初回起動**。専用SDで、開始・処理中・完了画面からFEへの遷移、FAT32領域の作成、途中中断後の再開を確認します。2回目以降の通常起動では、初回の画面やパーティション変更が再発しないことを確認します。
4. **更新と対象機種**。通常の開発・検証はADBで差分配備します。System A/BやRuntime更新はPID 1・初回セットアップ・FEの境界が安定した後に設計を詰めます。他の機種はプロファイルを追加し、表示・入力・音声・ADBおよびストレージの受け入れ結果を機種ごとに記録します。
