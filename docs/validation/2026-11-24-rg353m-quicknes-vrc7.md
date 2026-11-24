# QuickNESでのLagrange Point起動

Lagrange PointはKonami VRC7a（マッパー85、NES 2.0サブマッパー2）を使用する。[VRC7の仕様](https://www.nesdev.org/wiki/VRC7)

QuickNESの固定リビジョン `058d665` はVRC7のマッパーとFM合成を実装済み。今回のROMにはNES 2.0の既定の拡張機器番号がバイト15に入っている。旧ローダーはバイト15が0以外だとヘッダーの上位マッパー情報を捨てるため、85を5と判定していた。NES 2.0のヘッダーを識別し、従来の補正は旧iNES形式にだけ適用する。拡張マッパー番号または拡張ROMサイズを必要とするヘッダーは明示的にエラーにする。[固定リビジョンのVRC7実装](https://github.com/libretro/QuickNES_Core/blob/058d66516ed3f1260b69e5b71cd454eb7e9234a3/nes_emu/Mapper_Vrc7.cpp)

ROMは編集せず、保有の `Lagrange Point (Japan).nes` と `LagrangePoint.nes` で検証した。旧コアではブート画面を抜けず、修正コアでは両方でタイトルと名前入力画面が出た。DockerのLibretro試験で日本語版の名前を入力し、オープニングを経て最初の操作画面まで進んだ。Binary Landは同じ入力で修正前後のPCMとフレームが一致した。FM出力だけを0にした診断用コアとの比較で、演奏時にVRC7がPCMへ混ざることを確認した。

本番カタログのDockerビルドでQuickNESだけをビルドし、パッチのSHA-256を記録した。最終SYSTEMのSHA-256は `a36e56daa17f63bcc33cfab8baf23064bdfeaf4169d3ed3b44c5ad9e4b1853d5`。USB ADBで転送して試験起動し、既定のSYSTEMに設定した。

RG353Mの通常のFE起動プロファイルを経由し、RetroArchで `Lagrange Point (Japan).nes`、PicoArchで `LagrangePoint.nes` を起動した。両方でDRM描画、内蔵スピーカーPCMのポインター進行、FNメニューへの切替と復帰を測定した。検証中のセーブ領域は一時ディレクトリに分離した。試験用SYSTEMの転送前に、Macに同一ハッシュのコピーがある旧候補SYSTEMをSDから1本取り除いた。

## Stereo Panning

同じゲーム入力で、最初の操作場面を含む25秒分（1,100,819ステレオフレーム）の出力を比較した。QuickNESの `Non-Linear` では左右差が0、`Stereo Panning` では1,098,423フレームで左右が異なった。VRC7だけを無音にした比較用ビルドとの差分にも左右差があり、FMの成分にもステレオ効果がかかることを確認した。

QuickNESはNES本体の2つのパルス音を左右に配分する。VRC7の6音は中央にミックスされ、左右で異なるエコーが加わる。FMの各音を個別の左右位置へ振り分ける実装ではない。[QuickNESのエフェクト実装](https://github.com/libretro/QuickNES_Core/blob/058d66516ed3f1260b69e5b71cd454eb7e9234a3/nes_emu/Effects_Buffer.cpp)

RG353Mの既存ALSA出力へ同じPCMの一部を流し、RK817への書き込み直前で左右を別々に取得した。PCMは2チャンネルのままRUNNINGとなり、入力と同じチャンネルの相関は左右とも0.99998以上だった。試験ではLibretroの呼び出し側からコアオプションを指定し、出力経路の検証には本体の音量設定を使用した。USB DACやアナログ出力の実聴は今回の試験項目に含めていない。

## 戦闘中の文字タイル

RG353MのDRMのゲーム画面を読み取り、戦闘のコマンドや名前に敵の画像の一部が混ざることを確認した。QuickNESはCHRを読み出す際にマッパーが選んだバンクを参照するが、PPUの `$2007` からCHR RAMに書く際には論理アドレスをそのまま使っていた。そのためVRC7がバンクを切り替えた後、敵のタイルが文字の領域を上書きしていた。書き込み先と描画キャッシュの無効化先を、同じ物理CHRタイルにそろえた。[VRC7のCHRバンク仕様](https://www.nesdev.org/wiki/VRC7)

- 作成した検証カートリッジで、キャッシュ済みのタイルをバンク切替後に更新した。修正前はPPU経由の読み戻しが `00` で表示も変わらず、修正後は書いた値 `ff` が戻り、更新後のタイルが描画された。
- 実機からコピーした戦闘中のステートをDockerで読み、逃走から次の戦闘まで同じ入力を再生した。2通りの戦闘で、旧コアは敵の名前が欠け、修正コアは名前を描画した。同じ再生でVRC7を含むPCMのハッシュは一致した。最初の部屋で会話中に化けていた人物タイルも、修正後はFCEUmmの描画と一致した。
- 本番カタログのDockerビルドでQuickNESを再生成し、SYSTEM `c24d349d413cc8b24200e8acf0c5c3cffbe2caa5a27612b7ca6083de7adb204f` に収録した。ADBで試験起動し、Bubbleの通常の起動経路からRetroArchとQuickNESを開き、試験用ステートで「デニス」と戦闘コマンドが内蔵画面に表示されることをDRMキャプチャで確認した。内蔵スピーカーのPCMも進行した。Bubbleへの復帰を確認し、新しいSYSTEMを既定に設定した。
- 元のセーブステート3本とサムネイル3枚は、試験前後でSHA-256が一致した。旧コアで戦闘中に保存したステートには、化けたCHR RAMも含まれている。その場でロードした直後は同じ表示が残り、ゲームがタイルを書き直す次の戦闘で直る。
- USBでADBが `offline` の間、MacはRG353Mを列挙できるものの `CNXN` への応答がなかった。Mac側のADB再起動後も同じ状態で、ケーブルの抜き差しで復旧した。Wi-FiのFTPとSambaで共有領域を読めた。SSHは公開鍵認証で止まっていた。

## ヘッダー互換性とlibretroDBによる調査

- 指定の `rom2/nes` にあったNESイメージ120本（ZIP内の1本を含む）を同じ入力で各540フレーム実行した。従来のNES 2.0ヘッダー修正は『アルゴス』『ギミック！』『機動戦士Zガンダム ホットスクランブル』『燃えろ!!プロ野球』『プロ野球ファミリースタジアム』でも描画・起動を改善した。『ラグランジュポイント』2本を含め、基準ビルドから挙動が変わったのは7本だった。
- 『エキサイトバイク』は先頭にWUP形式の付加情報が付いていた。内包されたPRG・CHRのSHA-1はlibretroDBの `Excitebike (World) (Switch Online).unh` と一致した。QuickNESがWUPの識別子とサイズ・ROM範囲を検証して読み込むようにした。元ファイルと診断用のiNES化したコピーは、タイトルとコース選択を描画し、各540フレームの映像とPCMが一致した。WUPの識別子、範囲、末尾、内側の署名を壊した入力と、切り詰めたiNES入力は拒否した。[libretroDBのNES DAT](https://github.com/libretro/libretro-database/blob/f89f09cbe13f9f7863ecf20d0ebf2c5ce53be029/metadat/no-intro/Nintendo%20-%20Nintendo%20Entertainment%20System.dat) [Wii Uの包装形式を調べた記録](https://www.xavenna.net/writing/wiiu-nes.html)
- 公式互換性リストの『ファミリーサーキット ’91』を別コレクションで確認した。保有ROMの旧iNESヘッダーはマッパー19だった。保有データに検証用のNES 2.0ヘッダーを組み合わせ、libretroDBのマッパー210版とファイル全体のCRC32およびSHA-1が一致することを確認した。配布用コアにNamco 175／340のバンク切り替えとミラーリングを実装した。2 KiBのPRG RAMを8 KiBのCPU窓でミラーし、バンクと書き込み保護の状態をステートに保存する。検証用カートリッジでPRG・CHRの切り替え、PRG RAMのミラーと書き込み保護、画面のミラーリング、ステートの往復を確認した。[QuickNES公式互換性リスト](https://docs.libretro.com/library/compatibility/nes/#quicknes) [マッパー210の仕様](https://www.nesdev.org/wiki/INES_Mapper_210)
- libretroDBに記載のNES 2.0版とSHA-1が一致する9本で、修正前はすべて読み込み失敗し、修正後はすべて画面を描画した。対象は『ファミリーサーキット ’91』『ちびまる子ちゃん うきうきショッピング』『ファミスタ ’91』『ファミスタ ’92』『ファミスタ ’93』『ファミスタ ’94』『平成天才バカボン』『トップストライカー』『ワギャンランド2』。元のROMセットでは、新たに読めた『エキサイトバイク』と未対応で拒否された1本を除く118本で、既存コアと各540フレームの映像・PCMのSHA-256が一致した。
- 『Skull & Crossbones』のマッパー64と『SuborWin 2000』のマッパー178は未実装。ヘッダー検証を通過してからマッパー生成で止まる。公式リストの『Burai Fighter』と『Huge Insect』は起動画面まで描画した。公式リストにあるステージ進行時の症状は今回の比較範囲外。
- Dockerで作成したSYSTEMは `651a1267e2b3a067182adc94f020c30715a6dbfb758c3849edc7bacc6d64e481`。ADBで試験起動し、通常のRetroArch起動スクリプトで『ファミリーサーキット ’91』のモード選択と『エキサイトバイク』のコース選択を内蔵画面から取得した。両方でPCMの再生ポインターが進んだ。検証ではセーブ領域と設定を一時的に分け、Bubbleが復帰してからSYSTEMを既定に設定した。SDの更新領域を確保するため、Mac側に同一SHA-256のコピーがある選択外の旧試験SYSTEMを1本だけSDから取り除いた。

## 未検証タイトルに共通するNES 2.0対応

- NewRisingSunのNES 2.0 XMLデータベースの2026年9月26日版をlibretroDBとSHA-1で照合した。調査対象の既存マッパーには、4・8 KiBの小容量PRGを記録した23件と、従来の下位8ビットのサイズ欄では表せない4 MiB以上のPRGを記録した2件があった。『ギャラクシアン』のNamcot Collection／Namco Museum Archives版とEvercade版はいずれもマッパー0、PRG 8 KiB、CHR 8 KiBで、今回検証した日本版2本と同じ読み込み条件に該当する。この2版の判定はメタデータによる。[_NES 2.0 XML Database_](https://forums.nesdev.org/viewtopic.php?t=19940)・[使用したXMLの配布元](https://github.com/Eggmansworld/Eggmans_NRSVault_Mini/tree/main/files)・[libretroDBのNES DAT](https://github.com/libretro/libretro-database/blob/f89f09cbe13f9f7863ecf20d0ebf2c5ce53be029/metadat/no-intro/Nintendo%20-%20Nintendo%20Entertainment%20System.dat)
- PRG／CHR ROMサイズの上位ビットを読み、指数・倍率形式のサイズもデコードする。小容量PRGはCPUページ単位でミラーし、境界をまたいだオペランドの読み取りにも同じミラーを使う。ファイルの実寸、オーバーフロー、コアが表現できるバンク構成を確認してから読み込む。NROMではヘッダーに指定された2／4／8 KiBのPRG RAMをミラーする。マッパー2・3・7・11でNES 2.0のサブマッパー2が明示した場合は、書き込み値とROM値をANDするバス競合を再現する。既定値やサブマッパー1では従来の挙動を維持する。[NES 2.0仕様](https://www.nesdev.org/wiki/NES_2.0)・[NROMの構成](https://www.nesdev.org/wiki/NROM)・[サブマッパー仕様](https://www.nesdev.org/wiki/NES_2.0_submappers)
- テスト用ROMで4・8 KiBのPRGミラー、ミラーをまたぐ命令オペランド、サイズの上位ビット、トレーナーの分離、NROM RAMのミラー、4種のマッパーのバス競合を検証した。19機能ケースと4不正入力の拒否が通った。既存120本は各540フレームで読み込み結果、映像とPCMのSHA-256、セーブ領域サイズとステートサイズが一致した。NES 2.0版『ギャラクシアン』はlibretroDBのファイルSHA-1と一致する日本版2本で、旧コアが拒否し新コアがタイトルを描画した。Family BASICはRAMの挙動をテスト用ROMで確認した。『Huge Insect』の2,100フレーム比較では修正前後の出力が一致したため、同作の敵出現の問題は解消したと判定していない。
- Dockerで生成したSYSTEM `25037d604b605de72aa9296aecf1100eb5f82213350f4593afd4b41f8243a7eb` をADBで試験起動した。日本版『ギャラクシアン』を通常のRetroArch起動スクリプトから起動し、1人プレイの画面をDRMから取得した。内蔵スピーカー向けPCMポインターも進行した。Bubbleへの復帰を確認し、試験用データを取り除いて新SYSTEMを既定に設定した。SDの容量確保にはMacに同一SHA-256のコピーがある旧試験SYSTEMを1本取り除いた。
