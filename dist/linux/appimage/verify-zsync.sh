#!/usr/bin/env bash
#
# Verify that a .zsync file describes a specific AppImage, and that the
# AppImage's embedded update information points back at that .zsync file.
#
# A zsync client downloads the .zsync file first and uses it to fetch only the
# blocks that differ from the local AppImage. The .zsync file is only valid for
# the exact bytes it was generated from: it stores the file length and the
# SHA-1 of the whole file. If the AppImage changes after the .zsync is
# generated (for example by embedding update information afterwards), clients
# download the full file or fail the checksum.
#
# Usage:
#   verify-zsync.sh [--update-url URL] APPIMAGE ZSYNC
#
#   --update-url URL  The exact URL that must be embedded in the AppImage's
#                     .upd_info section. Default: only check that the embedded
#                     URL names the same .zsync file.
#
# Exit status is 0 when every check passes. Each failed check is reported on
# stderr.

set -euo pipefail

die() {
  echo "verification failed: $*" >&2
  exit 1
}

update_url=""
if [ "${1:-}" = "--update-url" ]; then
  update_url="${2:?--update-url needs a value}"
  shift 2
fi

if [ $# -ne 2 ]; then
  echo "usage: verify-zsync.sh [--update-url URL] APPIMAGE ZSYNC" >&2
  exit 2
fi

appimage=$1
zsync=$2

[ -f "$appimage" ] || die "no such AppImage: $appimage"
[ -f "$zsync" ] || die "no such zsync file: $zsync"

# Read the first value of a header from the zsync file.
header() {
  sed -n "s/^$1:[[:space:]]*//p" "$zsync" | head -n 1 | tr -d '\r'
}

length=$(header Length)
sha1_value=$(header "SHA-1")
filename=$(header Filename)
target_url=$(header URL)
blocksize=$(header Blocksize)

[ -n "$length" ] || die "missing Length header in $zsync"
[ -n "$sha1_value" ] || die "missing SHA-1 header in $zsync"
[ -n "$blocksize" ] || die "missing Blocksize header in $zsync"

actual_size=$(stat -c %s "$appimage")
[ "$actual_size" = "$length" ] ||
  die "size mismatch: $appimage is $actual_size bytes, $zsync says $length"

# zsyncmake writes the whole-file SHA-1 as hex; zsync2 writes it as base64.
# Accept both and compare hex digests with sha1sum's output.
actual_sha1=$(sha1sum "$appimage" | cut -d' ' -f1)
if printf '%s' "$sha1_value" | grep -Eq '^[0-9a-fA-F]{40}$'; then
  expected_sha1=$(printf '%s' "$sha1_value" | tr 'A-F' 'a-f')
else
  expected_sha1=$(printf '%s' "$sha1_value" | base64 --decode | od -An -tx1 | tr -d ' \n')
fi
[ "$actual_sha1" = "$expected_sha1" ] ||
  die "SHA-1 mismatch: $appimage is $actual_sha1, $zsync says $expected_sha1"

if [ -n "$filename" ] && [ "$filename" != "$(basename "$appimage")" ]; then
  die "filename mismatch: $zsync names $filename, got $appimage"
fi

# AppImageUpdate reads the .upd_info ELF section to find the .zsync file.
if ! command -v readelf > /dev/null 2>&1; then
  die "readelf not found; install binutils to inspect the update information"
fi
upd_info=$(readelf -p .upd_info "$appimage" 2> /dev/null |
  sed -n 's/^ *\[ *[0-9a-f]*\] *//p' | head -n 1 | sed 's/[[:space:]]*$//')
case "$upd_info" in
  zsync\|*) ;;
  *) die "no zsync update information in $appimage; rebuild it with appimagetool -u" ;;
esac

embedded_url=${upd_info#zsync|}
case "$embedded_url" in
  *.zsync) ;;
  *) die "update information does not name a .zsync file: $embedded_url" ;;
esac

if [ -n "$update_url" ] && [ "$embedded_url" != "$update_url" ]; then
  die "update information is $embedded_url, expected $update_url"
fi

# If the zsync file carries an absolute target URL, it must name the AppImage
# this .zsync was generated for.
if [ -n "$target_url" ] && [ "${target_url#*://}" != "$target_url" ]; then
  [ "$(basename "$target_url")" = "$(basename "$appimage")" ] ||
    die "zsync URL header is $target_url, which does not name $(basename "$appimage")"
fi

echo "ok: $(basename "$appimage")"
echo "  size:      $actual_size bytes"
echo "  sha1:      $actual_sha1"
echo "  blocksize: $blocksize"
echo "  update:    $upd_info"
