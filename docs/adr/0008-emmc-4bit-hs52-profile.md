# ADR 0008: Four-bit eMMC HS52 profile

- Status: Superseded by ADR 0009 after successful HS52 bring-up
- Date: 2026-09-02

## Context

PCF4N routes only DAT0..DAT3 between the Agilex 5 HPS SDMMC controller and the
soldered eMMC. Live identification reports Samsung manufacturer ID `0x15`,
product name `AJTD4R`, MMC 5.1, 14.6 GiB capacity and a four-bit bus. The part
is therefore nominally 16 GB; the exact ordering code remains a BOM check.

Altera's locked `socfpga_agilex5_socdk_emmc.dts` describes the development-kit
eMMC as eight-bit and advertises HS200 and HS400. It also forces SDHCI
capability bit 18 (`SDHCI_CAN_DO_8BIT`). Copying that node unchanged to PCF4N
can select an impossible eight-bit transfer or an unvalidated tuned mode.

The alternate board build successfully enumerates the same eMMC after changing
the bus to four bits, masking the forced eight-bit capability and disabling
HS200/HS400. It operates in MMC HS52 mode. Separately, PCF4N register-level
testing proved that SD6HC card-clock division must use the named 50 MHz CIU
clock rather than the 200 MHz base-clock value exposed through capabilities.

## Decision

- Keep the PCF4N device-tree root and its FPGA-first QSPI boot order. Do not
  include the complete SoCDK eMMC DTS because it also carries SoCDK-specific
  console, storage, Ethernet and peripheral choices.
- Set `bus-width = <4>`, `cap-mmc-highspeed` and
  `max-frequency = <52000000>`. The protocol mode is MMC HS52; the physical
  clock is limited to 50 MHz by the CIU source.
- Do not advertise `mmc-hs200-1_8v` or `mmc-hs400-1_8v`. HS200 tuning has not
  passed and HS400 requires an eight-bit bus in this U-Boot implementation.
- Set `sdhci-caps-mask = <0 0x00040000>` and `sdhci-caps = <0 0>` in the
  U-Boot board node. This explicitly clears `SDHCI_CAN_DO_8BIT` even if the
  controller macro advertises it.
- Port only the Legacy and eMMC-SDR PHY properties from the locked Altera
  eMMC-variant DTS. HS200 and HS400 timing properties are intentionally not
  copied because the associated modes are disabled.
- Retain VCC=3.3 V, VCCQ=1.8 V and the GPIO27 reset description in the device
  tree.
- First validate an A/B candidate using the locked U-Boot driver without the
  former patches 0008--0011. In this candidate `mmc-pwrseq` and `no-sd` remain
  descriptive DT properties but do not alter the original driver flow; the
  named-CIU correction and PHY_CTRL phony-DQS clearing are also absent.
- Restore only the smallest driver correction demonstrated necessary by the
  stock-driver board result.
- The stock-driver result enumerated and read eMMC successfully, but
  `CLOCK_CONTROL=0x0207` and oscilloscope measurement proved that the physical
  HS52 clock was only 12.5 MHz. Keep the driver unmodified and override the
  SDHCI base-clock capability in the board DTS: mask `0x0004ff00` (the 8-bit
  capability plus base-clock field) and supply `0x00003200` (50 MHz).

## Selected timing values

```text
Legacy/identification:
  DQS timing       0x00780000
  gate/loopback    0x81a40040
  DLL slave        0x00a000fe
  DQ timing        0x28000001

MMC HS/52 SDR:
  DQS timing       0x00780001
  gate/loopback    0x81a40040
  DLL slave        0x00000000
  DQ timing        0x10000001
  HRS09            0x0001800c
  HRS10            0x00030000
  HRS16            0x00000101
  HRS07            0x000a0001
```

Properties not listed above retain the locked U-Boot driver's defaults.

## Validation gate

The change remains proposed until the new HEX/ITB pair reports all of the
following on PCF4N:

```text
Manufacturer ID: 15
Name: AJTD4R
Capacity: 14.6 GiB
Bus Width: 4-bit
```

The build must apply no eMMC functional patches after the existing bring-up
patch 0007. Require successful `mmc rescan`, the identity below,
`CLOCK_CONTROL=0x0007`, and an approximately 50 MHz measured clock in HS52
mode. Use `mmc info` for the board-level enumeration gate.

Then run repeated aligned reads, non-destructive hash comparisons and a
write/read/erase test confined to an explicitly disposable eMMC range. Do not
enable HS200 or HS400 as a workaround for a failure at MMC HS52.
