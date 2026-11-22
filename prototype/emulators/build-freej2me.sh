#!/bin/bash
set -euo pipefail

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 PREPARED_BUBBLE_SOURCE" >&2
    exit 2
fi
work=$(cd "$1" && pwd)
revision=52b25f75824d247c23e352625be45157bfe87620
base=plumos-rk3566-bubble-tools:ec81d42
image=plumos-rk3566-freej2me:openjdk17.0.21.1
if ! docker image inspect "$image" >/dev/null 2>&1; then
    docker build --platform linux/arm64 -t "$image" - <<DOCKER
FROM $base
RUN apt-get update && apt-get install -y --no-install-recommends \\
    ant=1.10.13-1 openjdk-17-jdk-headless=17.0.21.1+2-1~deb12u1 \\
    && rm -rf /var/lib/apt/lists/*
DOCKER
fi

docker run --rm -i --platform linux/arm64 \
    -v "$work:/work" "$image" bash -s -- "$revision" <<'BUILD'
set -euo pipefail
revision=$1
source=/work/build/freej2me-plus
destination=/work/output/freej2me-plus/bubble/plumos
test ! -e "$source"
test ! -e "$destination"
mkdir -p /work/build
git init -q "$source"
git -C "$source" fetch --depth 1 https://github.com/TASEmulators/freej2me-plus.git "$revision"
git -C "$source" checkout -q --detach FETCH_HEAD
test "$(git -C "$source" rev-parse HEAD)" = "$revision"
cd "$source"
make -C src/libretro -j4
ant -Dsource.version=8 -Dtarget.version=8 jar-libretro
component="$destination/components/freej2me-plus"
system="$destination/share/libretro-system/freej2me-plus"
java="$system/freej2me_plus_runtime/linux-arm64"
mkdir -p "$component" "$system" "$destination/cores" "$destination/info" "$destination/licenses"
jlink --add-modules java.base,java.desktop --compress=2 --no-header-files \
    --no-man-pages --strip-debug --output "$java"
install -m 644 build/freej2me_plus-lr.jar "$java/bin/"
install -m 755 src/libretro/freej2me_plus_libretro.so "$destination/cores/"
install -m 644 LICENSE "$destination/licenses/freej2me_plus-LICENSE"
cat >"$destination/info/freej2me_plus_libretro.info" <<'INFO'
display_name = "Mobile (FreeJ2ME-Plus)"
corename = "FreeJ2ME-Plus"
systemname = "Java ME"
supported_extensions = "jar|jad"
license = "GPLv3"
libretro_saves = "true"
savestate = "false"
INFO
printf '{"id":"freej2me_plus","binary":"freej2me_plus_libretro.so","rendering":"software","source_ref":"%s"}\n' "$revision" >"$component/manifest.json"
cd "$destination"
find cores info licenses share components/freej2me-plus -type f \
    ! -name checksums.sha256 -print0 | sort -z | xargs -0 sha256sum >"$component/checksums.sha256"
BUILD
