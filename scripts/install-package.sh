#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  scripts/install-package.sh /path/to/openwrt

Copies this repository's custom dae package into an OpenWrt build tree as:
  package/custom/dae

It also removes stale feed-installed dae packages so CONFIG_PACKAGE_dae resolves
to this custom package.
USAGE
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" || $# -ne 1 ]]; then
  usage
  exit $([[ $# -eq 1 ]] && echo 0 || echo 1)
fi

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
openwrt_dir="$(cd -- "$1" && pwd -P)"

[[ -f "$openwrt_dir/rules.mk" && -d "$openwrt_dir/package" ]] || {
  echo "error: not an OpenWrt build tree: $openwrt_dir" >&2
  exit 1
}

target_dir="$openwrt_dir/package/custom/dae"
mkdir -p "$(dirname "$target_dir")"
rm -rf "$target_dir"
rsync -a --delete "$repo_dir/net/dae/" "$target_dir/"

find "$openwrt_dir/package/feeds" -mindepth 2 -maxdepth 2 \( -type d -o -type l \) -name dae -prune -exec rm -rf {} + 2>/dev/null || true

echo "installed custom dae package: $target_dir"
