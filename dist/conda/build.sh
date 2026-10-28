#!/usr/bin/env bash
# Build Ghostty for the conda package. Only Linux is supported by this recipe.
set -euo pipefail

# Zig caches the Ghostty dependencies in ZIG_GLOBAL_CACHE_DIR on the first
# build. The helper in nix/build-support does not produce cache entries that
# Zig 0.17 accepts for named dependencies, so let Zig fetch them itself.
export ZIG_GLOBAL_CACHE_DIR="${SRC_DIR}/zig-cache"
mkdir -p "${ZIG_GLOBAL_CACHE_DIR}"

# Point Zig at the conda toolchain instead of the host /usr include and /lib64.
gcc_dir="$(dirname "$(${HOST}-gcc -print-libgcc-file-name)")"
libc_txt="${SRC_DIR}/conda-libc.txt"
cat > "${libc_txt}" <<EOF
include_dir=${BUILD_PREFIX}/${HOST}/sysroot/usr/include
sys_include_dir=${BUILD_PREFIX}/${HOST}/sysroot/usr/include
crt_dir=${BUILD_PREFIX}/${HOST}/sysroot/usr/lib64
msvc_lib_dir=
kernel32_lib_dir=
gcc_dir=${gcc_dir}
darwin_sdk_dir=
cc_dir=$(command -v "${HOST}-gcc")
EOF

# With --sysroot, Zig prefixes every -L path (including the conda host
# ${PREFIX}/lib) with the sysroot. Mirror the prefix inside the sysroot so
# those paths resolve.
sysroot_dir="${BUILD_PREFIX}/${HOST}/sysroot"
mkdir -p "${sysroot_dir}$(dirname "${PREFIX}")"
ln -sfn "${PREFIX}" "${sysroot_dir}${PREFIX}"

# build.zig links -lbzip2 while conda-forge bzip2 ships libbz2.so. Add a
# build-time alias; the SONAME embedded in the binary stays libbz2.so.
bzip2_compat_link="${PREFIX}/lib/libbzip2.so"
ln -sf libbz2.so "${bzip2_compat_link}"

zig build \
    --prefix "${PREFIX}" \
    --sysroot "${sysroot_dir}" \
    --libc "${libc_txt}" \
    --search-prefix "${PREFIX}" \
    -Doptimize=ReleaseFast \
    -Dcpu=baseline \
    -Dversion-string="${PKG_VERSION}" \
    -Dinstalled-exe-path="${PREFIX}/bin/ghostty" \
    -Dpie=true

rm -f "${bzip2_compat_link}"

# Ghostty locates its resource dir by walking up from the binary looking for
# share/terminfo/x/xterm-ghostty. rattler-build drops the relative symlinks
# the build installs, so recreate them.
if [[ -f "${PREFIX}/share/terminfo/78/xterm-ghostty" ]]; then
    mkdir -p "${PREFIX}/share/terminfo/x" "${PREFIX}/share/terminfo/g"
    ln -sfn ../78/xterm-ghostty "${PREFIX}/share/terminfo/x/xterm-ghostty"
    ln -sfn ../78/xterm-ghostty "${PREFIX}/share/terminfo/g/ghostty"
fi

# menuinst reads $PREFIX/Menu/<package-name>.json on install and creates the
# desktop shortcut. The icon is referenced from the same directory.
mkdir -p "${PREFIX}/Menu"
cp "${RECIPE_DIR}/Menu/ghostty.json" "${PREFIX}/Menu/ghostty.json"
cp "${SRC_DIR}/images/gnome/512.png" "${PREFIX}/Menu/ghostty.png"
