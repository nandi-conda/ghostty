#!/usr/bin/env bash
# Install the prebuilt Ghostty AppImage and its menuinst descriptor.
# Building the AppImage itself is the job of dist/linux/appimage and
# .github/workflows/appimage.yml.
set -euo pipefail

shopt -s nullglob
appimages=("${SRC_DIR}"/Ghostty-*-x86_64.AppImage)
if [ "${#appimages[@]}" -ne 1 ]; then
    echo "error: expected one Ghostty-*-x86_64.AppImage in ${SRC_DIR}," \
        "found ${#appimages[@]}" >&2
    exit 2
fi

mkdir -p "${PREFIX}/bin" "${PREFIX}/Menu"
install -m 0755 "${appimages[0]}" "${PREFIX}/bin/ghostty.AppImage"
install -m 0644 "${RECIPE_DIR}/Menu/ghostty.json" "${PREFIX}/Menu/ghostty.json"
install -m 0644 "${RECIPE_DIR}/Menu/ghostty.png" "${PREFIX}/Menu/ghostty.png"
