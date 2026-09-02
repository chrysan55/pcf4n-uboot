#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=scripts/lib/common.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

require_cmd make
prepare_directories
fetch_repo atf "$ATF_REPO" "$ATF_COMMIT"
restore_tracked_source atf "$ATF_COMMIT"

src="$SOURCE_DIR/atf"
build_type=release
[[ "$ATF_DEBUG" == 1 ]] && build_type=debug
build_base="$BUILD_DIR/atf"
bl31="$build_base/agilex5/$build_type/bl31.bin"

# TF-A does not track build-variable changes as object dependencies.  Use the
# isolated build tree and clear it so a UART0 object cannot survive a switch
# to the PCF4N UART1 configuration.
log "cleaning ATF $build_type build"
make -C "$src" CROSS_COMPILE=aarch64-linux-gnu- PLAT=agilex5 \
  BUILD_BASE="$build_base" DEBUG="$ATF_DEBUG" clean

log "building ATF BL31 (UART$ATF_CONSOLE_UART, log level $ATF_LOG_LEVEL)"
# The locked TF-A revision has a verbose/toolchain-detection make expansion
# failure in lib/libfdt/libfdt.mk, so do not add V=1 to this invocation.
make -C "$src" CROSS_COMPILE=aarch64-linux-gnu- PLAT=agilex5 \
  BUILD_BASE="$build_base" DEBUG="$ATF_DEBUG" \
  LOG_LEVEL="$ATF_LOG_LEVEL" SOCFPGA_UART_CONFIG="$ATF_CONSOLE_UART" \
  -j"$JOBS" bl31

require_file "$bl31"
