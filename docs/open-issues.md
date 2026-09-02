# Open issues and confirmation log

## Blocking production release

- [ ] Logic team: provide the final JIC/PFG QSPI layout.
- [ ] Logic team: confirm from the generated map that `u-boot.itb` occupies the
  fixed `0x00300000..0x005fffff` allocation and P1 starts at `0x00600000`.
- [x] Logic team/bring-up: FPGA-configuration-first mode selected; FPGA fabric
  reaches user mode before HPS startup.
- [ ] Logic team: provide the final `.qsf` or fitter-report evidence for
  `HPS_INITIALIZATION = After INIT_DONE`, and a generated PFG with no `hps="1"`
  HPS-first selection.
- [ ] Logic team: provide the production `.qsf`/`.sof` evidence that QSPI
  ownership is assigned to HPS.
- [ ] Hardware/logic teams: confirm the HPS and HPS-EMIF reference clocks are
  free-running and match the final handoff; confirm `HPS_COLD_nRESET` has an
  external pull-up and no FPGA/CPLD drive contention.
- [ ] Logic team: confirm Reset Release IP is instantiated and document the
  FPGA application-reset release. If HPS-FPGA bridges are enabled, document
  each `h2f_reset` connection and warm-reset handshake/quiesce behavior.
- [x] Board bring-up: identify the installed eMMC through a live CID exchange.
  CMD2 returned manufacturer ID `0x15` (Samsung) and product name `AJTD4R`;
  the working alternate build reports 14.6 GiB (nominal 16 GB). The exact
  ordering code should still be confirmed from the BOM/marking.
- [ ] Hardware team: confirm usable DDR capacity from the Quartus handoff.
- [x] Board bring-up: with QSPI ownership assigned to HPS, SPL reads the FIT
  from SPI and verifies the configuration, BL31, U-Boot, and FDT CRCs.
- [x] Board bring-up: the UART1 BL31-handoff diagnostic pair reaches BL31 EL3
  exit with BL33=`0x80200000`, SPSR=`0x3c9`, after all SPL and BL31 checks pass.
- [x] Board bring-up: the BL33-entry diagnostic passed ERET, SError unmasking,
  stack/FDT/CPU/driver-model setup, then stopped after `[serial>]`. Its BL31
  preflight matched the packaged U-Boot image; DMI0/DMI1 and UART1 firewall
  values allowed normal-world access.
- [x] Board bring-up: the UART1-probe diagnostic reached `[probe>]` after
  successful DT address and 100 MHz clock resolution, then stopped before the
  reset result marker. This isolates reset acquisition/deassertion.
- [x] Board bring-up: the UART1-reset-preserve diagnostic passed both the
  pre-relocation and relocated UART1 probes, printed the U-Boot proper banner,
  enumerated 38 devices, and reached MMC initialization.
- [x] Board software: the following `Could not initialize timer (err -19)` was
  traced to all four APB timer nodes remaining disabled, despite the timer
  uclass and DesignWare driver being enabled. This is not yet an eMMC error.
- [x] Board bring-up: the `pcf4n-timer2-diag` pair enters timer2 probe during
  MMC initialization, then its last line is `Can't get reset: -2`. `-ENOENT`
  is expected because that diagnostic deliberately removed the timer reset
  property; the line neither proves probe completion nor identifies the hang.
- [x] Board bring-up: the `pcf4n-timer-mmc-diag` pair showed timer2 MMIO and a
  reported 100 MHz clock, but its current-value register remained `0 -> 0` and
  probe returned `-ETIMEDOUT` (`-110`). The counter is held reset; the former
  claim that SPL releases `L4SYSTIMER0_RESET` on Agilex 5 was incorrect.
- [x] Board bring-up: the `pcf4n-arch-timer-mmc-diag` HEX/ITB pair reaches the
  U-Boot proper command prompt. Disabling the DM timer path makes reset waits
  use `CNTPCT_EL0/CNTFRQ_EL0` and removes the fatal APB timer2 dependency.
- [ ] Board bring-up: save the complete successful `MMC:` marker sequence and
  confirm that the expected eMMC device is enumerated. Reaching the prompt
  confirms the timer fix, but does not by itself validate repeated 4-bit eMMC
  I/O.
- [x] Board bring-up: validate the `pcf4n-emmc-reset-diag` pair and capture
  `[mmc:pwrseq-get=0][mmc:pwrseq>][mmc:pwrseq=0]` before PHY initialization;
  the sequence completes, but eMMC CMD1 still times out.
