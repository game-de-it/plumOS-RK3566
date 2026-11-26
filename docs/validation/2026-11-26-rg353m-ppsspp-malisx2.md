# RG353MのPPSSPP Vulkan試験

2026年11月26日（JST）。plumOS-RK3566 v0.1.0を対象に、PPSSPPだけがMaliSX2を読み込む試験構成を用意した。

## ビルド

| 項目 | 内容 |
| --- | --- |
| PPSSPP | 1.20.4、`fa50bb1976065c4f8b1b47af227d367fe9771555` |
| ビルド環境 | Docker ARM64、`plumos-rk3566-bubble-tools:ec81d42` |
| ビルド設定 | 既存のPPSSPPビルド設定とBubbleのSDL2_ttfパッチを使用し、`VULKAN=ON` と `USE_VULKAN_DISPLAY_KHR=ON` に設定。OpenGL ES対応もコンパイルした。 |
| 試験バイナリ | `PPSSPPSDL`、SHA-256 `63f3e77f98fcd4a4d31ed75b2bdace9b52353d01412d36a6e43cfea4172e6ad9` |
| MaliSX2 ICD | Linux ARM64版0.6.1、SHA-256 `61d1255e78f9e1937dec5d68791ae0caa2fee44a3c2dad1fe1018efbb80c6646`。[上流リリース](https://github.com/bmdhacks/malisx2/releases/tag/v0.6.1) |
| Vulkanローダー | Debian Bookworm ARM64の `libvulkan1` 1.3.239、`libvulkan.so.1` のSHA-256 `605f52f426f01a2c468ecd920b3de31452fde495f2c0d99602fffb93e782767c` |

コンテナ内で試験バイナリの `--version` が `v1.20.4` を返すことを確認した。先行調査ではRG353Mのカーネル `4.19.172` と `/dev/mali0` を使い、MaliSX2でVulkanインスタンスを作成してMali-G52（Vulkan 1.1.368）を認識した。

## 実機試験

SFTP転送の完了後に、ADBで試験版をRG353MのRAM上の `/run/plumos-ppsspp-malisx2/` に配置した。PPSSPPに限って `LD_LIBRARY_PATH` と `VK_DRIVER_FILES` を渡し、試験用INIの `GraphicsBackend` を `3 (VULKAN)` に設定した。CLIの `--graphics=vulkan` だけでは設定の読み込み後にOpenGL ESへ戻るため、その起動は計測から除外した。既定のPPSSPP、SYSTEM、カーネル、他のエミュレータには変更を加えていない。

『Ridge Racers 2（日本版）』のレース中に、ユーザーがOpenGL ES版でセーブステートを作成した。その同一ステートを両版で読み直し、描画解像度1×、VSync有効、フレームスキップ無効、計測中はコントローラー入力なしで比較した。起動から10秒後に、内蔵画面のCRTCに対する `drm_vblank_event_delivered` を約20秒間記録した。試験用の設定・セーブ先を使用し、CPUガバナーとCPUアフィニティは両版で変更しなかった。提示FPSは画面に送ったフレーム数から算出し、PPSSPP内のFPSカウンターもスクリーンショットで確認した。

| 項目 | 既存OpenGL ES | Vulkan ＋ MaliSX2 |
| --- | ---: | ---: |
| 計測時間 | 20.060秒 | 20.064秒 |
| 画面に提示されたフレーム | 660 | 1,204 |
| 平均提示FPS | 32.90 | 60.01 |
| 提示間隔の中央値 | 33.32 ms | 16.67 ms |
| 提示間隔の95パーセンタイル | 33.38 ms | 16.69 ms |
| 提示間隔の最大値 | 716.67 ms | 16.75 ms |
| 50 msを超えた提示間隔 | 11回 | 0回 |
| PPSSPPの画面表示（計測前・後の2点） | 39/60・38/60 | 60/60・60/60 |

Vulkan版をユーザーが操作した際も、描画と操作は正常だった。ユーザーの目視では既存OpenGL ES版が約36 fps、Vulkan版は60 fpsで安定した。Vulkan版のプレイ中に採取した別の20.050秒では提示FPSが60.00、提示間隔の最大値が16.75 msで、50 msを超えた間隔は0回だった。

MaliSX2は既存のkbase UK 11.29に接続した。セットアップ時にRockchip側が72バイトのジョブ記述子を拒否し、MaliSX2が64バイトを選択した。JITゾーンも使えなかったが、ゲーム進行中の描画やフレーム提示は継続した。Vulkanの内蔵画面出力はレース中のスキャンアウト画像と実際の操作で確認した。試験後はBubbleに復帰し、試験版は再起動までRAM上に残した。

今回の比較対象はRG353Mのこの1タイトル・1ステート。

## FEからの一時切り替え

RG353MのPSP一覧でゲームを選び、`SELECT` → `CORES` で左右を押すと、`SA: PPSSPP` と `SA: PPSSPP-MALISX2` を切り替えられる。`B` で一覧に戻り、`A` で起動する。『Ridge Racers 2』をFE経由で両方起動し、既存バイナリとOpenGL ES用ライブラリ、試験バイナリとMaliSX2をそれぞれ読み込んだことを実機で確認した。

両経路の試験設定は1×、VSync有効、手動・自動フレームスキップOFF、FPS・速度表示ON。CPUガバナーはFEのPSP設定を両方に使う。試験用セーブとセーブステートはRAM上で両経路が共有する。L3で保存し、FNのPPSSPPメニューから読み込める。FEの設定ファイル、起動スクリプト、コア選択を含む状態ディレクトリにRAMから一時的にバインドマウントした。再起動で一時経路、設定、試験用セーブは消える。

## 正式経路への切り替え

2026年11月27日（JST）。開発ビルドのPSP起動経路を `SA: PPSSPP-MALISX2` の1項目に変更した。既存の `standalone:ppsspp` の内部IDと保存先を維持するため、既存のゲーム別設定、履歴、セーブと互換性がある。Vulkanを初期化できない場合はログを出して終了する。フレームスキップは新規設定で手動・自動ともにOFF。既に保存されている個別の設定は引き継ぐ。

Dockerの正式ビルドではPPSSPPにVulkanと `VK_KHR_display` を有効にし、MaliSX2とVulkanローダーをPPSSPP専用ディレクトリへ収録する。公開済みv0.1.0のSYSTEMを基に、更新したPPSSPP、FEバイナリ、ランチャー、ドライバーを入れた開発用SYSTEM `69fcf802b91dd0852453fe725c2194b801b1c44348878e64a698054e7daff319` をDockerで組み立てた。196起動経路と9コンポーネントの検証を通過した。

一時FE経路の試験用セーブをMacへ退避し、RAM上のバインドマウントを解除してから、ADBでRG353Mの既存SDへSYSTEMを配置して試行起動した。Bubble、USB ADB、SD2、PSP一覧に表示された唯一のPPSSPP経路を確認した。FEから『Ridge Racers 2』を起動し、PPSSPPプロセスが同梱の `libvulkan_malisx2.so` を読み込んで内蔵画面にゲームを描画し、FNでメニューが開くことを確認した。このSYSTEMを既定に設定した。
