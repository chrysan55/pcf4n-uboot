#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=scripts/lib/common.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

require_cmd make
prepare_directories
fetch_repo linux "$LINUX_REPO" "$LINUX_COMMIT"

src="$SOURCE_DIR/linux"
out="$BUILD_DIR/linux"
modules="$STAGING_DIR/modules"
mkdir -p "$out" "$modules"
cp "$ROOT_DIR/board/pcf4n/linux/socfpga_agilex5_pcf4n.dts" \
  "$src/arch/arm64/boot/dts/intel/"

log "configuring Linux"
make -C "$src" O="$out" ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- defconfig
"$src/scripts/kconfig/merge_config.sh" -m -O "$out" "$out/.config" \
  "$ROOT_DIR/board/pcf4n/linux/pcf4n.config"
make -C "$src" O="$out" ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- olddefconfig

log "building Linux Image, DTB, and modules"
KBUILD_BUILD_TIMESTAMP="@$(source_date_epoch)"
export KBUILD_BUILD_TIMESTAMP
export KBUILD_BUILD_USER=bootstrap
export KBUILD_BUILD_HOST=container
make -C "$src" O="$out" ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- \
  -j"$JOBS" Image intel/socfpga_agilex5_pcf4n.dtb modules

rm -rf -- "${modules:?}/lib"
make -C "$src" O="$out" ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- \
  INSTALL_MOD_PATH="$modules" modules_install

require_file "$out/arch/arm64/boot/Image"
require_file "$out/arch/arm64/boot/dts/intel/socfpga_agilex5_pcf4n.dtb"
