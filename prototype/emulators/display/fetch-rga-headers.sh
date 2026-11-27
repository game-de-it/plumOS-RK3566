#!/bin/bash
set -euo pipefail

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 NEW_HEADER_DIRECTORY" >&2
    exit 2
fi
mkdir "$1"
archive=$(mktemp)
trap 'rm -f "$archive"' EXIT
revision=df26244eb0c3991df319d4276ab80e8c0bf91f64
curl --fail --location --retry 3 \
    "https://codeload.github.com/JustEnoughLinuxOS/linux-rga/tar.gz/$revision" \
    -o "$archive"
expected=f13e0e81af0cdb44447fa4cb13e2c2a248d2e0e4e1e409464fb6ed8f77c09359
actual=$(shasum -a 256 "$archive" | cut -d ' ' -f 1)
test "$actual" = "$expected"
prefix="linux-rga-$revision/include"
tar --strip-components=2 -xf "$archive" -C "$1" \
    "$prefix/RgaApi.h" "$prefix/drmrga.h" "$prefix/rga.h"
