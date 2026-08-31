# ADR 0001: Containerized, source-locked builds

- Status: Accepted
- Date: 2026-08-26

## Context

The build host is a small Tencent Cloud VM and may be replaced or rebuilt. The
project must support updates, traceability, version control, and use without a
specific preconfigured workstation.

## Decision

Use a Docker image for build tools, store Altera release refs separately from
full commit locks, keep downloaded sources and outputs outside Git, and emit a
machine-readable build manifest for each package.

Use `JOBS=2` by default and allow memory-heavy steps to reduce parallelism.

## Consequences

- Builds are portable between Linux Docker hosts.
- Source movement is detected because checkout uses full commits.
- Container creation still depends on apt repositories; production release
  additionally requires a digest-pinned base image.
- Low-memory builds are slow but do not require a larger VM.
