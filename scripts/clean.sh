#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
for target in "$ROOT_DIR/.work" "$ROOT_DIR/output"; do
  [[ "$target" == "$ROOT_DIR/"* ]] || { echo "refusing unsafe path: $target" >&2; exit 1; }
done
rm -rf -- "$ROOT_DIR/.work" "$ROOT_DIR/output"
