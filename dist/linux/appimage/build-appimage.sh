#!/usr/bin/env bash
#
# Build the Ghostty AppImage and the zsync files that AppImageUpdate uses to
# download deltas.
#
# The AppDir must already contain an installed Ghostty tree in usr/, built for
# the AppImage with:
#
#   zig build --prefix "$APPDIR/usr" \
#     -Doptimize=ReleaseFast -Dcpu=baseline
#
# The script bundles shared libraries and GTK data with linuxdeploy, packs the
# AppImage with appimagetool (embedding zsync update information) and generates
# the .zsync files from the finished AppImage.
#
# Two copies of every artifact are written:
#
#   Ghostty-VERSION-ARCH.AppImage(.zsync)
#       Versioned copy for direct downloads. Its update information points at
#       the channel below, so it can update itself later.
#
#   Ghostty-ARCH.AppImage(.zsync)
#       Channel copy at a version-independent path. Every release overwrites
#       it; existing installations point their updates at this file.
#
# Usage:
#   build-appimage.sh --appdir DIR --version VERSION --channel-base URL [--output DIR]

set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

appdir=""
version=""
channel_base=""
output_dir="$PWD"

usage() {
  cat <<'EOF'
Build the Ghostty AppImage and its zsync update metadata.

Usage: build-appimage.sh --appdir DIR --version VERSION --channel-base URL [--output DIR]

  --appdir DIR        AppDir with usr/bin/ghostty already installed
  --version VERSION   Version embedded in the versioned file name
  --channel-base URL  Base URL of the release channel. Update information is
                      URL/Ghostty-ARCH.AppImage.zsync; the artifacts are meant
                      to be published as URL/Ghostty-ARCH.AppImage and
                      URL/Ghostty-ARCH.AppImage.zsync, overwritten per release.
  --output DIR        Directory for the finished artifacts (default: $PWD)
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --appdir) appdir="${2:?--appdir needs a value}"; shift 2 ;;
    --version) version="${2:?--version needs a value}"; shift 2 ;;
    --channel-base) channel_base="${2:?--channel-base needs a value}"; shift 2 ;;
    --output) output_dir="${2:?--output needs a value}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "error: unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

if [ -z "$appdir" ] || [ -z "$version" ] || [ -z "$channel_base" ]; then
  echo "error: --appdir, --version and --channel-base are required" >&2
  usage >&2
  exit 2
fi

appdir=$(cd "$appdir" && pwd)
mkdir -p "$output_dir"
output_dir=$(cd "$output_dir" && pwd)
channel_base="${channel_base%/}"

exe="$appdir/usr/bin/ghostty"
desktop="$appdir/usr/share/applications/com.mitchellh.ghostty.desktop"
icon="$appdir/usr/share/icons/hicolor/256x256/apps/com.mitchellh.ghostty.png"

for f in "$exe" "$desktop" "$icon"; do
  if [ ! -f "$f" ]; then
    echo "error: missing $f; install Ghostty into the AppDir first" >&2
    exit 2
  fi
done

arch="${ARCH:-$(uname -m)}"
case "$arch" in
  x86_64|aarch64) ;;
  *) echo "error: unsupported architecture: $arch" >&2; exit 2 ;;
esac

linuxdeploy="${LINUXDEPLOY:-linuxdeploy}"
appimagetool="${APPIMAGETOOL:-appimagetool}"
zsyncmake="${ZSYNCMAKE:-zsyncmake}"
blocksize="${ZSYNC_BLOCKSIZE:-4096}"

for tool in "$linuxdeploy" "$appimagetool" "$zsyncmake"; do
  if ! command -v "$tool" > /dev/null 2>&1; then
    echo "error: $tool not found; set LINUXDEPLOY, APPIMAGETOOL or ZSYNCMAKE" >&2
    exit 2
  fi
done

if [ -n "${LINUXDEPLOY_GTK_PLUGIN:-}" ]; then
  PATH="$(cd "$(dirname "$LINUXDEPLOY_GTK_PLUGIN")" && pwd):$PATH"
  export PATH
fi
if ! command -v linuxdeploy-plugin-gtk.sh > /dev/null 2>&1; then
  echo "error: linuxdeploy-plugin-gtk.sh not found; put it in PATH or set LINUXDEPLOY_GTK_PLUGIN" >&2
  exit 2
fi

versioned="Ghostty-${version}-${arch}.AppImage"
channel="Ghostty-${arch}.AppImage"
channel_zsync_url="$channel_base/$channel.zsync"

# Ghostty's D-Bus service is not installed by an AppImage, so D-Bus activation
# would launch nothing. Start the executable directly instead.
sed -i 's/^DBusActivatable=.*/DBusActivatable=false/' "$desktop"

# Remove artifacts from a previous run so linuxdeploy starts from a clean
# AppDir root.
rm -rf "$appdir/AppRun" "$appdir/AppRun.wrapped" "$appdir/apprun-hooks"

# Development files are installed next to the executable but are not needed in
# a user-facing AppImage.
rm -rf "$appdir/usr/include"
find "$appdir/usr/lib" -maxdepth 1 \( -name 'libghostty-vt.so*' -o -name '*.a' \) -delete

echo "==> Bundling shared libraries and GTK data"
"$linuxdeploy" \
  --appdir "$appdir" \
  --desktop-file "$desktop" \
  --icon-file "$icon" \
  --custom-apprun "$script_dir/AppRun" \
  --plugin gtk

mkdir -p "$output_dir"
rm -f "$output_dir/$versioned" "$output_dir/$versioned.zsync" \
  "$output_dir/$channel" "$output_dir/$channel.zsync"

echo "==> Creating $versioned"
# appimagetool writes a .zsync next to the AppImage when update information is
# given, so run it from the output directory and overwrite that file below.
(
  cd "$output_dir"
  ARCH="$arch" "$appimagetool" -u "zsync|$channel_zsync_url" "$appdir" "$versioned"
)

# The channel copy is byte-identical, so it shares the embedded update
# information. appimagetool also creates a .zsync when zsyncmake is installed;
# overwrite it with our block size and explicit target URL.
cp "$output_dir/$versioned" "$output_dir/$channel"

echo "==> Creating zsync metadata (block size $blocksize)"
"$zsyncmake" -b "$blocksize" \
  -u "$channel_base/$versioned" \
  -o "$output_dir/$versioned.zsync" "$output_dir/$versioned"
"$zsyncmake" -b "$blocksize" \
  -u "$channel_base/$channel" \
  -o "$output_dir/$channel.zsync" "$output_dir/$channel"

echo "==> Verifying the AppImages and their zsync metadata"
"$script_dir/verify-zsync.sh" --update-url "$channel_zsync_url" \
  "$output_dir/$versioned" "$output_dir/$versioned.zsync"
"$script_dir/verify-zsync.sh" --update-url "$channel_zsync_url" \
  "$output_dir/$channel" "$output_dir/$channel.zsync"

echo
echo "Versioned AppImage: $output_dir/$versioned"
echo "Versioned zsync:    $output_dir/$versioned.zsync"
echo "Channel AppImage:   $output_dir/$channel"
echo "Channel zsync:      $output_dir/$channel.zsync"
echo "Update information: zsync|$channel_zsync_url"
