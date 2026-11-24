# RGB30r2のUSB DACとLast Emulator

SYSTEM `88d730c7103a88ad1f58b643164a3862774e9428e107490996146706dfccd86f` のRGB30r2で、利用者がRA、PicoArch、単体エミュレータを選んでプレイし、USB DACから音が出ることを聴感で確認した。プレイしたままのUSB DACの抜き差しと、スリープから復帰した後のUSB DAC出力も正常だった。試したタイトル名は記録されていない。同じ実機で、前回修正したRetroArchのアスペクト比が正しく表示されることも利用者が確認した。

## Last Emulatorの音声経路

起動中の `LastEmulator.pyxapp` を確認した。ゲームの `engine/audio.py` は先に `pygame.mixer` を44.1 kHz、16ビット、2チャンネルで開く。実行ログでは `pygame.mixer.init()` が `libgthread-2.0.so.0` の読み込みエラーで失敗した。実行中のプロセスには `pygame.mixer` とSDL2_mixerがロードされておらず、ゲームの候補選択はPyxel PCMに進む。同じエラーは内蔵スピーカーを使った以前の起動ログにもあった。

同梱のPyxel 2.9.3で、44.1 kHzの試験WAVを `Sound.pcm()` で読み込み、`Sound.save()` で書き出すと、出力WAVは22,050 Hzだった。実際のゲームプロセスはplumOSのALSAルーターを経由して、CX31993のUSB DACに44,100 Hz、16ビット、2チャンネルで出力していた。PCMは `RUNNING` で、ハードウェアポインターも進行していた。ゲーム内で使われたPCMのレートと、DACとの接続レートは別々に確認した。

本体でゲームとは別にPythonを実行し、SDLのダミー出力で `pygame.mixer` の初期化を比較した。出荷時の探索パスでは `libgthread-2.0.so.0` が見つからず、それだけを追加すると `librt.so.1` が見つからなかった。SYSTEMに同梱されている両ライブラリーを試験プロセスだけの探索パスへ追加すると、`pygame.mixer.get_init()` は `(44100, -16, 2)` を返した。この試験はライブラリーのロードとミキサー初期化を対象とした。ゲームを起動し直さず、SYSTEMと利用者の設定を維持した。
