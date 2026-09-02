#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=scripts/lib/common.sh
source "$ROOT_DIR/scripts/lib/common.sh"

validate_source_locks

while IFS= read -r -d '' script; do
  bash -n "$script"
done < <(find "$ROOT_DIR/scripts" "$ROOT_DIR/tests" -type f -name '*.sh' -print0)

if command -v shellcheck >/dev/null 2>&1; then
  scripts=()
  while IFS= read -r -d '' script; do
    scripts+=("$script")
  done < <(find "$ROOT_DIR/scripts" "$ROOT_DIR/tests" -type f -name '*.sh' -print0)
  shellcheck -x "${scripts[@]}"
fi

[[ "$QSPI_UBOOT_OFFSET" =~ ^0x[0-9a-fA-F]+$ ]] || die 'QSPI offset is not hexadecimal'
qspi_offset=$((QSPI_UBOOT_OFFSET))
(( qspi_offset % 4096 == 0 )) || die 'QSPI offset must be 4 KiB aligned'
(( qspi_offset + UBOOT_MAX_BYTES <= QSPI_SIZE_BYTES )) || die 'U-Boot allocation exceeds QSPI'

pfg="$ROOT_DIR/board/pcf4n/quartus/qspi_helper.pfg"
grep -q '<settings custom_db_dir="\./" mode="ASX4"/>' "$pfg"
if grep -Eq 'hps="(1|on)"' "$pfg"; then
  die 'FPGA-first PFG enables the HPS-first option'
fi
grep -q 'fixed_s_addr="1" s_addr="0x00300000" e_addr="0x005FFFFF" fixed_e_addr="1" id="UBOOT"' "$pfg"
grep -q 'fixed_s_addr="1" s_addr="0x00600000" e_addr="auto" fixed_e_addr="0" id="P1"' "$pfg"
grep -q 'hps_path="u-boot-spl-dtb.hex"' "$pfg"

