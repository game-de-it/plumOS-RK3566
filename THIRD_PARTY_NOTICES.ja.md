# plumOS-RK3566の第三者ライセンス

[English](THIRD_PARTY_NOTICES.md)

plumOS-RK3566が独自に作成したソフトウェアと文書には[MITライセンス](LICENSE)を適用します。上流コードやそれを改変した部分には上流のライセンスと著作権表示を引き継ぎます。ファームウェア、バイナリ、フォント、画像などにも、それぞれの配布条件が適用されます。

エミュレータの一覧は、RG353Vで実機検証した `SYSTEM`（SHA-256 `4c3a44d5ba2e7cce6aa066ca93849d49479e393f20f30ccc617a899f64134bfd`）を基にしています。以下の `licenses/`、`components/`、`apps/`、`share/` は、そのSYSTEM内の `/usr/lib/plumos-353m/frontend` を基準としたパスです。

## ブートとハードウェア

| コンポーネント | ライセンスと根拠 |
| --- | --- |
| JELOS 20240206の起動スクリプトとinitramfs | JELOSのソフトウェアはGPLバージョン2、BusyBox 1.36.1はGPL-2.0-onlyです。JELOSの初期ブート処理を引き継いでいます。[ソースとビルド情報](docs/jelos-20240206-source.md) |
| Linux 4.19.172、DTB、RTL8821CSカーネルモジュール | カーネルはGPL-2.0-onlyです。一部のユーザー空間向けヘッダーにはLinux syscall例外があり、デバイスツリーのソースは各ファイルの表記に従います。Realtekの `8821cs.ko` ドライバーはGPLを宣言しています。[カーネルソース](https://github.com/JustEnoughLinuxOS/rk356x-kernel/tree/c741d56477939654bb4056be240f93d1ad1ae91e) |
| U-Boot | GPLバージョン2です。大半のファイルはそれ以降のバージョンも選択でき、一部には個別の例外があります。RGB30・RG353V向けの変更は同ソースへのパッチとして提供しています。[対象リビジョンのライセンス](https://github.com/JustEnoughLinuxOS/rk356x-uboot/blob/97c658238f7ccd436fbdede451bfd7488514a5c8/Licenses/README) |
| Rockchip rkbinのDDR、SPL、BL31 | 採用したリビジョンの[Rockchip Binary Software License Agreement](docs/licenses/rockchip-rkbin.txt)に従います。Rockchipプラットフォームや同梱文書に関する条件があります。[ファイル名とリビジョン](docs/jelos-20240206-source.md) |
| Arm Maliユーザー空間ドライバー | プロプライエタリ。JELOSのレシピではBifrost G52 g13p0を `libmali.so.1.9.0` として収録しています。実際に配布するバイナリに適用される契約を確認します。[JELOS収録のMali契約文](docs/licenses/jelos-mali-eula.txt) |
| Realtek RTL8821CSのBluetoothファームウェアと設定 | JELOSのレシピでは `rtl8821c_fw` と `rtl8821c_config` をApache-2.0と表記しています。同梱の2ファイルはレシピの入力ファイルとSHA-256が一致しました。公開前に上流の著作権表示とライセンス全文を確認します。[JELOSのレシピ](https://github.com/JustEnoughLinuxOS/distribution/blob/f8cac7b92040d734506e238f5a44560a4f0e81b0/packages/kernel/linux-firmware/RTL8821CS-firmware/package.mk) |
| JELOSのブランド素材とplumOSの起動画像 | 残っているJELOSのブランド素材・画像はCC BY-NC-SA 4.0です。圧縮されたリソースも含め、公開イメージ内のファイルを確認します。plumOS-mini-PLUSから取り込む起動画像は、画像自体の出典を確認します。[JELOSのライセンス](https://github.com/JustEnoughLinuxOS/distribution/blob/f8cac7b92040d734506e238f5a44560a4f0e81b0/LICENSE.md) · [起動画像の生成手順](prototype/build-boot-splash.sh) |

## FE、エミュレータ、Apps

| コンポーネント | ライセンスと根拠 |
| --- | --- |
| plumOS-BubbleのFE、ランチャー、独自ツール | Bubble独自コードはMITです。FEに同梱した `LICENSE` に従います。Bubbleが取り込んだ第三者素材にも固有の条件があります。[Bubbleの第三者ライセンス](https://github.com/game-de-it/plumOS-Bubble/blob/main/THIRD_PARTY_NOTICES.md) |
| RetroArchとアセット | RetroArchはGPL-3.0-or-laterです。アセットにはCC BY 4.0の素材が含まれ、個別のフォントや画像にはそれぞれの表記が適用されます。同梱の `licenses/RetroArch-COPYING`、`licenses/RetroArch-Assets-COPYING`、`licenses/RetroArch-Assets-README.md` を参照してください。 |
| RetroArch・PicoArchのコア | [コア一覧](docs/licenses/libretro-cores.tsv)に136プロファイル分のライセンス表記、同梱文書パス、ソースとリビジョンを掲載しています。Snes9x系、FinalBurn系、Genesis Plus GXなどには非商用条件や独自条件があります。各ライセンス本文で対象範囲と条件を確認してください。 |
| PicoArch | 本体の独自コードはBSD-3-Clauseです。libpicofeにはGPL・LGPL・MAMEの選択肢があり、一部のフィルターはMITです。同梱の `licenses/picoarch-LICENSE` を参照してください。 |
| PCSX-ReARMed・Yaba Sanshiro単体版 | GNU GPLバージョン2の本文を同梱しています。バージョンの選択条件と依存コードはソースの各表記に従います。同梱の `licenses/pcsx-rearmed-standalone-COPYING` と `licenses/yabasanshiro-LICENSE` を参照してください。 |
| PPSSPP単体版 | GPL-2.0-or-laterです。PSPSDKなどに個別の著作権・ライセンス表示があり、`licenses/ppsspp-LICENSE.txt` に収録されています。[上流](https://github.com/hrydgard/ppsspp) |
| OpenBOR単体版 | エンジンはBSD-3-Clauseです。ゲームパックには個別の条件があります。同梱の `licenses/openbor-LICENSE` を参照してください。 |
| DraStic | `steward-fu/nds` の統合コードはLGPL-2.1-onlyです。DraSticの実行ファイルはプロプライエタリで、統合コードのライセンス表記と上流のリリースREADMEだけでは公開再配布の権限を確認できていません。同梱の `licenses/steward-fu-nds-LGPL-2.1` と `licenses/drastic-upstream-NOTICE.txt` を参照してください。 |
| Pyxel、Python、pygame、NumPy、Pillow | PyxelはMIT、CPythonはPSFライセンスと旧版由来の条件、pygameはLGPL-2.1、NumPyはBSD-3-Clause、PillowはHPNDです。同梱ライブラリや素材の表記も含め、`apps/pyxel/site/` 以下の `*.dist-info` 内の文書とCPythonのライセンス文書を保持します。 |
| FreeJ2ME-PlusとJava | FreeJ2MEのコードはGPL-3.0です。ObjectWeb ASMなどには個別の条件があります。OpenJDKはGPL-2.0とClasspath例外を適用し、モジュール別文書を `share/libretro-system/freej2me-plus/freej2me_plus_runtime/linux-arm64/legal/` に収録しています。同梱の `licenses/freej2me_plus-LICENSE` も参照してください。 |
| PortMaster | 採用したGUIはMITです。補助ツール、フォント、ライブラリ、取得した各ポートには個別の条件があります。`apps/portmaster/upstream/PortMaster/licenses/` を参照してください。[採用したGUIのライセンス](https://github.com/PortsMaster/PortMaster-GUI/blob/2026.06.23-0015/LICENSE) |
| NextCommander | [採用したリビジョン](https://github.com/LoveRetro/NextCommander/tree/49c24bb67c12aea8078f48c833815f9ef2dcc5e2)のルートに独立したライセンス文書がなく、本体の条件を確認します。Source Code ProはSIL OFL 1.1です。その他の同梱フォントは個別に確認します。 |
| Music Playerと音声ルーティング | plumOS独自コードはMITです。miniaudioはパブリックドメインまたはMIT-0を選択できます。ALSAなどの依存関係には個別の条件があります。`licenses/plumos-audio-router-MIT.txt` と `components/music-player/manifest.json` を参照してください。[miniaudio](https://github.com/mackron/miniaudio) |

## システムツールとライブラリ

| コンポーネント | ライセンスと根拠 |
| --- | --- |
| BusyBox、Bash、GNU coreutils | BusyBoxはGPL-2.0-only、BashとGNU coreutilsはGPL-3.0-or-laterです。Debianパッケージの文書と、ネットワークツールに同梱したBusyBoxの文書を保持します。 |
| Debianのutil-linux/fdisk、e2fsprogs、dosfstools、kmod | util-linux/fdiskとe2fsprogsにはGPL、LGPLなどのファイル別条件があります。dosfstoolsはGPL-3.0-or-later、kmodはGPLとLGPLです。各パッケージの著作権文書を参照してください。 |
| Dropbear、OpenSSH SFTP、OpenSSL、Samba | DropbearはMIT系の条件と依存コードの個別表記、OpenSSHはBSD・ISC系などの個別表記に従います。OpenSSL 3はApache-2.0、SambaはGPL-3.0-or-laterで、個別ライセンスのライブラリも含みます。 |
| wpa_supplicant、ALSAツール、Info-ZIP UnZip | wpa_supplicantとwpa_cliはBSD-3-Clause、ALSAツールはGPLとパッケージ内の個別条件、UnZipはInfo-ZIPライセンスです。 |
| 共有ライブラリ、CA証明書、タイムゾーンデータ | 各共有ライブラリ、Sambaモジュール、ALSAデータ、`ca-certificates`、`tzdata` は、採用したDebianパッケージの文書を参照してください。例としてglibc・ALSAの共有ライブラリはLGPL、SDL2はzlib、GCCランタイムは該当部分にランタイム例外が適用されます。 |
| Standalone Linux adbd | 採用した `v36.0.1-linux.2` のソースは[Apache-2.0](docs/licenses/standalone-linux-adbd-Apache-2.0.txt)です。静的実行ファイルに組み込まれた依存関係にも個別の条件があるため、ビルドで使用した各ソースの表記を保持します。[対象ソースとビルド情報](https://github.com/happyme531/standalone-linux-adbd/tree/v36.0.1-linux.2) |

[Debianパッケージ一覧](docs/licenses/debian-runtime.tsv)には、検証済みSYSTEMとDockerランタイムで少なくとも1ファイルがバイト単位で一致した164パッケージを掲載しています。バイナリとソースのバージョン、およびDebianの著作権文書の表記を記録しています。CA証明書バンドルのような生成物と、別のレイヤーでビルドしたファイルは個別に出典を確認します。

リリースごとにDebian由来の実行ファイルと共有ライブラリをDockerのビルド環境で確認し、ソースパッケージ名とバージョンに対応付けます。該当する `/usr/share/doc/<package>/copyright` と、そこから参照されるライセンス本文を保持してください。[Dockerランタイムの構築手順](prototype/build-runtime-system.sh) · [Debianの著作権文書規定](https://www.debian.org/doc/debian-policy/ch-docs.html#copyright-information)

公開前に、最終SDイメージとSYSTEMの内容をこの一覧と照合します。フォント、画像、静的リンクされた依存関係も対象です。各ライセンスが求める文書、対応ソース、ビルドスクリプト、パッチを揃え、条件が未確認の素材やバイナリは公開物に含める前に許諾を確認します。[リリース時の確認項目](docs/developer/release.ja.md)
