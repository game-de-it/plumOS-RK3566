# RG353Mの音量ボタン曲線

2026-11-23（JST）。小音量でのボタン1回の変化が大きいため、0〜20の保存値は維持しつつ、ALSA Soft Volume Masterの割り当てを変更した。レベル0は従来どおりraw 0、レベル1はraw 181、レベル20はraw 255。レベル1〜20の差分は`1,1,2,2,2,2,3,3,3,4,4,4,5,5,5,6,7,7,8`で単調に増える。softvolの範囲は-90〜0 dBなので、レベル1→2は約0.35 dB、19→20は約2.82 dBになる。曲線は`prototype/emulators/set-volume-curve.py`で固定し、ランタイム組み立てとSYSTEMビルドの両方に適用する。

実機の`plumos-volume-control`をバックアップ後に差し替えた。USB DAC接続中、PCMが停止している状態でレベル1、2、4、10を適用し、ミキサーの読み戻しがそれぞれraw 181、182、185、200だった。ボタン監視が呼ぶ`runtime-up`、`runtime-down`でも181→182→181を確認した。試験後のランタイム値と保存値はどちらも元の1に戻した。監視プロセス`plumos-volume-keys --volume-only`は稼働中。旧スクリプトは本体の`/storage/plumos-rk3566/frontend/backups/volume-control-before-progressive-curve`に保存した。

Dockerの`build-bubble-system.sh`を固定Bubbleリビジョン`ec81d42`と既存のエミュレータランタイムで実行した。196のFEプロファイル、可視Apps、9コンポーネントの検査を通過した。生成した`SYSTEM`から取り出したスクリプトと実機のスクリプトはSHA-256 `51a45edccab6f478da51785d889289816c0115273bedd92e1b858e7942994382`で一致した。生成した`SYSTEM`のSHA-256は`3bda1e507d1adf1e22464c848f42715ffd6d1e37d4176d2617c7199e04d7789c`。既存SDは実機のoverlayだけを更新したため、SDの焼き直しは不要だった。

音の印象は再生内容と出力機器に依存するため、上記はミキサー値とボタン操作経路の検証結果である。
