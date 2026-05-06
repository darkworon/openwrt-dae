# openwrt-dae

Custom OpenWrt package feed for building `dae` with a patched Hysteria2
`salamander` outbound.

The package name is still `dae`, so an OpenWrt config that already contains
`CONFIG_PACKAGE_dae=y` can use it without changing package selections.

## What It Builds

- `dae` from `DAE_SOURCE_URL` / `DAE_SOURCE_REF`
- `github.com/daeuniverse/outbound` replaced with
  `DAE_OUTBOUND_REPO` / `DAE_OUTBOUND_REF`
- default outbound ref: `darkworon/outbound:stickyip-salamander`
- default dae ref: `daeuniverse/dae:main`

## Use In An OpenWrt Tree

```sh
git clone https://github.com/darkworon/openwrt-dae.git /tmp/openwrt-dae
/tmp/openwrt-dae/scripts/install-package.sh /path/to/openwrt
make -C /path/to/openwrt package/dae/compile V=s
```

The install script copies this package to:

```text
/path/to/openwrt/package/custom/dae
```

and removes feed-installed `dae` package directories so this custom package is
the one selected by `CONFIG_PACKAGE_dae=y`.

## CI Usage

This repository is a package source. The MT6000 package/image build is run from
`darkworon/openwrt-mt6000` GitHub Actions, which installs this package into an
OpenWrt tree after `./scripts/feeds install -a`.

Useful CI variables:

```text
DAE_SOURCE_REF=main
DAE_SOURCE_VERSION=latest
DAE_PKG_VERSION=2.0.0_alpha_git
DAE_OUTBOUND_REF=stickyip-salamander
DAE_OUTBOUND_REPO=https://github.com/darkworon/outbound.git
OPENWRT_REF=main
MT6000_OVERLAY_REF=main
```

To build the newest dae from another branch, start the `openwrt-mt6000`
firmware workflow with a different `DAE_SOURCE_REF`. If you want a pinned
reproducible build, set
`DAE_SOURCE_VERSION` to a commit hash.

As of May 6, 2026, `daeuniverse/dae` uses `main` as its default branch. If an
upstream `master` branch appears later, set `DAE_SOURCE_REF=master`.

## MT6000 Image Integration

In an MT6000 OpenWrt build job, replace the old "copy dae from immortalwrt"
step after `./scripts/feeds install -a` with:

```sh
git clone --depth=1 https://github.com/darkworon/openwrt-dae.git /tmp/openwrt-dae
/tmp/openwrt-dae/scripts/install-package.sh "$OPENWRT_DIR"
```

Then run the normal OpenWrt build. If the config already has:

```text
CONFIG_PACKAGE_dae=y
CONFIG_PACKAGE_luci-app-dae=y
```

the firmware image will include this custom `dae`.
