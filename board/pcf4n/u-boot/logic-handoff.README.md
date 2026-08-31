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

This diagnostic build expects Quartus `HPS_INITIALIZATION = After INIT_DONE`,
a PFG output with no HPS-first `hps=on`/`hps="1"` option, QSPI ownership by HPS,
and the FIT payload at QSPI offset `0x00300000`. Its SPL and U-Boot banners
contain `pcf4n-arch-timer-mmc-diag`, and TF-A BL31 logs are routed to HPS UART1. The
matching BL31 preflight should report BL33 words
`1400000a d503201f 000b9890 58000dd0`; U-Boot proper then emits raw `A` through
`F` markers before its stack is available and bracketed UART1 probe markers
inside `serial_init()`. U-Boot proper uses the ARMv8 architected counter and
prints `[rst:...]`, `[mmc:...]`, and `[phy:...]` markers around every potentially
blocking eMMC reset and Cadence SD6HC initialization step. Reset IDs 6, 15,
and 7 are COMBOPHY, SDMMC OCP, and SDMMC respectively. The preceding APB
timer2 diagnostic proved that timer2 remained reset; this package removes that
broken timebase so the first later MMC marker is meaningful.

The offset is still a board-layout placeholder in the release metadata even
though it matches the currently tested PFG layout. Do not treat this package as
a production release until the final PFG map and board configuration are
recorded and the release gates pass.
