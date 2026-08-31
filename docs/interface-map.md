# PCF4N HPS interface map

This is the software-facing record of the interface alignment supplied by the
FPGA logic team on 2026-08-28. The HPS controller names below are the names
used by the Altera 26.1 U-Boot and Linux device trees locked by this project.

## UART

| Board role | HPS block | Device-tree node | MMIO | Software use |
|---|---|---|---:|---|
| MCU data channel | UART0 | `uart0` / `serial0` | `0x10c02000` | Enabled; no console output |
| Type-C during bring-up; later MCU upgrade | UART1 | `uart1` / `serial1` | `0x10c02100` | Development boot console at 115200 8N1 |

Both aliases preserve the HPS hardware numbering. `chosen/stdout-path` selects
`serial1` for development so the UART0 data protocol is not contaminated by
SPL, U-Boot, or Linux log text. Before UART1 is connected to the MCU upgrade
channel in production, remove the UART1 console/getty or define a separate
manufacturing image policy.

## I2C, I3C, and MDIO

Agilex 5 contains two general-purpose I2C controllers followed by three
I2C_EMAC controllers. The locked device trees expose them as consecutive
`i2c0` through `i2c4` nodes:

| Board role | HPS interface | DT node | MMIO | State |
|---|---|---|---:|---|
| Optical module 0 management | I2C0 | `i2c0` | `0x10c02800` | Enabled |
| Unassigned | I2C1 | `i2c1` | `0x10c02900` | Disabled |
| `pw_i2c` power management | I2C_EMAC0 | `i2c2` | `0x10c02a00` | Enabled |
| Optical module 1 management | I2C_EMAC1 | `i2c3` | `0x10c02b00` | Enabled |
| GE PHY management pins | I2C_EMAC2 / MDIO2 | `i2c4` or `gmac2/mdio` | `0x10c02c00` for I2C mode | MDIO2 selected; `i2c4` disabled |
| Optical module 2 management | I3C0 in legacy-I2C use | `i3c0` | `0x10da0000` | Enabled, 100 kHz I2C clock |
| Optical module 3 management | I3C1 in legacy-I2C use | `i3c1` | `0x10da1000` | Enabled, 100 kHz I2C clock |

The logic-team phrase “GE_PHY i2c ... 走MIDO” is interpreted as MDIO (the
standard signal name; `MIDO` is a transposition). I2C_EMAC2 and MDIO2 are
alternate uses of the corresponding pins, so they must not both be enabled.
The RTL8211 PHY therefore remains an MDIO child of `gmac2` at address 1.

Only controller routing is confirmed. Power-controller identities and
addresses, optical-module control GPIOs, and hot-plug properties are still
missing, so the device trees intentionally do not invent child-device nodes.

## Ethernet and USB

| Board name | HPS block | DT node | State |
|---|---|---|---|
| GE | EMAC2 | `gmac2` | Enabled; RGMII and MDIO2 |
| USB0 | USB0 | `usb0` | Numbering recorded; disabled pending role/VBUS data |
| USB1 | USB1/USB 3.1 | `usb31` | Numbering recorded; disabled pending role/VBUS data |

`gmac0` and `gmac1` remain disabled. USB aliases preserve the logic/HPS
identity mapping, but controller activation needs host/device role, VBUS power
control, and over-current polarity.

## eMMC

| Property | Confirmed value | Device-tree representation |
|---|---|---|
| Data width | 4 bit | `bus-width = <4>` |
| Reset | HPS GPIO27, package pin `AG123` | `GPIO1/portb[3]`, active-low `mmc-pwrseq-emmc` |
| Initial timing policy | 52 MHz high-speed maximum | `cap-mmc-highspeed`, no HS200/HS400 |

Each Agilex 5 GPIO bank has 24 lines. Consequently global HPS GPIO27 maps to
GPIO bank 1 line `27 - 24 = 3`, expressed as `<&portb 3 GPIO_ACTIVE_LOW>`.

## Source of truth and limits

This mapping is authoritative for board-to-HPS peripheral selection. The
Quartus HPS handoff remains authoritative for pin mux, electrical settings,
DDR initialization, and routing peripherals to HPS I/O versus FPGA fabric.
Software cannot correct a mismatched handoff.

## Reference documents

- [Agilex 5 Hard Processor System Technical Reference
  Manual](https://cdrdv2-public.intel.com/814347/mnl-814346-814347.pdf)
- [Agilex 5 Pin Connection Guidelines: HPS I2C_EMAC and MDIO
  Pins](https://docs.altera.com/r/docs/813266/current/pin-connection-guidelines/hps-i2c_emac-and-mdio-pins)
- [Agilex 5 HPS Component Reference: Pin Mux and
  Peripherals](https://docs.altera.com/r/docs/813752/26.1/hard-processor-system-component-reference-manual-agilextm-5-socs/pin-mux-and-peripherals?contentId=ekHxKl7jeysWcINdvjI_qw)
