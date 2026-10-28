# Ghostty conda package

This directory builds the Ghostty GTK app from source as a conda package and
adds a `menuinst` shortcut, so Ghostty can be installed from the
`nandi-testing` channel on prefix.dev. The AppImage is only a GitHub release
artifact and is not used here.

## Files

- `recipe.yaml` - rattler-build recipe. Dependencies come from conda-forge;
  Zig fetches the packages pinned in `build.zig.zon` during the build.
- `build.sh` - installs `blueprint-compiler` from PyPI (it is not on
  conda-forge), then runs `zig build --prefix $PREFIX -Doptimize=ReleaseFast
  -Dcpu=baseline`.
- `Menu/ghostty.json`, `Menu/ghostty.png` - menuinst descriptor and icon.
- `publish.sh` - builds and uploads to prefix.dev/nandi-testing.

## Build

```sh
pixi run build-conda
# or
pixi exec rattler-build build --recipe dist/conda/recipe.yaml \
  -c conda-forge --output-dir dist-out/conda
```

The build number comes from `GHOSTTY_CONDA_BUILD_NUMBER` (default 0). CI sets
it to the commit count.

## Publish

`.github/workflows/conda.yml` builds `linux-64` and `linux-aarch64` on every
push to `main` that touches `dist/conda/` (or on a manual dispatch) and uploads
with `rattler-build upload prefix -c nandi-testing`. It needs the repository
secret `PREFIX_API_KEY` (or `PREFIX_DEV_TOKEN`): a prefix.dev API token with
write access to `nandi-testing`.

Locally:

```sh
PREFIX_API_KEY=... dist/conda/publish.sh --build-number "$(git rev-list --count HEAD)"
```

## Install

```sh
pixi global install -c https://prefix.dev/nandi-testing -c conda-forge ghostty
```

## Version

`recipe.yaml` sets `version: "1.4.1"`. Bump it together with `build.zig.zon`.
