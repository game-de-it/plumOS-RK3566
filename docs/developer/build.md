# Build the common SD image

[日本語](build.ja.md) · [Developer guide](README.md)

Run commands from the repository root. The host needs Bash, Git, Python 3, `shasum`, Docker with `linux/arm64` containers, and space for the build trees and both image files. The image build and verifier use a privileged container with loop devices. They take image files as inputs.

## Inputs

| Variable | Input |
| --- | --- |
| `BUBBLE_GIT` | Local Git repository containing plumOS Bubble commit `ec81d42c0c2c39e7a32973bfe4df9b3027512a5d` |
| `V90S_GIT` | Local Git repository containing the V90S toolchain commit `bc49dafe782173f35ab557035fa96ba81564038d` |
| `JELOS_IMG` | Verified, unpacked JELOS 20240206 rebuild. The image builder checks for raw SHA-256 `281bf1c1faf7f4c9d044f59677075fbb9af99d2a8d01f873c23c13587668c73f`. |
| `JELOS_SYSTEM` | Kernel-support SYSTEM extracted from the matching input. The SYSTEM builder checks for SHA-256 `b0028dc48926ad49ab2d0156fec2c64f16f406e2f463ded4cc84eb8dcaac4a83`. This supplies matching hardware files. |
| `STATIC_ADBD` | Executable static ARM64 `adbd` binary |
| `JELOS_UBOOT` | Local JELOS U-Boot Git repository containing commit `97c658238f7ccd436fbdede451bfd7488514a5c8` |
| `BL31` | `rk3568_bl31_v1.42.elf` from the matching Rockchip rkbin input |
| `BOOT_SPLASH_DIR` | Directory with `boot-splash.xrgb`, `provision-start.xrgb`, and `provision-error.xrgb`. Use the prepared assets or the macOS ARM64 splash helper. |
| `RELEASE_VERSION` | Version chosen for the candidate, passed through `PLUMOS_RUNTIME_VERSION` |

Use absolute paths for the inputs. The pinned source and reference-image comparisons are recorded separately. The splash helper takes a work directory with the pinned assets under `refs/mini-PLUS` and `refs/Bubble`, and the host Zig binary under `tools/`; it writes the frames under `compiled/boot-splash/`. [JELOS provenance](../jelos-20240206-source.md) · [ADB input provenance](../../prototype/README.md#ビルド入力) · [Splash helper](../../prototype/build-boot-splash.sh)

## Build

With the input variables above set, use a fresh work directory. The full emulator build uses the default catalog filter. Leave `PLUMOS_BUBBLE_CATALOG_FILTER` unset for a release candidate.

```sh
set -eu
work="$PWD/output/release-work"
mkdir -p "$work"

./prototype/build-emulators.sh "$BUBBLE_GIT" "$V90S_GIT" \
  "$JELOS_SYSTEM" "$work/emulators"

PLUMOS_RUNTIME_VERSION="$RELEASE_VERSION" \
  ./prototype/build-bubble-system.sh "$JELOS_SYSTEM" "$BUBBLE_GIT" \
  "$STATIC_ADBD" "$work/system" "$work/emulators/runtime"

./prototype/build-rk3566-uboot.sh "$JELOS_UBOOT" "$BL31" "$work/u-boot.itb"

./prototype/build-bubble-sd.sh "$JELOS_IMG" "$work/system/SYSTEM" \
  "$BOOT_SPLASH_DIR" "$work/plumOS-RK3566.img" "$work/u-boot.itb"
```

The SYSTEM step produces `SYSTEM`, `bubble-userland.squashfs`, `SHA256SUMS`, and `build-runtime-update.py`. The automatic board-selection image uses the generated U-Boot FIT as the fifth argument. The image step produces the raw `.img`, `.img.gz`, and `.img.sha256` files.

## Verify and package

```sh
./prototype/verify-bubble-sd.sh "$work/plumOS-RK3566.img"
(cd "$work/system" && shasum -a 256 -c SHA256SUMS)
(cd "$work" && shasum -a 256 -c plumOS-RK3566.img.sha256)
```

The SYSTEM builder checks that the frontend catalog, launchers, app dependencies, and component checksums agree. The raw-image verifier checks the image layout, first-boot provisioning, retention of existing user data, and trial SYSTEM recovery in a container. Keep the image hash with the physical-device results. [Release verification](release.md)

For a raw-image release, package the verified `.img.gz` and its matching checksum file. Retain the source commit, tool and input versions, and hashes of both the compressed and raw artifacts for support.

## Runtime update packages

New builds embed `prototype/update/rk3566-update-public.pem`. Before signing a release, derive the public key from the RK3566 signing key and confirm that it matches the embedded key. Keep the private key in protected storage outside Git and the build artifacts. See the [user update guide](../user/updates.md) for migration from v0.1.1.

The generated `build-runtime-update.py` packages the unpacked frontend runtime. Use `--base-dir` and `--base-version` for a version-specific delta and `--signing-key` with the key matching the public key included in the installed runtime. The package uses device ID `rg353m` and vendor runtime `rk3566-plumos-r1` for compatibility across the common builds. Check the current options with `build-runtime-update.py --help`. Test the signature, version checks, apply and rollback on a spare card before shipping an update. Runtime packages update frontend files; new boot assets or operating-system files require a new image or SYSTEM as appropriate. [Runtime update design](../rk3566-runtime.md)
