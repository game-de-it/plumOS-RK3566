#!/bin/bash
set -euo pipefail

if [ "$#" -ne 5 ]; then
    echo "Usage: $0 BUBBLE_GIT REVISION DOCKER_IMAGE NEW_BUILD_DIRECTORY SYSTEM_FRONTEND" >&2
    exit 2
fi
bubble=$1
revision=$2
image=$3
work=$4
target=$5
mkdir "$work"
git -C "$bubble" archive "$revision" scripts docker/bubble-tools src \
    package/frontend-bubble LICENSE | tar -xf - -C "$work"
prototype=$(cd "$(dirname "$0")" && pwd)
patch -d "$work" -p1 < "$prototype/patches/rk3566-ggfe-panel-fit.patch"
export SOURCE_DATE_EPOCH
SOURCE_DATE_EPOCH=$(git -C "$bubble" show -s --format=%ct "$revision")
export PLUMOS_BUBBLE_APPS_IMAGE=$image PLUMOS_BUBBLE_TOOLS_IMAGE=$image

python3 - "$work/scripts" <<'PY'
from pathlib import Path
import sys

scripts = Path(sys.argv[1])
path = scripts / "build-nextcommander-bubble.sh"
text = path.read_text()
anchor = 'make -C "$build_root/source"'
assert text.count(anchor) == 1
text = text.replace(anchor, '''sed -i 's@$(NEXTUI_SYSTEM_PATH)/res/font1.ttf@font1.ttf@' "$build_root/source/Makefile"
''' + anchor)
path.write_text(text)

path = scripts / "build-music-player-bubble.sh"
text = path.read_text()
anchor = 'gcc -std=c11'
assert text.count(anchor) == 1
text = text.replace(anchor, r'''sed -i 's/getenv("PLUMOS_ROOT")/getenv("PLUMOS_SDCARD_ROOT")/;
    /const char \*relative_roots\[\] = {/a\      "Music",' "$build_root/apps/plumos_music_player.c"

''' + anchor)
old = '${ALSA_CONFIG_PATH:-/run/plumos/audio/asound.conf}'
new = '${ALSA_CONFIG_PATH:-${PLUMOS_RUNTIME_ROOT:-/run/plumos}/audio/asound.conf}'
assert text.count(old) == 1
path.write_text(text.replace(old, new))
PY

"$work/scripts/build-nextcommander-bubble.sh"
"$work/scripts/build-music-player-bubble.sh"
"$work/scripts/build-bubble-frontend.sh"
for component in nextcommander music-player; do
    cp -R "$work/output/$component/bubble/plumos/." "$target/"
done

frontend=$work/output/frontend/bubble/plumos
for tool in curl plumos-ggfe plumos-ggfe-launch plumos-thumbnail-scraper \
    plumos-sd2-repair plumos-fsck-fat plumos-drm-master plumos-drm-broker-run; do
    install -m 755 "$frontend/bin/$tool" "$target/bin/"
done
mkdir -p "$target/frontend/lib"
install -m 755 "$frontend/frontend/lib/libplumos-drm-share.so" \
    "$target/frontend/lib/"
cp -R "$frontend/"{scraper,storage-tools} "$target/"
mkdir -p "$target/apps/ggfe" "$target/share/doc"
cp -R "$frontend/frontend/lib" "$target/apps/ggfe/"
cp -R "$frontend/share/doc/"{frontend,storage-tools} "$target/share/doc/"
python3 - "$target" <<'PY'
from pathlib import Path
import sys

root = Path(sys.argv[1])
for name, original, replacement in (
    ('plumos-ggfe-launch', '$PLUMOS_ROOT/frontend/lib', '$PLUMOS_ROOT/apps/ggfe/lib'),
    ('plumos-sd2-repair', '$PLUMOS_ROOT/bin/plumos-bubble-mount-sd2',
     '/usr/lib/plumos-353m/manage-sd2'),
):
    path = root / 'bin' / name
    text = path.read_text()
    assert text.count(original) == 1
    path.write_text(text.replace(original, replacement))

gamegear = root / 'bin/plumos-ggfe-launch'
text = gamegear.read_text()
cpu_check = 'if [ -x "$CPU_CONTROL" ] &&'
assert text.count(cpu_check) == 1
gamegear.write_text(text.replace(cpu_check, '''if [ ! -d "${PLUMOS_CPUFREQ_ROOT:-/sys/devices/system/cpu/cpufreq}/policy0" ]; then
    printf '%s\\n' 'Game Gear: CPU policy unavailable; keeping current clock' >&2
elif [ -x "$CPU_CONTROL" ] &&'''))

scraper = root / 'bin/plumos-thumbnail-scraper'
text = scraper.read_text()
required = '[ -z "$worker_dat_index" ] || [ -z "$worker_thumb_index" ] || [ -z "$worker_thumb_base" ]'
assert text.count(required) == 1
text = text.replace(required, '[ -z "$worker_dat_index" ] || [ -z "$worker_thumb_base" ]')
anchor = '''      href="$(lookup_thumb_href "$worker_thumb_index" "$canonical" || true)"'''
assert text.count(anchor) == 1
text = text.replace(anchor, anchor + '''
      if [ -z "$href" ] && ! thumb_index_valid "$worker_thumb_index"; then
        # When the index endpoint is unavailable, use the canonical DAT title.
        # fetch_thumbnail_png still verifies the response as a PNG.
        href="$(PLUMOS_ROOT="$PLUMOS_ROOT" "$PLUMOS_ROOT/bin/plumos-python-bubble" -c 'from sys import argv; from urllib.parse import quote; print(quote(argv[1] + ".png", safe=""))' "$canonical" || true)"
      fi''')
scraper.write_text(text)
PY
