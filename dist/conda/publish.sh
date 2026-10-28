#!/usr/bin/env bash
# Build the AppImage conda package and upload it to prefix.dev/nandi-testing.
#
# Authentication: CI pre-authenticates pixi with the organization secret
# PREFIX_DEV_TOKEN (setup-pixi `auth-host`/`auth-token`), so nothing is
# exported here. Locally, either export PREFIX_DEV_TOKEN or run
# `pixi auth login https://prefix.dev` once.
#
# Requires exactly one Ghostty-*-x86_64.AppImage in dist/conda/appimage/.
set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

shopt -s nullglob
appimages=("$here"/appimage/Ghostty-*-x86_64.AppImage)
if [ "${#appimages[@]}" -ne 1 ]; then
    echo "error: expected one Ghostty-*-x86_64.AppImage in $here/appimage," \
        "found ${#appimages[@]}" >&2
    exit 2
fi

if [ -n "${PREFIX_DEV_TOKEN:-}" ]; then
    pixi auth login https://prefix.dev --token "$PREFIX_DEV_TOKEN"
fi

pixi publish --path "$here" --to https://prefix.dev/nandi-testing "$@"
