# フロントエンドとエミュレータの変更

[English](frontend-emulators.md) · [ガイドの目次](README.ja.md)

- カタログやランチャーの変更は通常のビルド経路に入れ、フロントエンドから起動して確認します。フロントエンドとエミュレータのDRMの引き渡しを維持し、実行ファイル、マニフェスト、チェックサムをそろえます。[ランタイム検証スクリプト](../../prototype/emulators/verify-release-runtime.py)
- 共通のRetroArchパッチでは、ゲーム入力の抑制前にSELECT＋Bを判定し、内蔵のFNイベントも拾います。PicoArchと単体エミュレータは、RGB30とRK2023でSELECT＋STARTを使います。入力を変更したらRetroArchの両方の押し順と通常操作を確認します。[RetroArchのパッチ](../../prototype/emulators/retroarch-select-b-menu.patch) · [単体版のメニュー設定](../../prototype/emulators/configure-standalone-menu-chords.py)
