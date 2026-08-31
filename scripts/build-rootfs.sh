#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=scripts/lib/common.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

# The remote builder is administered as root, so container.sh preserves uid 0.
# GNU packages such as tar reject a root configure unless this documented
# Autoconf escape hatch is set. Builds remain isolated inside the disposable
# container and only write the workspace/cache mounts.
export FORCE_UNSAFE_CONFIGURE=1

require_cmd make sha256sum
prepare_directories
fetch_repo buildroot "$BUILDROOT_REPO" "$BUILDROOT_COMMIT"

src="$SOURCE_DIR/buildroot"
out="$BUILD_DIR/buildroot"
overlay="$WORK_DIR/generated/rootfs-overlay"
generated_defconfig="$WORK_DIR/generated/pcf4n_defconfig"
mkdir -p "$out" "$overlay" "$(dirname -- "$generated_defconfig")" "$BUILD_CACHE_DIR/buildroot-dl"

rm -rf -- "$overlay"
mkdir -p "$overlay"
rsync -a "$ROOT_DIR/board/pcf4n/buildroot/rootfs-overlay/" "$overlay/"
if [[ -d "$STAGING_DIR/modules/lib/modules" ]]; then
  mkdir -p "$overlay/lib"
  rsync -a "$STAGING_DIR/modules/lib/modules" "$overlay/lib/"
fi

cp "$ROOT_DIR/board/pcf4n/buildroot/pcf4n_defconfig" "$generated_defconfig"
printf 'BR2_ROOTFS_OVERLAY="%s"\n' "$overlay" >>"$generated_defconfig"
printf 'BR2_DL_DIR="%s"\n' "$BUILD_CACHE_DIR/buildroot-dl" >>"$generated_defconfig"

config_hash=$(sha256sum "$generated_defconfig" | awk '{print $1}')
config_stamp="$out/.pcf4n-defconfig.sha256"
if [[ -f "$out/.config" ]] &&
   { [[ ! -f "$config_stamp" ]] || [[ "$(<"$config_stamp")" != "$config_hash" ]]; }; then
  log "Buildroot configuration changed; clearing its isolated output tree"
  rm -rf -- "$out"
fi
mkdir -p "$out"

log "configuring Buildroot"
make -C "$src" O="$out" BR2_DEFCONFIG="$generated_defconfig" defconfig
printf '%s\n' "$config_hash" >"$config_stamp"

log "building 1 GiB ext4 rootfs (low-memory job count: $MEMORY_HEAVY_JOBS)"
export SOURCE_DATE_EPOCH
SOURCE_DATE_EPOCH=$(source_date_epoch)
make -C "$src" O="$out" -j"$MEMORY_HEAVY_JOBS"

require_file "$out/images/rootfs.ext4"
