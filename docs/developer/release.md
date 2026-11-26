# Release verification

[日本語](release.ja.md) · [Guide index](README.md)

## Hardware checks

Record the source commit, version, artifact hashes and exact test hardware. Write the candidate to a fresh card and validate first-boot provisioning, cold boot, reboot, shutdown, SD2, representative emulators and app menus, audio, and sleep/resume. Check Wi-Fi and USB ADB where available, screen layout on each panel geometry, and rollback for any update package included with the release. Distinguish a successful launch from compatibility throughout an entire game.

## Release files

Keep the final artifact inventory and the source and license notices for shipped components. Inspect the staged artifacts for personal ROMs, BIOS files, saves, test scripts, Wi-Fi profiles, host keys and signing material. The runtime verifier checks route and component coverage; review redistribution terms and validate the final image separately. [Image validation commands](build.md#verify-and-package)

Review the [third-party license inventory](../../THIRD_PARTY_NOTICES.md) against the final image. Include the required notices and provide corresponding source for the binaries that require it.