- [x] Board bring-up: validate the `pcf4n-reset100ms-sdprobe-raw-diag` pair.
  After the board power issue was corrected, CMD8 and CMD55 still returned
  `INT_STATUS=0x000a8000`, response `0x11111111`, and `-ECOMM`; generic U-Boot
  therefore never selected its timeout-only eMMC fallback.
- [x] Board bring-up: validate the
  `pcf4n-reset100ms-cmd1-phyobs-diag` pair. The scope capture contains exactly
  one 48-clock host CMD1 frame with argument zero and no eMMC R3 response;
  Combo PHY reports `cmd-underrun=1` and the SDHCI response is the invalid
  repeated value `0x11111111`.
- [x] Hardware/board bring-up: confirm eMMC VCC is 3.3 V and fixed VCCQ is
  1.8 V. U-Boot and Linux now model both rails explicitly.
- [x] Board bring-up: manually apply the Linux-style Legacy PHY tuple and a
  true 400 kHz card clock derived from the 50 MHz CIU source. CMD1 then returns
  `0x40ff8080` followed by ready OCR `0xc0ff8080`; CMD2/CMD3/CMD9/CMD7 and
  CMD13 complete, and CMD13 reports transfer state with ready-for-data set.
  This proves the eMMC, wiring, power rails, reset sequence and command receive
  path. The old `0x11111111` result came from the U-Boot static Legacy PHY/
  clock setup, not a missing or damaged eMMC.
- [ ] Board bring-up: validate the new `pcf4n-emmc4-hs52-dt50` HEX/ITB pair.
  Require successful `mmc rescan`, Samsung CID/product `AJTD4R`, 14.6 GiB
  capacity, `Bus Width: 4-bit`, and a successful block read. The candidate
  masks `SDHCI_CAN_DO_8BIT`, advertises MMC HS52 but not HS200/HS400, and uses
  the Altera eMMC-variant Legacy/SDR PHY tables. It applies none of the former
  eMMC functional patches 0008--0011. The DTS masks the incorrect 200 MHz
  SDHCI base-clock field and substitutes the measured 50 MHz CIU rate; require
  `CLOCK_CONTROL=0x0007` and an approximately 50 MHz pin clock in HS52 mode.
- [ ] Board software: after locating the MMC failure, remove the UART1
  reset-preserve workaround and diagnostic prints. These are bring-up aids,
  not FPGA-first requirements.
- [x] Board bring-up: UART1/Type-C development console prints the SPL banner,
  clock summary, and DDR calibration results.
- [ ] Board bring-up: save a complete successful boot log and confirm UART0
  remains free of boot output on the MCU data channel.
- [ ] Product firmware: disable the UART1 console/getty before UART1 is handed
  to the MCU firmware-upgrade protocol.
- [ ] Board bring-up: validate EMAC2/RTL8211F link and RGMII timing.
- [x] Board bring-up: validate the eMMC reset path on HPS GPIO27 (pin `AG123`).
- [ ] Board bring-up: validate 4-bit MMC HS52 operation under repeated reads
  and writes; the 50 MHz CIU clock is the board's physical maximum.
- [ ] Hardware/logic teams: provide power-controller and optical-module device
  addresses plus module-presence/reset/interrupt GPIOs so child nodes can be
  added to the enabled management buses.
- [ ] Hardware team: confirm USB0/USB1 connector roles, VBUS control, and
  over-current polarity before enabling either USB controller.
- [ ] Manufacturing: confirm whether a separate board EEPROM exists and, if
  so, provide its controller and address; the old unverified I2C0 `0x50` node
  conflicts with that bus's confirmed optical-module role and was removed.
- [ ] Security: select Secure Boot, FIT signing, key custody, and anti-rollback
  requirements.

## Non-blocking follow-up

- [ ] Add an A/B update layout after the first end-to-end boot succeeds.
- [ ] Decide whether HTTP replaces TFTP for easier infrastructure operation.
- [ ] Add DPU kernel drivers, firmware, and user-space packages when interfaces
  are delivered by the logic team.
- [ ] Add remote UART/JTAG/power control to the build-validation pipeline.

## Confirmation template

Record new facts in this file and update the matching ADR/config in the same
commit:

```text
Date:
Owner/team:
Board revision:
Fact confirmed:
Evidence (document/log/hash):
Configuration or ADR updated:
```
