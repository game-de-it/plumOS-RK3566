#!/bin/bash
set -euo pipefail

if [ "$#" -ne 4 ]; then
    echo "Usage: $0 BUBBLE_GIT V90S_GIT JELOS_SYSTEM NEW_BUILD_DIRECTORY" >&2
    exit 2
fi
prototype=$(cd "$(dirname "$0")" && pwd)
bubble_git=$(cd "$1" && pwd)
v90s_git=$(cd "$2" && pwd)
stock=$(cd "$(dirname "$3")" && pwd)/$(basename "$3")
mkdir "$4"
work=$(cd "$4" && pwd)

"$prototype/emulators/prepare-bubble-source.sh" "$bubble_git" "$work/bubble"
mkdir "$work/v90s"
v90s_revision=bc49dafe782173f35ab557035fa96ba81564038d
git -C "$v90s_git" archive "$v90s_revision" docker | tar -xf - -C "$work/v90s"

cd "$work/bubble"
export SOURCE_DATE_EPOCH
SOURCE_DATE_EPOCH=$(cat source-date-epoch)
export PLUMOS_BUBBLE_TOOLS_IMAGE=plumos-rk3566-bubble-tools:ec81d42
export PLUMOS_BUBBLE_DOCKER_IMAGE=plumos-rk3566-bubble-core-tools:ec81d42
export PLUMOS_BUBBLE_PICOARCH_TOOLS_IMAGE=plumos-rk3566-picoarch-tools:bc49dafe
if ! docker image inspect "$PLUMOS_BUBBLE_PICOARCH_TOOLS_IMAGE" >/dev/null 2>&1; then
    docker build --platform linux/arm64 -t "$PLUMOS_BUBBLE_PICOARCH_TOOLS_IMAGE" \
        -f "$work/v90s/docker/plumos-v90s-toolchain/Dockerfile" "$work/v90s"
fi
./scripts/build-bubble-retroarch.sh
./scripts/build-libretro-core-catalog-bubble.sh --filter "${PLUMOS_BUBBLE_CATALOG_FILTER:-all}"
./scripts/build-picoarch-bubble.sh
docker run --rm --platform linux/arm64 -e SOURCE_DATE_EPOCH \
    -v "$work/bubble:/work" -w /work "$PLUMOS_BUBBLE_TOOLS_IMAGE" \
    ./scripts/build-pyxel-bubble.sh --inside --sdl-only
"$prototype/emulators/stage-jelos-gpu.sh" "$stock" "$work/bubble/build/rg353m-jelos-gpu"
PLUMOS_BUBBLE_INCLUDE_CAPTURED_VENDOR_GPU=1 ./scripts/build-standalone-bubble.sh
"$prototype/emulators/assemble-runtime.sh" "$work/bubble" "$work/runtime"
