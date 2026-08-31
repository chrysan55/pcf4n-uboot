# ADR 0002: TFTP first, HTTP optional, no traditional FTP client

- Status: Accepted
- Date: 2026-08-26

## Context

The original requirement named FTP. Standard U-Boot has a mature TFTP client
and recent releases can provide HTTP `wget`, but traditional FTP is not a
portable standard U-Boot command. A recovery Linux would be required for a
streaming FTP client when images do not fit in DDR.

## Decision

Use DHCP plus TFTP for the first end-to-end implementation and compile HTTP
`wget` support when available. Download the 1 GiB rootfs into the inferred
16 GiB DDR, verify it, then write eMMC.

Do not add a custom FTP stack to U-Boot. If traditional FTP becomes mandatory
or usable DDR is too small, replace this path with a small recovery initramfs
that streams to eMMC.

## Consequences

- The implementation follows Altera's validated helper-JIC workflow.
- TFTP is simple to debug during bring-up.
- TFTP is unauthenticated and must not be treated as a production security
  boundary.
