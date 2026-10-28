#!/usr/bin/env bash
# Build the AppImage conda package and upload it to prefix.dev/nandi-testing.
#
# Authentication: CI pre-authenticates pixi with the organization secret
# PREFIX_DEV_TOKEN (setup-pixi `auth-host`/`auth-token`), so nothing is
# exported here. Locally, either export PREFIX_DEV_TOKEN or run
# `pixi auth login https://prefix.dev` once.
#
# Requires exactly one Ghostty-*-x86_64.AppImage in dist/conda/appimage/.
# --build-number <n> sets the recipe build number; any other argument is
# passed through to `pixi publish`.
set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

build_number=
publish_args=()
while [ "$#" -gt 0 ]; do
    case "$1" in
        --build-number|--build-number=*)
            if [ "$1" = "--build-number" ]; then
                if [ "$#" -lt 2 ]; then
                    echo "error: --build-number needs a value" >&2
                    exit 2
                fi
                build_number=$2
                shift 2
            else
                build_number=${1#*=}
                shift
            fi
            ;;
        *)
            publish_args+=("$1")
            shift
            ;;
    esac
done

if [ -n "$build_number" ]; then
    case "$build_number" in
        *[!0-9]*)
            echo "error: --build-number must be a non-negative integer," \
                "got '$build_number'" >&2
            exit 2
            ;;
    esac
    # pixi publish's own --build-number is ignored for rattler-build recipes,
    # so hand the number to the recipe through the environment instead.
    export GHOSTTY_CONDA_BUILD_NUMBER=$build_number
fi

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

pixi publish --path "$here" --to https://prefix.dev/nandi-testing \
    ${publish_args[@]+"${publish_args[@]}"}
