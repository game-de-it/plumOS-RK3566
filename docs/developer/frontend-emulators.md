# Frontend and emulator changes

[日本語](frontend-emulators.ja.md) · [Guide index](README.md)

- Make catalog or launcher changes in the normal build pipeline and test launch through the frontend. Keep the frontend and emulator DRM lifetime coordinated. Firmware, launchers, component manifests and checksums should describe the same packaged files. [Runtime verifier](../../prototype/emulators/verify-release-runtime.py)
- The common RetroArch patch handles SELECT + B before the gameplay input mask and reads the built-in FN event separately. PicoArch and standalone emulators use SELECT + START on RGB30 and RK2023. Verify both RetroArch press orders and the usual controls after touching input handling. [RetroArch patch](../../prototype/emulators/retroarch-select-b-menu.patch) · [Standalone menu configuration](../../prototype/emulators/configure-standalone-menu-chords.py)
