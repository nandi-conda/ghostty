# Ghostty AppImage with zsync updates

This directory builds a self-contained Ghostty AppImage and the zsync metadata
that [AppImageUpdate](https://github.com/AppImageCommunity/AppImageUpdate) uses
to download only the changed blocks of a new release.

Files:

- `build-appimage.sh` — turns an installed Ghostty tree into the AppImage and
  its `.zsync` files.
- `verify-zsync.sh` — checks that a `.zsync` file belongs to an AppImage and
  that the AppImage's embedded update information points at the right
  `.zsync`.
- `AppRun` — the AppImage entry point.

The CI workflow that publishes the artifacts is
`.github/workflows/appimage.yml`.

## Artifacts

Every build produces two pairs of files:

| File | Purpose |
| --- | --- |
| `Ghostty-VERSION-x86_64.AppImage` | Versioned AppImage, for direct downloads. |
| `Ghostty-VERSION-x86_64.AppImage.zsync` | zsync metadata for the versioned file. |
| `Ghostty-x86_64.AppImage` | Channel AppImage at a version-independent path. Every release overwrites it. |
| `Ghostty-x86_64.AppImage.zsync` | zsync metadata for the channel file, also overwritten every release. |

All four describe the same binary. The two files without a version use a stable
path, which is what auto-updating depends on:

```
https://release.files.ghostty.org/appimage/Ghostty-x86_64.AppImage
https://release.files.ghostty.org/appimage/Ghostty-x86_64.AppImage.zsync
```

Tagged releases also publish the versioned pair next to the other release
artifacts:

```
https://release.files.ghostty.org/VERSION/Ghostty-VERSION-x86_64.AppImage
https://release.files.ghostty.org/VERSION/Ghostty-VERSION-x86_64.AppImage.zsync
```

The versioned AppImage embeds the channel `.zsync` URL, not its own, so a
versioned download starts updating from the channel as soon as a newer release
is published. Without a stable URL an installed AppImage would keep pointing at
the `.zsync` of the release it came from and would never see an update.

## How auto-updating works

1. `appimagetool -u "zsync|URL"` writes `zsync|URL` into the AppImage's
   `.upd_info` ELF section before the filesystem is packed. This is the only
   place an AppImage stores its update source.
2. An updater (`appimageupdatetool`, `AppImageUpdate`, or a desktop
   integration such as AppImageLauncher) reads `.upd_info`, downloads
   `URL` (the channel `.zsync` file) and reads its headers:
   - `Length` and `SHA-1` describe the complete target file.
   - `Blocksize` plus the block checksum table describe every block.
   - `URL` names the target AppImage; a relative value resolves against the
     `.zsync` URL.
3. The updater reads the installed AppImage and matches its blocks against the
   table. Matching blocks are copied from the local file; only the rest is
   requested from the server with HTTP `Range` requests.
4. The result must match `Length` and `SHA-1` before it replaces the old file.

Because the `.zsync` is generated from the finished AppImage, any later change
to the AppImage invalidates it. The build script therefore embeds the update
information first, builds the AppImage, and only then runs `zsyncmake`.

Servers must support HTTP range requests for deltas to help; without them the
updater falls back to downloading the whole file. Cloudflare R2 and GitHub
release assets both support ranges.

AppImages are not signed here, so AppImageUpdate reports
`Validation warning: AppImage not signed` and updates anyway. The SHA-1 check
still guarantees that the downloaded file matches the published metadata.

## Building

Install the dependencies listed in `.github/workflows/appimage.yml`. The build
needs GTK 4 and libadwaita 1.7 or newer, and produces an AppImage that runs on
distributions with glibc 2.41 or newer (Debian 13, Ubuntu 25.04 and newer,
Fedora 42 and newer).

```sh
version=1.4.0
appdir="$PWD/AppDir"

zig build --prefix "$appdir/usr" \
  -Dversion-string="$version" \
  -Doptimize=ReleaseFast \
  -Dcpu=baseline

APPIMAGE_EXTRACT_AND_RUN=1 dist/linux/appimage/build-appimage.sh \
  --appdir "$appdir" \
  --version "$version" \
  --channel-base https://release.files.ghostty.org/appimage \
  --output dist-out
```

The install layout inside the AppDir is the normal Zig install layout that
other packagers use:

```
usr/bin/ghostty
usr/share/ghostty/                     # themes, shell integration, terminfo source
usr/share/terminfo/                    # compiled terminfo database
usr/share/applications/com.mitchellh.ghostty.desktop
usr/share/metainfo/com.mitchellh.ghostty.metainfo.xml
usr/share/icons/hicolor/.../apps/com.mitchellh.ghostty.png
usr/share/dbus-1/services/com.mitchellh.ghostty.service
usr/share/systemd/user/app-com.mitchellh.ghostty.service
usr/share/bash-completion/completions/ghostty
usr/share/fish/vendor_completions.d/ghostty.fish
usr/share/zsh/site-functions/_ghostty
usr/share/man/man1/ghostty.1
```

`build-appimage.sh` sets `DBusActivatable=false` in the desktop file, because
an AppImage cannot install the D-Bus service file that D-Bus activation needs.

## Verifying a release

`verify-zsync.sh` checks the three things that make a release usable:

- The `.zsync` `Length` and `SHA-1` match the AppImage bytes.
- The AppImage has a `zsync|...` value in `.upd_info`.
- The embedded URL is the expected channel URL (`--update-url`).

Run it against a downloaded pair:

```sh
dist/linux/appimage/verify-zsync.sh \
  --update-url https://release.files.ghostty.org/appimage/Ghostty-x86_64.AppImage.zsync \
  Ghostty-x86_64.AppImage Ghostty-x86_64.AppImage.zsync
```

Expected output:

```
ok: Ghostty-x86_64.AppImage
  size:      48234496 bytes
  sha1:      8b1a...
  blocksize: 4096
  update:    zsync|https://release.files.ghostty.org/appimage/Ghostty-x86_64.AppImage.zsync
```

To do the same checks by hand:

```sh
# 1. The zsync describes this file: compare Length and SHA-1.
grep -E '^(Length|Blocksize|SHA-1|URL):' Ghostty-x86_64.AppImage.zsync
stat -c %s Ghostty-x86_64.AppImage
sha1sum Ghostty-x86_64.AppImage
# zsyncmake writes SHA-1 as hex; zsync2 writes base64 of the same 20 bytes.

# 2. The update information is embedded in the AppImage.
readelf -p .upd_info Ghostty-x86_64.AppImage
#  [     0]  zsync|https://release.files.ghostty.org/appimage/Ghostty-x86_64.AppImage.zsync

# 3. The channel URLs resolve to the same bytes as the versioned release.
curl -fsSL https://release.files.ghostty.org/appimage/Ghostty-x86_64.AppImage.zsync |
  grep -E '^(Length|SHA-1):'
```

To exercise an update without replacing the installed file, use
`appimageupdatetool`; it writes the updated AppImage next to the old one:

```sh
appimageupdatetool --check-for-update Ghostty-x86_64.AppImage
appimageupdatetool Ghostty-x86_64.AppImage
```

`--check-for-update` exits with status 1 when an update is available, 0 when
the file is current, and another non-zero status on errors.
