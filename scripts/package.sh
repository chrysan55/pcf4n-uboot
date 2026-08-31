#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=scripts/lib/common.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

for cmd in gzip jq mkimage sha256sum tar zstd; do require_cmd "$cmd"; done

uboot_out="$BUILD_DIR/u-boot"
linux_out="$BUILD_DIR/linux"
buildroot_out="$BUILD_DIR/buildroot"
handoff="$OUTPUT_DIR/qspi-handoff"
logic_handoff="$OUTPUT_DIR/logic-handoff"
deploy="$OUTPUT_DIR/deploy"
generated="$WORK_DIR/generated/package"
atf_build_type=release
[[ "$ATF_DEBUG" == 1 ]] && atf_build_type=debug
atf_bl31="$BUILD_DIR/atf/agilex5/$atf_build_type/bl31.bin"

# Validate every required input before replacing any previously packaged
# output. A partial local build must not destroy the last complete handoff.
require_file "$atf_bl31"
require_file "$uboot_out/u-boot.bin"
require_file "$uboot_out/u-boot.itb"
require_file "$uboot_out/spl/u-boot-spl-dtb.hex"
require_file "$linux_out/arch/arm64/boot/Image"
require_file "$linux_out/arch/arm64/boot/dts/intel/socfpga_agilex5_pcf4n.dtb"
require_file "$buildroot_out/images/rootfs.ext4"

# These directories contain generated artifacts only. Clearing them after all
# validation makes a repeated package run unable to retain stale files from
# an older build while preserving the last package on preflight failure.
rm -rf -- "$handoff" "$logic_handoff" "$deploy" "$generated"
mkdir -p "$handoff" "$logic_handoff" "$deploy" "$generated"

install -m 0644 "$atf_bl31" "$handoff/bl31.bin"
install -m 0644 "$uboot_out/u-boot.itb" "$handoff/u-boot.itb"
# PFG workflows often require a .bin filename for raw partition data. Keep
# this byte-identical to the FIT because SPL_LOAD_FIT cannot boot the native
# U-Boot flat binary directly.
install -m 0644 "$uboot_out/u-boot.itb" "$handoff/u-boot.bin"
# Preserve the native flat build output under an unambiguous diagnostic name.
install -m 0644 "$uboot_out/u-boot.bin" "$handoff/u-boot-raw.bin"
install -m 0644 "$uboot_out/spl/u-boot-spl-dtb.hex" "$handoff/u-boot-spl-dtb.hex"
install -m 0644 "$ROOT_DIR/board/pcf4n/quartus/qspi_helper.pfg" \
  "$handoff/qspi_helper.pfg"

# Keep the historical logic-handoff path as an exact, checksummed mirror.
# Having two independently populated directories previously left an older HEX
# beside the current qspi-handoff and made it easy to program mismatched files.
for file in bl31.bin qspi_helper.pfg u-boot.itb u-boot.bin u-boot-raw.bin \
  u-boot-spl-dtb.hex; do
  install -m 0644 "$handoff/$file" "$logic_handoff/$file"
done
install -m 0644 "$ROOT_DIR/board/pcf4n/u-boot/logic-handoff.README.md" \
  "$logic_handoff/README.md"
(
  cd "$logic_handoff"
  sha256sum bl31.bin qspi_helper.pfg u-boot-spl-dtb.hex u-boot.itb \
    u-boot.bin u-boot-raw.bin >SHA256SUMS
)
install -m 0644 "$buildroot_out/images/rootfs.ext4" "$deploy/rootfs.ext4"

gzip -n -9 -c "$linux_out/arch/arm64/boot/Image" >"$generated/Image.gz"
its="$generated/kernel.its"
render_template "$ROOT_DIR/board/pcf4n/linux/kernel.its.in" "$its" \
  IMAGE_GZ "$generated/Image.gz" \
  DTB "$linux_out/arch/arm64/boot/dts/intel/socfpga_agilex5_pcf4n.dtb" \
  KERNEL_LOAD_ADDRESS "$KERNEL_LOAD_ADDRESS"
mkimage -f "$its" "$deploy/kernel.itb"

epoch=$(source_date_epoch)
if [[ -d "$STAGING_DIR/modules/lib/modules" ]]; then
  tar --sort=name --format=posix --numeric-owner --owner=0 --group=0 \
    --mtime="@$epoch" -C "$STAGING_DIR/modules" -cf - lib/modules \
    | zstd -q -f -19 -T1 -o "$deploy/modules.tar.zst"
