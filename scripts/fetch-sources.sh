#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=scripts/lib/common.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

require_cmd git
validate_source_locks
prepare_directories

fetch_repo u-boot "$UBOOT_REPO" "$UBOOT_COMMIT"
fetch_repo linux "$LINUX_REPO" "$LINUX_COMMIT"
fetch_repo atf "$ATF_REPO" "$ATF_COMMIT"
fetch_repo buildroot "$BUILDROOT_REPO" "$BUILDROOT_COMMIT"
