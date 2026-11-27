# 対応機種

[English](devices.md) · [ガイドの目次](README.ja.md)

共通SDイメージは起動時に本体を判定します。RGB30のr1とr2にも同じイメージを使います。

| 機種 | 実機での確認範囲 |
| --- | --- |
| Anbernic RG353M | 起動、フロントエンド、SD2、Wi-Fi、USB ADB、代表的なエミュレータ・音声・スリープ |
| Anbernic RG353V | 起動、SD2、USB ADB、USB接続中の電源投入、代表的なエミュレータ・Apps・音声・スリープ |
| Anbernic RG503 | 起動、960×544表示、SD2、別ケーブルでのUSB ADB、代表的なエミュレータ・Apps・音声・スリープ |
| Powkiddy RGB30 r1 / r2 | 両方で起動、基板の自動判定、フロントエンド、ADB。SD2・エミュレータ・音声の詳しい試験はr2で実施。 |
| Powkiddy RK2023 | 起動、640×480表示、SD2、USB ADB、代表的なエミュレータ・Apps、スリープ、USB DACから内蔵スピーカーへの切り替え。試験機ではWi-Fiハードウェアが検出されていない。 |

RGB10 Max 3はv0.1.2の実機写真でBubbleの起動と表示方向の問題を確認しています。表示補正は実機での確認待ちです。RG353PとRG353VSの実機起動は未確認で、RG353P用の機種定義はイメージに収録されています。[機種ごとの検証記録](../boot-and-device-support.md)