else
  tar --files-from /dev/null -cf - | zstd -q -f -19 -T1 -o "$deploy/modules.tar.zst"
fi

provision_cmd="$deploy/provision.cmd"
render_template "$ROOT_DIR/board/pcf4n/u-boot/provision.cmd.in" "$provision_cmd" \
  LOCAL_MAC_ADDRESS "$LOCAL_MAC_ADDRESS" \
  MANIFEST_ADDRESS "$MANIFEST_ADDRESS" \
  TFTP_PREFIX "$TFTP_PREFIX" \
  ROOTFS_ADDRESS "$ROOTFS_ADDRESS" \
  KERNEL_ITB_ADDRESS "$KERNEL_ITB_ADDRESS" \
  EMMC_DEVICE "$EMMC_DEVICE" \
  GPT_DISK_UUID "$GPT_DISK_UUID" \
  GPT_KERNEL_UUID "$GPT_KERNEL_UUID" \
  GPT_ROOTFS_UUID "$GPT_ROOTFS_UUID"
mkimage -A arm64 -O linux -T script -C none -n 'PCF4N eMMC provision' \
  -d "$provision_cmd" "$deploy/provision.scr"

kernel_sha=$(sha256sum "$deploy/kernel.itb" | awk '{print $1}')
rootfs_sha=$(sha256sum "$deploy/rootfs.ext4" | awk '{print $1}')
{
  printf 'manifest_version=1\n'
  printf 'kernel_file=kernel.itb\n'
  printf 'kernel_sha256=%s\n' "$kernel_sha"
  printf 'rootfs_file=rootfs.ext4\n'
  printf 'rootfs_sha256=%s\n' "$rootfs_sha"
} >"$deploy/manifest.env"

release_ready=false
if [[ "$QSPI_UBOOT_OFFSET_STATUS" == confirmed && "$LOCAL_MAC_STATUS" == confirmed && "$BASE_IMAGE_DIGEST" =~ ^sha256:[0-9a-f]{64}$ ]]; then
  release_ready=true
fi

jq -n \
  --arg release "$RELEASE_NAME" \
  --arg board "$BOARD" \
  --argjson boardConfigRevision "$BOARD_CONFIG_REVISION" \
  --arg qspiOffset "$QSPI_UBOOT_OFFSET" \
  --arg qspiOffsetStatus "$QSPI_UBOOT_OFFSET_STATUS" \
  --arg macStatus "$LOCAL_MAC_STATUS" \
  --arg baseImage "$BASE_IMAGE" \
  --arg baseImageDigest "$BASE_IMAGE_DIGEST" \
  --arg ubootCommit "$UBOOT_COMMIT" \
  --arg linuxCommit "$LINUX_COMMIT" \
  --arg atfCommit "$ATF_COMMIT" \
  --arg buildrootCommit "$BUILDROOT_COMMIT" \
  --arg buildrootToolchain "$BUILDROOT_TOOLCHAIN" \
  --argjson sourceDateEpoch "$epoch" \
  --argjson releaseReady "$release_ready" \
  '{schemaVersion:1,release:$release,board:$board,boardConfigRevision:$boardConfigRevision,releaseReady:$releaseReady,sourceDateEpoch:$sourceDateEpoch,qspi:{uBootOffset:$qspiOffset,status:$qspiOffsetStatus},mac:{status:$macStatus},container:{baseImage:$baseImage,digest:$baseImageDigest},toolchain:{buildroot:$buildrootToolchain},sources:{uBoot:$ubootCommit,linux:$linuxCommit,armTrustedFirmware:$atfCommit,buildroot:$buildrootCommit}}' \
  >"$OUTPUT_DIR/build-manifest.json"

(
  cd "$OUTPUT_DIR"
  checksum_tmp=$(mktemp "$OUTPUT_DIR/manifest.sha256.XXXXXX")
  find qspi-handoff logic-handoff deploy -type f ! -name manifest.sha256 -print0 \
    | sort -z \
    | xargs -0 sha256sum >"$checksum_tmp"
  mv "$checksum_tmp" manifest.sha256
)
cp "$OUTPUT_DIR/manifest.sha256" "$deploy/manifest.sha256"
find "$handoff" "$logic_handoff" "$deploy" -type f -exec chmod 0644 {} +
chmod 0644 "$OUTPUT_DIR/build-manifest.json" "$OUTPUT_DIR/manifest.sha256"

log "packaged artifacts in $OUTPUT_DIR (releaseReady=$release_ready)"
