# PCF4N hardware constraints

These values were extracted from the reviewed PCF4N schematic. Items marked
“inferred” must be confirmed from BOM, Quartus handoff, or a board probe.

| Function | Board fact | Software consequence |
|---|---|---|
| FPGA | Agilex 5 E-Series `A5ED065BB32AE4S` | Base port on Agilex 5 SoCDK 26.1 |
| Boot mode | MSEL `001`, AS Fast Mode; FPGA fabric is confirmed working before HPS starts | Set `HPS_INITIALIZATION "After INIT_DONE"`, generate an FPGA-configuration-first JIC without `hps=on`/`hps="1"`, and embed the SPL HEX in the complete `.sof` bitstream |
| QSPI | Macronix `MX25U51245GXDI00`, 64 MiB, 1.8 V, x4 | Enable Macronix SPI NOR; use conservative 50 MHz initially |
| QSPI ownership | SPL must read `u-boot.itb` from the SDM-side QSPI | Set Quartus `QSPI_OWNERSHIP HPS`; otherwise the SPL mailbox ownership request is rejected and SPI NOR probing cannot succeed |
| HPS reset release | In FPGA-first mode the SDM holds HPS in reset until the fabric is in user mode, then releases `HPS_COLD_nRESET` to an external pull-up | Do not transfer HPS peripheral reset control to fabric logic; preserve Reset Manager device-tree resets and verify no FPGA/CPLD drive contention on `HPS_COLD_nRESET` |
| FPGA application reset | FPGA sectors do not all enter user mode synchronously | Instantiate Reset Release IP; if software readiness is also required, gate only the application logic with the documented `h2f_gp_out[1]` contract |
| HPS-FPGA bridges | Bridge reset remains under HPS Reset Manager with fabric-side reset/handshake signals | Connect enabled bridge reset inputs to `h2f_reset`, implement traffic quiesce/warm-reset handshake as needed, and hold unused bridges in reset |
| eMMC | eMMC 5.1, 8 GB, 4-bit HPS SDMMC, 1.8 V I/O | Non-removable, 4-bit, 52 MHz; no HS200 in revision 2 |
| eMMC reset | HPS GPIO27, package pin `AG123` | GPIO27 is GPIO1/`portb` line 3; use active-low `mmc-pwrseq-emmc` |
| Ethernet | HPS EMAC2 direct RGMII | Enable `gmac2`; disable unused HPS GMAC nodes |
| PHY | Realtek RTL8211F(D)(I), MDIO2 address 1 | Enable Realtek PHY and set `reg = <1>` under `gmac2/mdio` |
| RGMII delay | Strap does not request an extra 2 ns | Start with `phy-mode = "rgmii"`; validate timing on hardware |
| PHY reset | Board-level `RESET_OTHER_N` | Do not model an unverified U-Boot GPIO reset |
| Clocks | HPS oscillator 25 MHz; PHY oscillator 25 MHz | Preserve 25 MHz oscillator setting |
| UART0 | HPS UART0 connects to the MCU data channel | Enable it, but do not use it for boot logs |
| UART1 | HPS UART1 reaches Type-C during bring-up and later the MCU upgrade channel | Use it as the development console; disable console/getty before production MCU upgrade use |
| Power management | `pw_i2c` uses HPS I2C_EMAC0 | Enable device-tree `i2c2` |
| Optical management | Module 0→I2C0; module 1→I2C_EMAC1; module 2→I3C0; module 3→I3C1 | Enable `i2c0`, `i2c3`, `i3c0`, and `i3c1`; keep legacy I2C on I3C buses at 100 kHz |
| EMAC2 PHY management | Board signal described as GE_PHY I2C, but the logic mapping selects MDIO2 | Keep I2C_EMAC2 (`i2c4`) disabled because its pins are used as MDIO2 |
| USB | Board USB numbering matches the HPS numbering | Preserve USB0→`usb0` and USB1→`usb31`; wait for connector role/VBUS facts before enabling |
| DDR4 | Two 32-bit+ECC groups using `MT40A2G16TBB-062E:F` | Approximately 16 GB inferred; Quartus handoff is authoritative |

The complete controller/address mapping and the distinction between
I2C_EMAC2 and MDIO2 are recorded in [interface-map.md](interface-map.md).
The earlier unconfirmed `CAT24C32@0x50` node was removed from I2C0: that bus is
now confirmed as optical-module 0 management, whose standard management
address may also be `0x50`. A separate board EEPROM must not be described
until its bus and address are confirmed.

## Required hardware validation

Before production release, capture a complete UART log containing at least:

```text
sf probe
sf info
mmc list
mmc dev 0
mmc info
mii device
mdio list
dhcp
ping <server-ip>
```

Capture the boot log from UART1/Type-C and verify that UART0 remains free of
console output. Validate RGMII link at 10/100/1000 Mbps where supported and run repeated large
TFTP transfers with SHA-256 comparison. If CRC or packet errors appear, revisit
`phy-mode`, PHY strap interpretation, and PCB delay rather than masking the
problem in the update script. Use `i2cdetect -l` to verify adapter enumeration,
but do not run blind address scans on power-management or optical-module buses;
use the component-specific safe register list from the hardware team.
