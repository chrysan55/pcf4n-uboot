#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=/dev/null
source "$ROOT_DIR/config/board.env"

[[ "$BOARD_CONFIG_REVISION" == 3 ]]
[[ "$HPS_DATA_UART" == 0 ]]
[[ "$HPS_UPGRADE_UART" == 1 ]]
[[ "$HPS_DEVELOPMENT_CONSOLE_UART" == 1 ]]
[[ "$HPS_POWER_I2C_CONTROLLER" == 2 ]]
[[ "$HPS_OPTICAL0_I2C_CONTROLLER" == 0 ]]
[[ "$HPS_OPTICAL1_I2C_CONTROLLER" == 3 ]]
[[ "$HPS_OPTICAL2_I3C_CONTROLLER" == 0 ]]
[[ "$HPS_OPTICAL3_I3C_CONTROLLER" == 1 ]]
[[ "$HPS_ETHERNET_EMAC" == 2 ]]
[[ "$HPS_ETHERNET_MDIO" == 2 ]]
[[ "$HPS_USB0_CONTROLLER" == 0 ]]
[[ "$HPS_USB1_CONTROLLER" == 1 ]]
[[ "$EMMC_BUS_WIDTH" == 4 ]]
[[ "$EMMC_MAX_FREQUENCY" == 52000000 ]]
[[ "$EMMC_RESET_GPIO_GLOBAL" == 27 ]]
[[ "$EMMC_RESET_GPIO_BANK" == 1 ]]
[[ "$EMMC_RESET_GPIO_OFFSET" == 3 ]]
[[ "$EMMC_RESET_PACKAGE_PIN" == AG123 ]]
[[ "$ROOTFS_PARTITION_BYTES" == 1073741824 ]]
[[ "$QSPI_UBOOT_OFFSET" == 0x00300000 ]]
[[ "$UBOOT_MAX_BYTES" == 3145728 ]]
[[ "$QSPI_UBOOT_OFFSET_STATUS" == placeholder || "$QSPI_UBOOT_OFFSET_STATUS" == confirmed ]]
[[ "$LOCAL_MAC_STATUS" == placeholder || "$LOCAL_MAC_STATUS" == confirmed ]]
