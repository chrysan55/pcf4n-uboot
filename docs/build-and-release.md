# Build and release process

## Development build

1. Resolve source refs with `make lock` on a networked host.
2. Build the container with `make image`.
3. Run `make build`.
4. Inspect `output/build-manifest.json` and `output/manifest.sha256`.
5. Run `make check`.

`make package` is idempotent: it clears only its generated `deploy/`,
`qspi-handoff/`, `logic-handoff/`, and temporary package directories before
rebuilding them, then sets every served/handed-off artifact to mode `0644` for
non-root TFTP access. `logic-handoff/` is regenerated as an exact compatibility
mirror rather than being allowed to retain files from an older build.

Development builds are allowed while the QSPI offset is a placeholder. Their
manifest has `releaseReady: false`, and the U-Boot identity contains a clear
development marker.

The container wrapper raises `nofile` to 65536. Docker Desktop and Colima may
otherwise give a container only 1024 descriptors, which is too low for a
parallel Linux build and can fail while compiling the in-tree device-tree
compiler with `Too many open files`.

Build parallelism defaults to two jobs for small cloud builders. A local or CI
machine with more assigned CPUs can override it without editing board data,
for example `JOBS=4 make build-linux`.

## Remote builder

The prepared Tencent Cloud VM has limited CPU/RAM but a large data disk. Its
layout is:

```text
/data/bootstrap   synchronized project
/data/cache       persistent download/compiler cache
/data/artifacts   exported build results
/data/docker      Docker data root
/data/containerd  containerd data root
```

Copy `config/remote.env.example` to `config/remote.env`, verify its settings,
then run `make remote-build`. The helper synchronizes only source-controlled
inputs, builds with low parallelism, and copies `output/` to
`/data/artifacts/bootstrap` on the remote host.

The return transfer excludes `rootfs.ext4` from rsync and copies that 1 GiB
filesystem through SCP into a temporary local file. The helper checks its
SHA-256 against the downloaded manifest before atomically replacing the local
artifact, then runs the complete local check suite. This avoids silent
large-file truncation observed with macOS `openrsync` protocol 29.

The remote host is administered as `root`, and `container.sh` deliberately
preserves the invoking uid so bind-mounted artifacts have predictable
ownership. `build-rootfs.sh` therefore sets `FORCE_UNSAFE_CONFIGURE=1`: this is
the GNU/Autoconf opt-in required by host tools such as GNU tar when configuring
as uid 0. The build itself remains isolated in the disposable container and is
limited to the workspace and persistent cache mounts.

Buildroot uses its official Bootlin AArch64 glibc stable 2025.08-1 external
toolchain. The toolchain URL, version, and hash come from the locked Buildroot
2026.02 source tree. Buildroot's internal ccache is intentionally disabled: on
the low-memory, single-job remote builder, building host CMake, ccache, binutils,
GCC, and glibc locally costs more than it saves for this compact recovery root
filesystem. Downloaded source archives remain persistent in
`/data/cache/bootstrap/buildroot-dl`, and all other component build directories
remain incremental under `/data/bootstrap/.work`. `build-rootfs.sh` hashes the
effective defconfig and clears only the isolated Buildroot output tree when the
configuration changes, preventing stale internal-toolchain objects from being
mixed with a new external-toolchain build.

## Logic-team handoff checklist

- Record the FPGA design revision and `.sof` SHA-256.
- Confirm FPGA-configuration-first boot with
  `set_global_assignment -name HPS_INITIALIZATION "After INIT_DONE"` in the
  final Quartus assignment/report.
- Do not enable the PFG `hps` option. Reject a generated FPGA-first PFG that
  contains `hps="1"`; that is the HPS-first phase-split selection.
- Use the complete final `.sof` with `u-boot-spl-dtb.hex` as its HPS path. Do
  not substitute a baseline/peripheral SOF or core RBF from the HPS-first flow.
- Confirm the Quartus project contains `set_global_assignment -name QSPI_OWNERSHIP HPS`.
- Confirm HPS and HPS-EMIF reference clocks are free-running, stable before
  configuration, and match the frequencies compiled into the Quartus handoff.
