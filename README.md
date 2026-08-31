# bootstrap

`bootstrap` builds the HPS-side boot artifacts for the PCF4N Agilex 5 DPU
card. The intended boot path is:

```text
SDM configures FPGA from QSPI (FPGA-first)
  -> SDM releases HPS and starts embedded SPL
  -> SPL reads ATF BL31 + U-Boot ITB from QSPI
  -> DHCP/TFTP -> verify -> write eMMC -> boot FIT
```

The FPGA fabric image and final `.jic` are owned by the logic team. This
repository produces the inputs that cross that boundary, plus the kernel and
root filesystem installed on eMMC.

> [!WARNING]
> `config/board.env` currently contains the official development-kit QSPI
> offset as an explicit **placeholder**. Development artifacts may be built,
> but `make release-check` intentionally fails until the logic team confirms
> the board's actual JIC layout.

## Repository map

- `docs/architecture.md` - end-to-end design and failure behavior.
- `docs/hardware.md` - facts extracted from the PCF4N schematic and software
  consequences.
- `docs/interface-map.md` - logic-team-confirmed board names to HPS controller
  and device-tree mappings.
- `docs/adr/` - durable architecture decisions and their rationale.
- `config/` - release refs, immutable source lock, board parameters, and
  remote-build example.
- `board/pcf4n/` - U-Boot/Linux device trees, configuration fragments,
  Buildroot configuration, and the provisioning script.
- `scripts/` - source acquisition, component builds, packaging, verification,
  and remote build helpers.
- `ops/xray/` - credential-free service definition and secure builder setup
  notes for GitHub egress through Xray.

## Quick start

The supported path uses Docker so host package versions do not leak into the
result:

```bash
cp config/remote.env.example config/remote.env  # only for remote builds
make image
make lock
make build
make package
make check
```

On the prepared Tencent Cloud builder:

```bash
make remote-build
```

Build state is written under `.work/`; deliverables are written under
`output/`. Both are intentionally ignored by Git.

## Expected outputs

```text
output/
  build-manifest.json
  manifest.sha256
  qspi-handoff/
    bl31.bin
    u-boot.bin
    u-boot-raw.bin
    u-boot.itb
    u-boot-spl-dtb.hex
  logic-handoff/  # exact compatibility mirror with README and SHA256SUMS
  deploy/
    kernel.itb
    rootfs.ext4
    modules.tar.zst
    provision.cmd
    provision.scr
    manifest.env
    manifest.sha256
```

`output/deploy/` is the TFTP tree. The default U-Boot boot command requests
`pcf4n/provision.scr`; publish the contents of `output/deploy/` beneath that
directory on the TFTP server.

## Current limitations

- The QSPI U-Boot offset is not board-confirmed.
- The FPGA project must select FPGA-first mode and grant QSPI ownership to HPS;
  the final `.sof`/`.pfg` evidence is still owned by the logic team.
- The exact eMMC part number and DDR size still need hardware confirmation.
- Image hashes detect corruption, but TFTP and an unsigned manifest do not
  establish authenticity. Secure Boot and signed update metadata are future
  work.
- Hardware validation requires the early UART1/Type-C console or JTAG access
  to a PCF4N card.

See `docs/open-issues.md` before treating any artifact as production-ready.
