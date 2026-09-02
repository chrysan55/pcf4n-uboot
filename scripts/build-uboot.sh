#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=scripts/lib/common.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

require_cmd make
prepare_directories
fetch_repo u-boot "$UBOOT_REPO" "$UBOOT_COMMIT"
fetch_repo atf "$ATF_REPO" "$ATF_COMMIT"
restore_tracked_source u-boot "$UBOOT_COMMIT"

atf_build_type=release
[[ "$ATF_DEBUG" == 1 ]] && atf_build_type=debug
atf_bl31="$BUILD_DIR/atf/agilex5/$atf_build_type/bl31.bin"
require_file "$atf_bl31"

src="$SOURCE_DIR/u-boot"
out="$BUILD_DIR/u-boot"
generated="$WORK_DIR/generated/u-boot"
mkdir -p "$out" "$generated"

cp "$ROOT_DIR/board/pcf4n/u-boot/socfpga_agilex5_pcf4n.dts" "$src/arch/arm/dts/"
cp "$ROOT_DIR/board/pcf4n/u-boot/socfpga_agilex5_pcf4n-u-boot.dtsi" "$src/arch/arm/dts/"
ln -sfn "$atf_bl31" "$src/bl31.bin"

build_kind=dev-placeholder
[[ "$QSPI_UBOOT_OFFSET_STATUS" == confirmed ]] && build_kind=release
fragment="$generated/pcf4n.config"
render_template "$ROOT_DIR/board/pcf4n/u-boot/pcf4n.config.in" "$fragment" \
  BUILD_KIND "$build_kind" \
  QSPI_UBOOT_OFFSET "$QSPI_UBOOT_OFFSET" \
  TFTP_PREFIX "$TFTP_PREFIX" \
  LOCAL_MAC_ADDRESS "$LOCAL_MAC_ADDRESS" \
  SCRIPT_ADDRESS "$SCRIPT_ADDRESS"

log "configuring U-Boot"
make -C "$src" O="$out" ARCH=arm CROSS_COMPILE=aarch64-linux-gnu- \
  socfpga_agilex5_defconfig
"$src/scripts/kconfig/merge_config.sh" -m -O "$out" "$out/.config" "$fragment"
make -C "$src" O="$out" ARCH=arm CROSS_COMPILE=aarch64-linux-gnu- olddefconfig

log "building U-Boot with QSPI offset $QSPI_UBOOT_OFFSET ($QSPI_UBOOT_OFFSET_STATUS)"
export SOURCE_DATE_EPOCH
SOURCE_DATE_EPOCH=$(source_date_epoch)
make -C "$src" O="$out" ARCH=arm CROSS_COMPILE=aarch64-linux-gnu- -j"$JOBS"

require_file "$out/u-boot.itb"
require_file "$out/spl/u-boot-spl-dtb.hex"
