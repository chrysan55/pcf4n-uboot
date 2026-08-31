# System architecture

## Objective

PCF4N is an Agilex 5 FPGA DPU card. This project owns only the HPS software
boot chain. FPGA design files are delivered by the logic team and are not
built here.

The first implementation is a deterministic recovery/provisioning path. It is
optimized for bring-up and traceability, not yet for field-update security.

## Boot and provisioning sequence

```text
QSPI flash
  full FPGA-first configuration (logic-team SOF/JIC)
    -> SDM configures FPGA fabric and HPS I/O
    -> SDM starts SPL (u-boot-spl-dtb.hex embedded in the bitstream)
    -> initialize HPS DDR and QSPI
    -> load u-boot.itb from QSPI_UBOOT_OFFSET
    -> hand off through ATF BL31
  U-Boot proper
    -> set the configured locally-administered MAC
    -> DHCP, retaining the DHCP/TFTP next-server address
    -> download pcf4n/provision.scr
    -> download and import manifest.env
    -> download rootfs.ext4 and kernel.itb to DDR
    -> verify SHA-256 for both files
    -> initialize eMMC and write the deterministic GPT
    -> write rootfs first
    -> write kernel last
    -> boot the verified kernel.itb already in DDR
```

Any failed network, hash, GPT, eMMC, or boot command leaves the operator at the
U-Boot prompt. It must not fall through to an unverified or partly overwritten
system.

## Artifact ownership boundary

This repository hands these files to the logic team:

- `u-boot-spl-dtb.hex`: HPS first-stage loader embedded in the FPGA bitstream.
- `u-boot.itb`: U-Boot proper stored at the agreed QSPI offset.
- `u-boot.bin`: byte-identical `.bin` alias of `u-boot.itb` for PFG raw-data
  import; despite its suffix it remains a FIT image.
- `u-boot-raw.bin`: native flat U-Boot build output retained for diagnostics;
  it is not a valid payload for the current `SPL_LOAD_FIT` boot flow.
- `bl31.bin`: provenance/debug artifact used while constructing U-Boot ITB.

The logic team owns:

- Quartus project and handoff configuration.
- `.sof`, core `.rbf`, flash loader selection, `.pfg`, and final `.jic`.
- The authoritative QSPI partition map and confirmation that the design is
  FPGA-configuration-first with QSPI ownership assigned to HPS.

The handoff is blocked for production until `QSPI_UBOOT_OFFSET_STATUS` is
`confirmed` and the offset is recorded in ADR 0003.

## eMMC layout

The provisioning script creates a GPT on eMMC:

| Partition | Start | Size | Content |
|---|---:|---:|---|
| `kernel` | 1 MiB | 64 MiB | Raw `kernel.itb` |
| `rootfs` | 65 MiB | 1024 MiB | ext4 filesystem image |

The kernel partition is deliberately written last. A failed rootfs transfer
therefore cannot replace a known kernel with a new one. The current failure
policy still stops at U-Boot; automatic rollback is not implemented.

The root filesystem is selected with the fixed GPT partition UUID in
`config/board.env`, avoiding dependence on Linux's eMMC enumeration order.

## Kernel FIT

`kernel.itb` contains only:

- a reproducibly gzip-compressed `Image`;
- the PCF4N Linux DTB;
- SHA-256 hash nodes for both;
- one `conf-pcf4n` configuration.

It intentionally contains no FPGA RBF. Fabric lifecycle and DPU firmware are
out of scope until the logic/software interface is specified.

## Reproducibility model

- Component release refs follow Altera 26.1's validated combination.
- `config/sources.lock` records full immutable commit IDs.
- Docker fixes the host distribution and required tools.
- The locked Buildroot release selects the hash-verified Bootlin AArch64 glibc
  stable 2025.08-1 target toolchain.
- Build timestamps use `SOURCE_DATE_EPOCH` derived from the source lock.
- gzip uses `-n`; tar file order and metadata are normalized.
- `build-manifest.json` records source commits, configuration state, container,
  and target-toolchain identity; `manifest.sha256` records artifact hashes.

Reproducibility is only complete after the Docker base image is pinned by
digest and all source commits are resolved. `make release-check` enforces both.

## Security model

The first version detects accidental corruption with SHA-256. It does not yet
authenticate TFTP, `manifest.env`, or `provision.scr`; an attacker able to
alter the TFTP response can replace both the artifacts and their hashes.

Production must add at least signed FIT configurations and authenticated,
anti-rollback update metadata. Secure Boot ownership must be agreed with the
logic/security teams because keys affect the complete FPGA/HPS image chain.
