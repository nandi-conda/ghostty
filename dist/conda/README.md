# Ghostty AppImage conda package

This directory wraps the Ghostty AppImage in a conda package and adds a
`menuinst` shortcut, so the AppImage can be installed and updated from a
prefix.dev channel.

The package does not build Ghostty. The AppImage is built by
`dist/linux/appimage` and `.github/workflows/appimage.yml`; this recipe only
installs the finished file.

## Files

- `recipe.yaml` - rattler-build recipe used by `pixi build` / `pixi publish`.
- `build.sh` - installs the AppImage and the menuinst files into `$PREFIX`.
- `Menu/ghostty.json` - menuinst 2.x descriptor. conda, mamba, micromamba and
  pixi read `$PREFIX/Menu/<package-name>.json` when the package is installed
  and create the desktop entry from it.
- `Menu/ghostty.png` - icon referenced by the descriptor.
- `appimage/` - where the AppImage must be placed before building. It is
  git-ignored; CI downloads the `appimage` artifact there.

## Installed layout

```
$PREFIX/bin/ghostty.AppImage
$PREFIX/Menu/ghostty.json
$PREFIX/Menu/ghostty.png
```

The menuinst command is `{{ PREFIX }}/bin/ghostty.AppImage` and the descriptor
sets `activate: false`, so the shortcut launches the AppImage directly instead
of running `conda shell.bash activate` first. Because the payload is an
AppImage, it also updates itself through the channel embedded in the file (the
`.zsync` URL under `https://tip.files.ghostty.org/appimage/`); the conda
package never has to be reinstalled for that.

`menuinst` 2.5.2 writes the `Icon=` line of the generated desktop entry as a
literal `{_escape_desktop_string(self.render_key('icon')}` instead of the icon
path. The descriptor has the right value (`{{ MENU_DIR }}/ghostty.png`, which
`build.sh` installs), so the entry gets a correct icon as soon as that upstream
formatting bug is fixed.

## Build

Place the AppImage in `appimage/` first:

```sh
mkdir -p dist/conda/appimage
cp dist-out/Ghostty-*-x86_64.AppImage dist/conda/appimage/
pixi build --path dist/conda --output-dir dist-out
# or
pixi run build-appimage-conda
```

Only `linux-64` is supported. The AppImage needs FUSE 2 at runtime; systems
without it (or containers) can run the file with `--appimage-extract-and-run`.

## Publish

The testing channel is `nandi-testing` on prefix.dev:

```sh
dist/conda/publish.sh
# or
pixi run publish-appimage-nandi-testing
```

`publish.sh` checks for the AppImage, then runs
`pixi publish --path dist/conda --to https://prefix.dev/nandi-testing`.
It builds the package first; pass `--build-number` to override the build
number (CI uses the number of commits, the same number the tip release uses).

### Credentials

Publishing uses the organization secret `PREFIX_DEV_TOKEN`, a prefix.dev API
token with write access to the `nandi-testing` channel. The release workflow
gives it to setup-pixi (`auth-host`/`auth-token`), which logs pixi in, so the
CI publish step relies on the org secret and never exports the token itself.
Reading a private channel needs the same token.

For a local run, either export `PREFIX_DEV_TOKEN` (`publish.sh` then runs
`pixi auth login`) or run `pixi auth login https://prefix.dev` once by hand.
Never commit the token. `pixi auth status` lists the stored hosts.

The channel must already exist and the token must be allowed to write to it;
prefix.dev does not accept anonymous uploads.

## Version

`recipe.yaml` sets `version: "1.4.1"` for the current development tree. Bump
it together with `build.zig.zon` when tagging a release. The AppImage inside is
the tip build; its version is the commit hash embedded by the AppImage
workflow, which is why CI sets the conda *build number* to the commit count.
