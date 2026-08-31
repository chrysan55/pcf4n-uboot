#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=scripts/lib/common.sh
source "$ROOT_DIR/scripts/lib/common.sh"

"$ROOT_DIR/scripts/check.sh"

[[ "$QSPI_UBOOT_OFFSET_STATUS" == confirmed ]] || die 'QSPI U-Boot offset is not confirmed'
[[ "$LOCAL_MAC_STATUS" == confirmed ]] || die 'MAC source is not confirmed'
[[ "$BASE_IMAGE_DIGEST" =~ ^sha256:[0-9a-f]{64}$ ]] || die 'Docker base image is not digest-pinned'
require_file "$OUTPUT_DIR/build-manifest.json"
require_file "$OUTPUT_DIR/qspi-handoff/u-boot.itb"
require_file "$OUTPUT_DIR/qspi-handoff/u-boot-spl-dtb.hex"
require_file "$OUTPUT_DIR/deploy/kernel.itb"
require_file "$OUTPUT_DIR/deploy/rootfs.ext4"

uboot_size=$(wc -c <"$OUTPUT_DIR/qspi-handoff/u-boot.itb")
kernel_size=$(wc -c <"$OUTPUT_DIR/deploy/kernel.itb")
rootfs_size=$(wc -c <"$OUTPUT_DIR/deploy/rootfs.ext4")
(( uboot_size <= UBOOT_MAX_BYTES )) || die 'u-boot.itb exceeds allocation'
(( kernel_size <= KERNEL_PARTITION_BYTES )) || die 'kernel.itb exceeds eMMC partition'
(( rootfs_size <= ROOTFS_PARTITION_BYTES )) || die 'rootfs.ext4 exceeds eMMC partition'

jq -e '.releaseReady == true' "$OUTPUT_DIR/build-manifest.json" >/dev/null || die 'manifest is not release-ready'
[[ -z "$(git -C "$ROOT_DIR" status --porcelain)" ]] || die 'working tree is not clean'

printf 'Production release gates passed.\n'
