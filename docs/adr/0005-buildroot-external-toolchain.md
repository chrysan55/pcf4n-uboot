# ADR 0005: Official external toolchain for the recovery rootfs

- Status: Accepted
- Date: 2026-08-26

## Context

The Tencent Cloud builder is intentionally small and runs memory-heavy builds
with one job. Buildroot's default internal toolchain builds host binutils,
GCC, and glibc before it can build the small recovery root filesystem. Enabling
Buildroot ccache additionally builds host CMake and ccache first.

## Decision

Use the Bootlin AArch64 glibc stable 2025.08-1 external toolchain selected by
the locked Buildroot 2026.02 tree. Keep Buildroot ccache disabled. Record the
toolchain identity in `config/versions.env` and every build manifest.

The toolchain archive is still downloaded and hash-verified by Buildroot; no
unversioned compiler from the VM or container is used for target userspace.

## Consequences

- First rootfs builds avoid compiling a complete target toolchain on the VM.
- The toolchain version and checksum move only when the locked Buildroot release
  or this explicit selection changes.
- The recovery userspace uses glibc and is larger than a minimal musl image, but
  remains comfortably within the fixed 1 GiB eMMC rootfs partition.
- Buildroot package sources remain cached under `/data/cache/bootstrap`.
