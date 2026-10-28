#!/usr/bin/env bash
# Build the Ghostty GTK app from source and install it into $PREFIX.
set -euxo pipefail

# blueprint-compiler is not packaged on conda-forge; the recipe downloads
# its wheel.
"${BUILD_PREFIX}/bin/python" -m pip install --no-deps --no-index \
    "${SRC_DIR}"/.wheels/blueprint_compiler-*.whl

export ZIG_GLOBAL_CACHE_DIR="${SRC_DIR}/.zig-global-cache"
export ZIG_LOCAL_CACHE_DIR="${SRC_DIR}/.zig-local-cache"
export PKG_CONFIG_PATH="${PREFIX}/lib/pkgconfig:${PREFIX}/share/pkgconfig"
export GI_TYPELIB_PATH="${BUILD_PREFIX}/lib/girepository-1.0"

zig build \
    --prefix "${PREFIX}" \
    --search-prefix "${PREFIX}" \
    -Doptimize=ReleaseFast \
    -Dcpu=baseline \
    -Dinstalled-exe-path="${PREFIX}/bin/ghostty" \
    -fsys=gtk4-layer-shell

mkdir -p "${PREFIX}/Menu"
install -m 0644 "${RECIPE_DIR}/Menu/ghostty.json" "${PREFIX}/Menu/ghostty.json"
install -m 0644 "${RECIPE_DIR}/Menu/ghostty.png" "${PREFIX}/Menu/ghostty.png"
