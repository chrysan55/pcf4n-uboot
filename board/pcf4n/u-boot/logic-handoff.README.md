# PCF4N FPGA-first QSPI handoff

This directory is an exact compatibility mirror of `output/qspi-handoff/`.
Always use files from one build together and verify `SHA256SUMS` before PFG/JIC
generation.

- `u-boot-spl-dtb.hex`: embed in the FPGA bitstream as the HPS SPL image.
- `qspi_helper.pfg`: current FPGA-first PFG. Place the final `pcie_ed.sof` in
  `output_jic/`, keep the remaining handoff files beside the PFG, and run PFG
  from this directory. The generated JIC, RPD, and map are written to
  `output_jic/`.
- `u-boot.bin`: complete FIT payload for the QSPI U-Boot partition. It is
  byte-identical to `u-boot.itb` and is named `.bin` for PFG raw-file input.
- `u-boot.itb`: the same complete FIT under its native name.
- `u-boot-raw.bin`: native U-Boot flat binary for diagnostics only. Do not put
  this file in the QSPI U-Boot partition.
- `bl31.bin`: the TF-A image already embedded inside the FIT, provided only for
  inspection and traceability.

This bring-up build expects Quartus `HPS_INITIALIZATION = After INIT_DONE`,
a PFG output with no HPS-first `hps=on`/`hps="1"` option, QSPI ownership by HPS,
and the FIT payload at QSPI offset `0x00300000`. Its SPL and U-Boot banners
contain `pcf4n-emmc4-hs52-dt50`, and TF-A BL31 logs are routed to HPS
UART1. The
matching BL31 preflight should report BL33 words
`1400000a d503201f 000b9890 58000dd0`; U-Boot proper then emits raw `A` through
`F` markers before its stack is available and bracketed UART1 probe markers
inside `serial_init()`. U-Boot proper uses the ARMv8 architected counter and
prints `[rst:...]`, `[mmc:...]`, and `[phy:...]` markers around every potentially
blocking eMMC reset and Cadence SD6HC initialization step. Reset IDs 6, 15,
and 7 are COMBOPHY, SDMMC OCP, and SDMMC respectively. These markers come from
the already committed early bring-up patches. No additional eMMC functional
driver patch is applied in this stock-driver A/B build.

The device tree still records active-low GPIO27 RESET_n, VCC=3.3 V,
VCCQ=1.8 V, `non-removable`, `no-sd` and `no-sdio`. The locked Cadence driver
does not execute `mmc-pwrseq`, and the locked generic discovery path does not
use `no-sd` to bypass SD probing. This candidate therefore relies on the
normal board power-on reset and on the original CMD8/CMD55 timeout followed by
the eMMC CMD1 fallback.

The stock driver derives SDHCI divider values from the base clock encoded in
CAPABILITIES. Board measurement proved that the unmodified 200 MHz field made
the 50 MHz physical CIU produce a 12.5 MHz HS52 clock. The board device tree
therefore masks that field and supplies 50 MHz (`0x32`) while also masking
`SDHCI_CAN_DO_8BIT`; no driver patch is required. It continues to provide the
Altera eMMC-variant Legacy/SDR timing tables, advertises neither HS200 nor
HS400, and selects four-bit MMC HS52 with a 52 MHz ceiling. A correct run
enumerates CID MID `0x15`, product `AJTD4R`, 14.6 GiB capacity and a four-bit
bus; SDHCI `CLOCK_CONTROL` should be `0x0007` at the final 50 MHz rate.

The offset is still a board-layout placeholder in the release metadata even
though it matches the currently tested PFG layout. Do not treat this package as
a production release until the final PFG map and board configuration are
recorded and the release gates pass.
