#!/bin/bash
set -euo pipefail

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 NEW_PAYLOAD_DIRECTORY" >&2
    exit 2
fi

source=$(cd "$(dirname "$0")" && pwd)
parent=$(cd "$(dirname "$1")" && pwd)
destination="$parent/$(basename "$1")"
test ! -e "$destination"
stage=$(mktemp -d "$parent/.native-init.XXXXXX")
trap 'rm -rf "$stage"' EXIT

cp "$source"/{boot-system,entry,init,install-native,manage-sd2,mount-storage.sh,select-init.sh} "$stage/"
cp "$source/../seed/start-storage" "$stage/"
for script in "$stage"/*; do sh -n "$script"; done

docker run --rm --platform linux/arm64 \
    -v "$source/power.c:/src/power.c:ro" -v "$stage:/out" \
    plumos-rk3566-bubble-tools:ec81d42 cc -static -O2 -Wall -Wextra -o /out/power /src/power.c
(
    cd "$stage"
    shasum -a 256 boot-system entry init install-native manage-sd2 mount-storage.sh power select-init.sh start-storage > SHA256SUMS
)
mkdir "$destination"
mv "$stage"/* "$destination/"