- Confirm `HPS_COLD_nRESET` has the required external pull-up and is not driven
  by FPGA/CPLD logic after the SDM releases it.
- Confirm Reset Release IP holds FPGA application logic reset until full user
  mode. If `h2f_gp_out[1]` is used as a later software-ready release, record
  its polarity and consumer logic.
- For every enabled H2F/LWH2F/F2H/F2SDRAM bridge, confirm the documented
  `h2f_reset` connection and any warm-reset handshake/quiesce logic. Record
  unused bridges as intentionally held in reset.
- Confirm the exact `u-boot.itb` QSPI start offset and maximum length.
- The current PFG fixes `UBOOT` at `0x00300000..0x005fffff` (3 MiB) and fixes
  the complete FPGA-first bitstream start at `0x00600000`; reject any FIT that
  exceeds that allocation.
- Confirm that SPL and the final PFG use the same offset.
- Confirm the Macronix flash loader/device selection supported by Quartus.
- Record the SPL banner timestamp and SHA-256 from the exact HEX embedded in
  the final JIC; do not select an older handoff directory by filename alone.
- For the current stock-driver/DTS-clock build, require the SPL and U-Boot
  banners to contain `pcf4n-emmc4-hs52-dt50`; an earlier
  `pcf4n-linuxphy400k-diag`,
  `pcf4n-vccq1v8-init74-diag`,
  `pcf4n-reset100ms-cmd1-phyobs-diag`, `pcf4n-reset100ms-sdprobe-raw-diag`,
  `pcf4n-reset10ms-sdprobe-raw-diag`, `pcf4n-reset10ms-initcmd-diag`,
  `pcf4n-reset10ms-cmd1-diag`, `pcf4n-cmd1-diag`,
  `pcf4n-emmc-reset-diag`,
  `pcf4n-arch-timer-mmc-diag`, `pcf4n-timer-mmc-diag`,
  `pcf4n-arch-timer-diag`,
  `pcf4n-timer2-diag`, `pcf4n-uart1-preserve-diag`,
  `pcf4n-uart1-probe-diag`, `pcf4n-bl33-entry-diag`, `pcf4n-handoff-diag`, or
  plain `2026.01-g<commit>` banner is stale. BL31 preflight output, raw U-Boot
  entry markers, and successful UART1 probe markers must precede the U-Boot
  proper banner. This build intentionally uses the ARMv8 architected counter
  rather than APB timer2.

  For eMMC validation, require `mmc rescan` to return success and `mmc info` to
  report manufacturer ID `15`, product `AJTD4R`, 14.6 GiB capacity and
  `Bus Width: 4-bit`. Read at least one known block and compare it with the
  expected data. Probe GPIO27 RESET_n only if the normal board power-on reset
  remains in question; this build does not execute the DT `mmc-pwrseq` node.

  The candidate models VCC=3.3 V and VCCQ=1.8 V, masks
  `SDHCI_CAN_DO_8BIT`, and enables four-bit MMC HS52 without HS200/HS400. It
  uses the locked Altera eMMC-variant Legacy/SDR PHY tables. It deliberately
  retains the original U-Boot SD-probe fallback and PHY_CTRL handling. The DTS
  masks the incorrect 200 MHz SDHCI base-clock field and substitutes 50 MHz,
  allowing the original divider code to generate the true CIU rate. Require
  final `CLOCK_CONTROL=0x0007` and an approximately 50 MHz measured pin clock.
- Package `output/qspi-handoff/` with the source `build-manifest.json`.
- Preserve the final `.pfg`, `.jic`, map file, and hashes alongside this build.
- Preserve the final `.qsf`, HPS/EMIF handoff, and Quartus fitter report so the
  configuration order, clocks, pins, and reset wiring are auditable.

## Release gates

`make release-check` fails if any of these are true:

- a source commit is unresolved or malformed;
- the Docker base is not digest-pinned;
- QSPI offset status is not `confirmed`;
- the default development MAC remains configured;
- required artifacts or manifests are absent;
- artifact hashes do not match;
- an artifact exceeds its allocated eMMC/QSPI capacity;
- the working tree contains uncommitted changes.

The gate is deliberately stricter than `make check`: bring-up should remain
possible while production mistakes remain hard.
