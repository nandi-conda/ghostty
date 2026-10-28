#!/usr/bin/env bash
# Build the AppImage conda package and upload it to prefix.dev/nandi-testing.
#
# Requires:
#   - PREFIX_DEV_TOKEN, a prefix.dev API token with write access to the
#     nandi-testing channel
#   - exactly one Ghostty-*-x86_64.AppImage in dist/conda/appimage/
set -euo pipefail

if [ -z "${PREFIX_DEV_TOKEN:-}" ]; then
    echo "error: PREFIX_DEV_TOKEN is not set" >&2
    exit 2
fi

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

shopt -s nullglob
appimages=("$here"/appimage/Ghostty-*-x86_64.AppImage)
if [ "${#appimages[@]}" -ne 1 ]; then
    echo "error: expected one Ghostty-*-x86_64.AppImage in $here/appimage," \
        "found ${#appimages[@]}" >&2
    exit 2
fi

pixi auth login https://prefix.dev --token "$PREFIX_DEV_TOKEN"
pixi publish --path "$here" --to https://prefix.dev/nandi-testing "$@"
