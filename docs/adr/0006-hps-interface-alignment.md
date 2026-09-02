# ADR 0006: Align board interfaces with HPS controller instances

- Status: Accepted
- Date: 2026-08-28

## Context

The first PCF4N device trees were derived from incomplete schematic facts and
enabled only UART0, I2C0, EMAC2, and an 8-bit eMMC. The FPGA logic team then
confirmed the actual board-to-HPS routing for both UARTs, the management buses,
EMAC2, USB numbering, and eMMC reset/data width.

Agilex 5 has five I2C controllers. In the Altera 26.1 device trees, `i2c0` and
`i2c1` are the general-purpose blocks, while `i2c2`, `i2c3`, and `i2c4` are
I2C_EMAC0, I2C_EMAC1, and I2C_EMAC2 respectively. Each I2C_EMAC interface can
alternatively provide the corresponding EMAC MDIO pins.

## Decision

- Preserve hardware numbering with UART0 as `serial0` and UART1 as `serial1`.
  Use UART1 as the development console because it reaches Type-C during
  bring-up and UART0 is an MCU data channel.
- Enable I2C0 for optical module 0, I2C_EMAC0 (`i2c2`) for power management,
  I2C_EMAC1 (`i2c3`) for optical module 1, and I3C0/I3C1 for optical modules
  2/3 in legacy-I2C use.
- Treat “MIDO” as MDIO. Use MDIO2 below EMAC2 for the GE PHY and keep
  I2C_EMAC2 (`i2c4`) disabled because those pin functions are alternatives.
- Keep EMAC0 and EMAC1 disabled and EMAC2 enabled.
- Preserve identity aliases for USB0 and USB1, but do not enable either USB
  controller until port role, VBUS, and over-current wiring are supplied.
- Configure eMMC as non-removable 4-bit/1.8 V HS200 and reset it with HPS
  GPIO27. The FPGA handoff must provide a 200 MHz SD/eMMC SoftPHY clock.
  Since each GPIO bank has 24 lines, GPIO27 is GPIO1/port B line 3.
- Remove the earlier unconfirmed CAT24C32 node from I2C0. Its address `0x50`
  can collide with optical-module management, and no confirmed alternative
  bus/address was provided.
- Do not invent power-controller, optical-module, or USB child nodes without
  part/address/control-signal facts.

## Consequences

- SPL, U-Boot, and Linux development logs move from HPS UART0 to HPS UART1.
- UART1 console/getty must be disabled in the production image before that
  interface carries the MCU upgrade protocol.
- Both bootloader and kernel perform an active-low eMMC reset through GPIO27.
- The I3C controllers are configured with a conservative 100 kHz legacy-I2C
  clock for optical management; module-specific binding remains follow-up.
- The Quartus HPS handoff must select the same controller pin functions. A
  device-tree change cannot override an inconsistent compiled pin mux.
