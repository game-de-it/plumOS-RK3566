# RGB30r2のRetroArchアスペクト比

RGB30で起動中のGB版『Aretha』はGambatteを使用していた。起動用の追加設定にアスペクト比の指定がなく、共通の `retroarch-bubble.cfg` に `aspect_ratio_index = "23"` と640×480のCustomビューポートが残っていた。旧Game Gearランチャーの `sega43` の設定と一致し、そのランチャーの実行履歴も残っていた。RetroArchは追加設定を読み込んだ後の値を終了時に共通cfgへ保存できるため、後続のGBを含む他のコアも同じ値を読み込んだ。[RetroArch v1.22.2の設定保存処理](https://github.com/libretro/RetroArch/blob/v1.22.2/configuration.c#L5104) [アスペクト比の定義](https://github.com/libretro/RetroArch/blob/v1.22.2/gfx/video_defines.h#L34-L61)

RK3566のRetroArch共通既定値は `22` のCore Provided。FEに登録された116種類のRetroArchコア指定は共通ランチャーを通る。通常起動でアスペクトを上書きする分岐はなく、ユーザーが保存したコア別・コンテンツ別の上書きはRetroArchが読み込む。Game Gearで明示的に `sega43` または `integer3x` を選んだ場合だけ、一時cfgにCustomを適用する。相対パスとincludeの解決先を保つため、そのcfgは共通cfgと同じディレクトリーに作り、終了時に削除する。

既存SDでは、旧ランチャーのCustom、サイズ、原点、整数拡大とシェーダーの組み合わせに一致したときに、一度だけ共通cfgを移行する。元のcfgは `state/retroarch/pre-rk3566-core-aspect.cfg` に保存する。初期cfg、旧来の640×480と480×432、利用者が変えたCustom幅、4:3指定、シェーダーを無効にしたCustomの6種類で移行を試し、利用者の個別上書きと移行後の設定変更が維持されることを確認した。

SYSTEM `88d730c7103a88ad1f58b643164a3862774e9428e107490996146706dfccd86f` をDockerでビルドし、RGB30r2の既存SDへ差分適用した。同じ『Aretha』をFEから開き直すと、移行前のcfgとの差分はアスペクト比の1項目だけだった。DRMで160×144の入力に対して、修正前の640×480から、コアの10:9に沿った720×648へ変わったことを確認した。通常終了で共通cfgが保存された後も、Core Providedの `22` が入っていた。

分離した設定でGBのGearboy、GBCのGambatte、GBAのmGBA、NESのQuickNES、Game GearのGenesis Plus GXも起動した。全5ケースで通常終了し、共通cfgは `22` のままだった。Game Gearの両特殊表示も通常終了し、RetroArchの保存先はそれぞれ専用の一時cfgになった。一時cfgが片付けられ、共通cfgにCustomが残らないことを確認した。

試験後に修正版のSYSTEMを既定に設定した。更新前後のカーネル、RGB30用DTB、extlinux設定のSHA-256とパーティション一覧は一致し、SD2と利用者用領域はマウントされた。実機検証はRGB30r2で実施した。
