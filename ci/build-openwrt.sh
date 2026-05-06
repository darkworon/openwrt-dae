#!/usr/bin/env bash
set -euo pipefail

mode="${1:-package}"
case "$mode" in
  package|image)
    ;;
  *)
    echo "usage: $0 [package|image]" >&2
    exit 1
    ;;
esac

ci_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
repo_dir="$(cd -- "$ci_dir/.." && pwd -P)"

workdir="${WORKDIR:-$repo_dir/.work}"
openwrt_dir="${OPENWRT_DIR:-$workdir/openwrt}"
overlay_dir="${MT6000_OVERLAY_DIR:-$workdir/openwrt-mt6000}"
luci_app_dae_dir="${LUCI_APP_DAE_DIR:-$workdir/luci-app-dae}"

openwrt_repo="${OPENWRT_REPO:-https://github.com/openwrt/openwrt.git}"
openwrt_ref="${OPENWRT_REF:-main}"
overlay_repo="${MT6000_OVERLAY_REPO:-https://github.com/darkworon/openwrt-mt6000.git}"
overlay_ref="${MT6000_OVERLAY_REF:-main}"
luci_app_dae_repo="${LUCI_APP_DAE_REPO:-https://github.com/darkworon/openwrt-mt6000-luci-app-dae.git}"
luci_app_dae_ref="${LUCI_APP_DAE_REF:-main}"

jobs="${JOBS:-$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 2)}"
ccache_dir="${CCACHE_DIR:-$workdir/ccache}"

log() {
  printf '==> %s\n' "$*" >&2
}

clone_or_update() {
  local repo=$1
  local ref=$2
  local dir=$3

  if [[ ! -d "$dir/.git" ]]; then
    rm -rf "$dir"
    git clone --depth=1 --branch "$ref" "$repo" "$dir"
  else
    git -C "$dir" fetch --depth=1 origin "$ref"
    git -C "$dir" reset --hard FETCH_HEAD
    git -C "$dir" clean -ffd
  fi
}

apply_mt6000_overlay() {
  log "Applying MT6000 overlay"

  local kernel_target
  kernel_target="$(find "$openwrt_dir/target/linux/mediatek" -maxdepth 1 -type d -name 'patches-*' | sort -V | tail -n1)"
  [[ -n "$kernel_target" ]] || {
    echo "error: no mediatek kernel patch directory found" >&2
    exit 1
  }

  cp "$overlay_dir"/patches/kernel/*.patch "$kernel_target"/ 2>/dev/null || true

  mkdir -p "$openwrt_dir/package/kernel/mt76/patches"
  cp "$overlay_dir"/patches/mt76/*.patch "$openwrt_dir/package/kernel/mt76/patches"/ 2>/dev/null || true
  cp "$overlay_dir"/patches/mt76-local/*.patch "$openwrt_dir/package/kernel/mt76/patches"/ 2>/dev/null || true

  if [[ -d "$overlay_dir/files" ]]; then
    rsync -a "$overlay_dir/files/" "$openwrt_dir/"
  fi

  cp "$overlay_dir/config/feeds.conf.default" "$openwrt_dir/feeds.conf.default"
  cp "$overlay_dir/config/mt6000.diffconfig" "$openwrt_dir/.config"
}

install_luci_app_dae() {
  log "Installing luci-app-dae package"
  mkdir -p "$openwrt_dir/package/custom/luci-app-dae"
  rsync -a --delete "$luci_app_dae_dir/luci-app-dae/" "$openwrt_dir/package/custom/luci-app-dae/"
}

mkdir -p "$workdir" "$ccache_dir"

log "Cloning OpenWrt: $openwrt_repo $openwrt_ref"
clone_or_update "$openwrt_repo" "$openwrt_ref" "$openwrt_dir"

log "Cloning MT6000 overlay: $overlay_repo $overlay_ref"
clone_or_update "$overlay_repo" "$overlay_ref" "$overlay_dir"

log "Cloning luci-app-dae: $luci_app_dae_repo $luci_app_dae_ref"
clone_or_update "$luci_app_dae_repo" "$luci_app_dae_ref" "$luci_app_dae_dir"

apply_mt6000_overlay

log "Installing custom dae package"
"$repo_dir/scripts/install-package.sh" "$openwrt_dir"
install_luci_app_dae

log "Updating feeds"
(
  cd "$openwrt_dir"
  ./scripts/feeds update -a
  ./scripts/feeds install -a
)

log "Expanding config"
make -C "$openwrt_dir" defconfig

log "Building tools, toolchain and target"
make -C "$openwrt_dir" -j"$jobs" CCACHE_DIR="$ccache_dir" USE_CCACHE=1 \
  tools/install toolchain/install target/compile

log "Building custom dae package"
make -C "$openwrt_dir" -j"$jobs" CCACHE_DIR="$ccache_dir" USE_CCACHE=1 \
  package/dae/clean package/dae/compile V=s

if [[ "$mode" == "image" ]]; then
  log "Building firmware image"
  make -C "$openwrt_dir" -j"$jobs" CCACHE_DIR="$ccache_dir" USE_CCACHE=1 \
    package/install package/index
  make -C "$openwrt_dir" -j1 V=s CCACHE_DIR="$ccache_dir" USE_CCACHE=1 \
    target/install
fi

log "Artifacts"
find "$openwrt_dir/bin" -type f \( -name '*dae*' -o -name '*sysupgrade*.bin' -o -name 'sha256sums' -o -name '*.manifest' \) -print | sort