[[ "$LOCAL_MAC_ADDRESS" =~ ^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$ ]] || die 'invalid MAC address format'
first_octet=${LOCAL_MAC_ADDRESS%%:*}
first_value=$((16#$first_octet))
(( (first_value & 2) == 2 )) || die 'MAC is not locally administered'
(( (first_value & 1) == 0 )) || die 'MAC is multicast'

grep -q 'u-boot,spl-boot-order = &flash0' "$ROOT_DIR/board/pcf4n/u-boot/socfpga_agilex5_pcf4n-u-boot.dtsi"
grep -q 'stdout-path = "serial1:115200n8"' "$ROOT_DIR/board/pcf4n/u-boot/socfpga_agilex5_pcf4n-u-boot.dtsi"
grep -q 'CONFIG_TARGET_SOCFPGA_AGILEX5_SIMICS=n' "$ROOT_DIR/board/pcf4n/u-boot/pcf4n.config.in"
grep -q 'CONFIG_LOCALVERSION="-pcf4n-emmc4-hs52-dt50-uart1-dt"' "$ROOT_DIR/board/pcf4n/u-boot/pcf4n.config.in"
grep -q 'CONFIG_TIMER=n' "$ROOT_DIR/board/pcf4n/u-boot/pcf4n.config.in"
grep -q 'CONFIG_DESIGNWARE_APB_TIMER=n' "$ROOT_DIR/board/pcf4n/u-boot/pcf4n.config.in"
grep -q 'CONFIG_SPL_SHOW_ERRORS=y' "$ROOT_DIR/board/pcf4n/u-boot/pcf4n.config.in"
grep -q 'CONFIG_SPL_FIT_PRINT=y' "$ROOT_DIR/board/pcf4n/u-boot/pcf4n.config.in"
grep -q 'CONFIG_SPL_RAM_DEVICE=n' "$ROOT_DIR/board/pcf4n/u-boot/pcf4n.config.in"
grep -q 'mailbox direct-mode init failed' "$ROOT_DIR/board/pcf4n/u-boot/patches/0001-socfpga-spl-qspi-diagnostics.patch"
grep -q 'SPL: entering BL31' "$ROOT_DIR/board/pcf4n/u-boot/patches/0002-socfpga-spl-atf-handoff-diagnostics.patch"
grep -q 'BL33 preflight' "$ROOT_DIR/board/pcf4n/atf/patches/0001-agilex5-bl33-preflight-diagnostics.patch"
grep -q '^ATF_CONSOLE_UART=1$' "$ROOT_DIR/config/board.env"
grep -q 'SOCFPGA_UART_CONFIG="$ATF_CONSOLE_UART"' "$ROOT_DIR/scripts/build-atf.sh"
grep -q '^ATF_DEBUG=1$' "$ROOT_DIR/config/board.env"
grep -q '^ATF_LOG_LEVEL=50$' "$ROOT_DIR/config/board.env"
grep -q 'spi-max-frequency = <25000000>' "$ROOT_DIR/board/pcf4n/u-boot/socfpga_agilex5_pcf4n.dts"
grep -q 'spi-rx-bus-width = <1>' "$ROOT_DIR/board/pcf4n/u-boot/socfpga_agilex5_pcf4n.dts"
grep -A4 '^&uart1' "$ROOT_DIR/board/pcf4n/u-boot/socfpga_agilex5_pcf4n.dts" | \
  grep -q 'clock-frequency = <100000000>'
grep -A3 '^&uart1' "$ROOT_DIR/board/pcf4n/u-boot/socfpga_agilex5_pcf4n-u-boot.dtsi" | \
  grep -q 'bootph-all'
if rg -q 'drivers/serial/|PCF4N_EARLY_UART|pcf4n_uart_' \
  "$ROOT_DIR/board/pcf4n/u-boot/patches"; then
  die 'UART1 routing must not patch or bypass the upstream U-Boot serial driver'
fi
if grep -q '/delete-property/ resets' \
  "$ROOT_DIR/board/pcf4n/u-boot/socfpga_agilex5_pcf4n-u-boot.dtsi"; then
  die 'UART1 must retain its standard Reset Manager connection'
fi
if grep -q 'tick-timer' "$ROOT_DIR/board/pcf4n/u-boot/socfpga_agilex5_pcf4n-u-boot.dtsi"; then
  die 'architected-counter build must not select an APB tick-timer'
fi
grep -q 'PCF4N timer/MMC boundary' "$ROOT_DIR/board/pcf4n/u-boot/patches/0006-pcf4n-timer-mmc-boundary-diagnostics.patch"
grep -q 'trace PCF4N peripheral deassert results' "$ROOT_DIR/board/pcf4n/u-boot/patches/0007-pcf4n-reset-deassert-diagnostics.patch"
if find "$ROOT_DIR/board/pcf4n/u-boot/patches" -maxdepth 1 -type f \
  \( -name '000[89]-*.patch' -o -name '001[01]-*.patch' \) -print -quit | \
  grep -q .; then
  die 'stock-driver validation build must not apply eMMC functional patches 0008-0011'
fi
grep -q 'sdhci-caps-mask = <0x00000000 0x0004ff00>' "$ROOT_DIR/board/pcf4n/u-boot/socfpga_agilex5_pcf4n.dts"
grep -q 'sdhci-caps = <0x00000000 0x00003200>' "$ROOT_DIR/board/pcf4n/u-boot/socfpga_agilex5_pcf4n.dts"
grep -q 'max-frequency = <52000000>' "$ROOT_DIR/board/pcf4n/u-boot/socfpga_agilex5_pcf4n.dts"
grep -q 'cdns,phy-dqs-timing-delay-sd-ds = <0x00780000>' "$ROOT_DIR/board/pcf4n/u-boot/socfpga_agilex5_pcf4n.dts"
grep -q 'cdns,phy-gate-lpbk-ctrl-delay-sd-ds = <0x81a40040>' "$ROOT_DIR/board/pcf4n/u-boot/socfpga_agilex5_pcf4n.dts"
grep -q 'cdns,phy-dll-slave-ctrl-sd-ds = <0x00a000fe>' "$ROOT_DIR/board/pcf4n/u-boot/socfpga_agilex5_pcf4n.dts"
grep -q 'cdns,phy-dq-timing-delay-sd-ds = <0x28000001>' "$ROOT_DIR/board/pcf4n/u-boot/socfpga_agilex5_pcf4n.dts"
grep -q 'cdns,phy-dqs-timing-delay-emmc-sdr = <0x00780001>' "$ROOT_DIR/board/pcf4n/u-boot/socfpga_agilex5_pcf4n.dts"
grep -q 'cdns,ctrl-hrs10-lpbk-ctrl-delay-emmc-sdr = <0x00030000>' "$ROOT_DIR/board/pcf4n/u-boot/socfpga_agilex5_pcf4n.dts"
if grep -Eq 'mmc-hs(200|400)' "$ROOT_DIR/board/pcf4n/u-boot/socfpga_agilex5_pcf4n.dts"; then
  die 'PCF4N four-bit eMMC must not enable unvalidated HS200 or eight-bit-only HS400'
fi
grep -q '^EMMC_VCC_UV=3300000$' "$ROOT_DIR/config/board.env"
grep -q '^EMMC_VCCQ_UV=1800000$' "$ROOT_DIR/config/board.env"
grep -q 'vmmc-supply = <&sd_emmc_power>' "$ROOT_DIR/board/pcf4n/u-boot/socfpga_agilex5_pcf4n.dts"
grep -q 'vqmmc-supply = <&emmc_io_1v8_reg>' "$ROOT_DIR/board/pcf4n/u-boot/socfpga_agilex5_pcf4n.dts"
grep -q 'bus-width = <4>' "$ROOT_DIR/board/pcf4n/linux/socfpga_agilex5_pcf4n.dts"
grep -q 'reset-gpios = <&portb 3 GPIO_ACTIVE_LOW>' "$ROOT_DIR/board/pcf4n/linux/socfpga_agilex5_pcf4n.dts"
grep -q 'vmmc-supply = <&sd_emmc_power>' "$ROOT_DIR/board/pcf4n/linux/socfpga_agilex5_pcf4n.dts"
grep -q 'vqmmc-supply = <&emmc_io_1v8_reg>' "$ROOT_DIR/board/pcf4n/linux/socfpga_agilex5_pcf4n.dts"
grep -q 'ethernet-phy@1' "$ROOT_DIR/board/pcf4n/linux/socfpga_agilex5_pcf4n.dts"

while IFS= read -r -d '' test_script; do
  "$test_script"
done < <(find "$ROOT_DIR/tests" -type f -name '*.sh' -perm -111 -print0)

if git -C "$ROOT_DIR" rev-parse --git-dir >/dev/null 2>&1; then
  git -C "$ROOT_DIR" diff --check
fi

if [[ -f "$OUTPUT_DIR/manifest.sha256" ]]; then
  (cd "$OUTPUT_DIR" && sha256sum -c manifest.sha256)
fi

printf 'All static checks passed. QSPI status=%s; MAC status=%s.\n' \
  "$QSPI_UBOOT_OFFSET_STATUS" "$LOCAL_MAC_STATUS"
