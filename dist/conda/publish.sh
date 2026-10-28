#!/usr/bin/env bash
# Build the conda package from source and upload it to prefix.dev/nandi-testing.
#
# Authentication: export PREFIX_API_KEY (a prefix.dev API token with write
# access to nandi-testing). CI passes the repository secret.
# --build-number <n> sets the recipe build number (default 0).
set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
out=${OUTPUT_DIR:-$here/../../dist-out/conda}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --build-number) export GHOSTTY_CONDA_BUILD_NUMBER=$2; shift 2 ;;
        --build-number=*) export GHOSTTY_CONDA_BUILD_NUMBER=${1#*=}; shift ;;
        *) echo "error: unknown argument $1" >&2; exit 2 ;;
    esac
done

if [ -z "${PREFIX_API_KEY:-}" ]; then
    echo "error: PREFIX_API_KEY is not set" >&2
    exit 2
fi

pixi exec rattler-build build --recipe "$here/recipe.yaml" \
    -c conda-forge --output-dir "$out"

shopt -s nullglob globstar
pkgs=("$out"/**/ghostty-*.conda)
pixi exec rattler-build upload prefix -c nandi-testing --skip-existing "${pkgs[@]}"
