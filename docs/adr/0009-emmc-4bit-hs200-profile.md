# ADR 0009: Four-bit, 1.8 V eMMC HS200 profile

- Status: Proposed for board validation
- Date: 2026-09-02
- Supersedes: ADR 0008 operating-speed policy

## Context

The installed Samsung `AJTD4R` has been confirmed to support a four-bit bus,
1.8 V signaling, and MMC HS200. PCF4N routes DAT0..DAT3, powers the device core
from fixed 3.3 V, and powers VCCQ from fixed 1.8 V. HS200 supports four-bit
operation; HS400 is excluded because it requires an eight-bit data bus.

The first stable board profile intentionally used HS52. Its device tree masked
the production SD6HC 200 MHz base-clock field and substituted 50 MHz because
the FPGA handoff supplied a 50 MHz SoftPHY clock. That workaround is not valid
for HS200. HS200 requires the clock advertised through SRS16.BSDCLK and the
actual FPGA/HPS SoftPHY clock to agree at 200 MHz.

## Decision

- Keep the locked Altera U-Boot and TF-A source trees unmodified.
- Describe the eMMC as `bus-width = <4>`, `mmc-hs200-1_8v`, fixed VCC=3.3 V,
  fixed VCCQ=1.8 V, non-removable, and eMMC-only.
- Set `max-frequency = <200000000>` in both U-Boot and Linux board device
  trees.
- Preserve the production SD6HC SRS16.BSDCLK value of 200 MHz. Remove the old
  `sdhci-caps = <0 0x3200>` base-clock substitution and mask only
  `SDHCI_CAN_DO_8BIT` in U-Boot.
- Enable MMC HS200 and its tuning support in U-Boot and SPL. Disable SD UHS
  modes and all HS400 variants so mode selection cannot exceed the physical
  four-bit interface.
- Add the Altera Agilex 5 eMMC HS200 PHY/controller profile to the U-Boot board
  device tree. Runtime CMD21 tuning selects the final read sampling point.
- Require the FPGA HPS handoff to set the SD/eMMC SoftPHY clock to 200 MHz.
  Software capability data must not be used to conceal a 50 MHz handoff.

## Validation gate

Before loading the HS200 HEX/ITB pair, the logic team must provide a matching
SOF/handoff or clock report showing a 200 MHz SD/eMMC SoftPHY clock. The SPL
clock summary must report:

```text
SDMMC         200000 kHz
```

Then require:

```text
mmc rescan
mmc info
```

to identify `AJTD4R`, report a four-bit bus and a 200 MHz bus speed. At the
final rate, SDHCI `CLOCK_CONTROL` should encode divide-by-one (`0x0007`). Save
the CMD21 tuning result and perform repeated read verification plus controlled
write/read comparison in a disposable partition. Any tuning failure, CRC
error, or clock-summary mismatch blocks HS200 acceptance and requires fallback
to the validated ADR 0008 HS52 profile rather than a driver patch.
