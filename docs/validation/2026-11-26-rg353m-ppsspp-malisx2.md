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
