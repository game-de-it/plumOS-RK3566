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

SD2へのSFTP転送が完了するまで、試験版の配置と実機比較は保留。試験版はADBでRAM上に配置し、Vulkanを起動するプロセスにだけローダーとICDのパスを指定する。v0.1.0のOpenGL ES版と同じゲーム、場面、解像度を使用し、内蔵画面、ゲームのFPS、画面への提示間隔を記録する。
