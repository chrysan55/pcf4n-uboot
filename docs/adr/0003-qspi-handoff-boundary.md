# ADR 0003: Logic team owns final JIC and QSPI layout

- Status: Accepted with unresolved parameter
- Date: 2026-08-26

## Context

Quartus combines the FPGA `.sof`, HPS SPL, U-Boot binary, flash device, and
partition layout into the final JIC. This HPS project does not own the FPGA
design. The actual `u-boot.itb` offset is not yet available.

## Decision

This repository outputs `u-boot-spl-dtb.hex`, `u-boot.itb`, and `bl31.bin` but
does not build `.sof`, `.rbf`, or `.jic`.

Use `0x00300000` only as an explicitly marked development placeholder because
that is the offset in Altera's 26.1 helper-JIC example. Production release is
blocked until the logic team confirms the PCF4N value and this ADR is updated.

## Consequences

- HPS development can proceed without inventing ownership of FPGA artifacts.
- A development SPL may compile, but must not be programmed as a production
  image.
- The offset exists in one board config source and is rendered into U-Boot,
  preventing mismatched hand-edited values.
