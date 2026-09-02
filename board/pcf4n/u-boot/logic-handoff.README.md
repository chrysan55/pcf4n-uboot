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
contain `pcf4n-emmc4-hs200-uart1`. TF-A selects HPS UART1 through the
`SOCFPGA_UART_CONFIG=1` build setting; SPL and U-Boot select `serial1` through
the board device tree. The upstream NS16550 driver and UART1 Reset Manager
description are unchanged. U-Boot proper uses the ARMv8 architected counter.
TF-A and U-Boot are built from the locked upstream revisions without any
downstream source patches or bring-up markers.

The device tree still records active-low GPIO27 RESET_n, VCC=3.3 V,
VCCQ=1.8 V, `non-removable`, `no-sd` and `no-sdio`. The locked Cadence driver
does not execute `mmc-pwrseq`, and the locked generic discovery path does not
use `no-sd` to bypass SD probing. This candidate therefore relies on the
normal board power-on reset and on the original CMD8/CMD55 timeout followed by
the eMMC CMD1 fallback.

The installed `AJTD4R` has been confirmed to support four-bit, 1.8 V HS200.
The board device tree therefore advertises HS200, keeps HS400 disabled, and
masks only the controller's unconnected eight-bit capability. It preserves the
production SD6HC 200 MHz base-clock field and provides Altera's
Legacy/SDR/HS200 PHY profiles; no driver patch is required. The final SOF/HPS
handoff must provide a matching 200 MHz SoftPHY clock. Reject this package if
the SPL summary still reports `SDMMC 50000 kHz`. A correct run reports
`SDMMC 200000 kHz`, enumerates CID MID `0x15`, product `AJTD4R`, 14.6 GiB
capacity and a four-bit bus, completes CMD21 tuning, and uses
`CLOCK_CONTROL=0x0007` at the final 200 MHz rate.

The offset is still a board-layout placeholder in the release metadata even
though it matches the currently tested PFG layout. Do not treat this package as
a production release until the final PFG map and board configuration are
recorded and the release gates pass.
