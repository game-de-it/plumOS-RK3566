# 対応機種

[English](devices.md) · [ガイドの目次](README.ja.md)

共通SDイメージは起動時に本体を判定します。RGB30のr1とr2にも同じイメージを使います。

| 機種 | 実機での確認範囲 |
| --- | --- |
| Anbernic RG353M | 起動、フロントエンド、SD2、Wi-Fi、USB ADB、代表的なエミュレータ・音声・スリープ |
| Anbernic RG353V | 起動、SD2、USB ADB、USB接続中の電源投入、代表的なエミュレータ・Apps・音声・スリープ |
| Anbernic RG353PS | 利用者から実機での動作報告あり。 |
| Anbernic RG503 | 起動、960×544表示、SD2、別ケーブルでのUSB ADB、代表的なエミュレータ・Apps・音声・スリープ |
| Powkiddy RGB30 r1 / r2 | 両方で起動、基板の自動判定、フロントエンド、ADB。SD2・エミュレータ・音声の詳しい試験はr2で実施。 |
| Powkiddy RK2023 | 起動、640×480表示、SD2、USB ADB、代表的なエミュレータ・Apps、スリープ、USB DACから内蔵スピーカーへの切り替え。試験機ではWi-Fiハードウェアが検出されていない。 |
| Powkiddy RGB10 Max 3 | 利用者から実機での動作報告あり。画面の向き、音声出力、シャットダウンの修正は先行版で確認済み。内蔵Wi-Fiの接続は実機確認待ち。 |

RG353PとRG353VSは実機起動の確認待ちです。RG353P用の機種定義はイメージに収録されています。[機種ごとの検証記録](../boot-and-device-support.md)
