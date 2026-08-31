# ADR 0004: Simple GPT, kernel-last write, stop-on-failure

- Status: Accepted
- Date: 2026-08-26

## Context

The first milestone is reliable board provisioning, not a complete field
update system. The user explicitly selected conservative eMMC timing and a
failure policy that remains at the U-Boot prompt.

## Decision

Create a two-partition GPT with a 64 MiB raw kernel FIT partition and a 1 GiB
ext4 rootfs partition. Download and hash both files before modifying eMMC.
Write rootfs first and kernel last. On any error, do not boot from eMMC or an
older image automatically.

Use non-removable 4-bit eMMC at a maximum of 52 MHz; do not advertise HS200 in
the first device tree. Reset the device through HPS GPIO27, represented as
GPIO1/port B line 3 with active-low polarity, before card initialization.

## Consequences

- The flow is deterministic and easy to inspect over UART.
- There is no rollback or power-loss-safe A/B update.
- Reprovisioning rewrites the GPT and system partitions each time.
- A/B slots can be added after hardware initialization is proven.
