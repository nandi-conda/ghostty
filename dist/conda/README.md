# Conda packaging

This directory packages Ghostty as a normal conda package. It installs the
files that `zig build --prefix "$PREFIX"` produces plus a `menuinst`
descriptor that creates a desktop shortcut when the package is installed.

The AppImage in `../linux/appimage` is **not** part of this package. The
AppImage is only published with the GitHub rolling ("tip") release; the conda
channel ships the plain installed tree.

## Files

- `recipe.yaml` - rattler-build recipe used by `pixi build` / `pixi publish`.
- `build.sh` - builds Ghostty with Zig into `$PREFIX`, then installs the
  menuinst descriptor and icon.
- `Menu/ghostty.json` - menuinst 2.x descriptor. conda, mamba, micromamba and
  pixi read `$PREFIX/Menu/<package-name>.json` on install and create the
  desktop entry from it.

## Installed layout

The package contains the normal Zig install tree:

```
$PREFIX/bin/ghostty
$PREFIX/share/applications/com.mitchellh.ghostty.desktop
$PREFIX/share/metainfo/com.mitchellh.ghostty.metainfo.xml
$PREFIX/share/icons/hicolor/*/apps/com.mitchellh.ghostty.png
$PREFIX/share/ghostty/
$PREFIX/share/terminfo/{g/ghostty,x/xterm-ghostty}
$PREFIX/share/dbus-1/services/com.mitchellh.ghostty.service
$PREFIX/share/systemd/user/app-com.mitchellh.ghostty.service
$PREFIX/share/{bash-completion,fish,zsh}/...
$PREFIX/share/man/man1/ghostty.1
$PREFIX/Menu/ghostty.json
$PREFIX/Menu/ghostty.png
```

`build.sh` passes `-Dinstalled-exe-path=$PREFIX/bin/ghostty`, so the desktop
file, D-Bus service and systemd unit point at the absolute executable inside
the environment. The menuinst descriptor also uses `{{ PREFIX }}/bin/ghostty`
directly, so the shortcut works without activating the environment.

## Build

```sh
pixi build --path dist/conda --output-dir dist-out
# or
pixi run build-conda
```

Only `linux-64` is supported: `gtk4-layer-shell` is not packaged for
`linux-aarch64` yet.

## Publish

The testing channel is `nandi-testing` on prefix.dev:

```sh
pixi publish --path dist/conda --to https://prefix.dev/nandi-testing
# or
pixi run publish-conda-nandi-testing
```

Publishing needs write access to that channel. Create a prefix.dev API token
with write permission for `nandi-testing` and store it with either:

```sh
pixi auth login https://prefix.dev --token "$PREFIX_DEV_TOKEN"
# or point pixi at a token file
pixi publish --auth-file /path/to/token --path dist/conda \
  --to https://prefix.dev/nandi-testing
```

In CI keep the token in a secret (for example `PREFIX_DEV_TOKEN`) and never
commit it. `pixi auth status` shows the stored hosts. Uploading to prefix.dev
requires this token; anonymous uploads are not possible, and reading a private
channel also requires the token.

## Version

`recipe.yaml` sets `version: 1.4.1` for the current development tree. Bump it
together with `build.zig.zon` when tagging a release.
