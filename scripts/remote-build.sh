#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
for cmd in awk rsync scp sha256sum ssh; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "required command not found: $cmd" >&2; exit 1; }
done

env_file="$ROOT_DIR/config/remote.env"
[[ -f "$env_file" ]] || { echo 'copy config/remote.env.example to config/remote.env first' >&2; exit 1; }
# shellcheck source=/dev/null
source "$env_file"

: "${REMOTE_HOST:?missing REMOTE_HOST}"
: "${REMOTE_KEY:?missing REMOTE_KEY}"
: "${REMOTE_PROJECT_DIR:?missing REMOTE_PROJECT_DIR}"
: "${REMOTE_CACHE_DIR:?missing REMOTE_CACHE_DIR}"
: "${REMOTE_ARTIFACT_DIR:?missing REMOTE_ARTIFACT_DIR}"
: "${REMOTE_HTTP_PROXY:?missing REMOTE_HTTP_PROXY}"
[[ -f "$REMOTE_KEY" ]] || { echo "SSH key not found: $REMOTE_KEY" >&2; exit 1; }
[[ "$REMOTE_PROJECT_DIR" == /data/* ]] || { echo 'remote project must be under /data' >&2; exit 1; }
[[ "$REMOTE_CACHE_DIR" == /data/* ]] || { echo 'remote cache must be under /data' >&2; exit 1; }
[[ "$REMOTE_ARTIFACT_DIR" == /data/* ]] || { echo 'remote artifacts must be under /data' >&2; exit 1; }

ssh_opts=(-i "$REMOTE_KEY" -o BatchMode=yes -o ConnectTimeout=15)
# shellcheck disable=SC2029
ssh "${ssh_opts[@]}" "$REMOTE_HOST" \
  "install -d -m 0755 '$REMOTE_PROJECT_DIR' '$REMOTE_CACHE_DIR/bootstrap' '$REMOTE_ARTIFACT_DIR'"

rsync -az --safe-links \
  --exclude .git --exclude .work --exclude output --exclude config/remote.env \
  -e "ssh -i $REMOTE_KEY -o BatchMode=yes -o ConnectTimeout=15" \
  "$ROOT_DIR/" "$REMOTE_HOST:$REMOTE_PROJECT_DIR/"

# shellcheck disable=SC2029
ssh "${ssh_opts[@]}" "$REMOTE_HOST" \
  "cd '$REMOTE_PROJECT_DIR' && BUILDER_HTTP_PROXY='$REMOTE_HTTP_PROXY' BUILD_CACHE_DIR='$REMOTE_CACHE_DIR/bootstrap' make image build check && rsync -a output/ '$REMOTE_ARTIFACT_DIR/'"

mkdir -p "$ROOT_DIR/output/deploy"
rsync -az --exclude deploy/rootfs.ext4 \
  -e "ssh -i $REMOTE_KEY -o BatchMode=yes -o ConnectTimeout=15" \
  "$REMOTE_HOST:$REMOTE_PROJECT_DIR/output/" "$ROOT_DIR/output/"

# macOS openrsync has been observed to truncate this 1 GiB filesystem while
# still returning success. Transfer it separately, validate the temporary file,
# and only then replace the local artifact.
rootfs_tmp=$(mktemp "$ROOT_DIR/output/deploy/rootfs.ext4.XXXXXX")
trap 'rm -f -- "$rootfs_tmp"' EXIT
scp -C "${ssh_opts[@]}" \
  "$REMOTE_HOST:$REMOTE_PROJECT_DIR/output/deploy/rootfs.ext4" "$rootfs_tmp"
expected_rootfs_sha=$(awk '$2 == "deploy/rootfs.ext4" {print $1; exit}' \
  "$ROOT_DIR/output/manifest.sha256")
actual_rootfs_sha=$(sha256sum "$rootfs_tmp" | awk '{print $1}')
[[ -n "$expected_rootfs_sha" && "$actual_rootfs_sha" == "$expected_rootfs_sha" ]] || {
  echo 'rootfs checksum mismatch after SCP transfer' >&2
  exit 1
}
mv -f -- "$rootfs_tmp" "$ROOT_DIR/output/deploy/rootfs.ext4"
"$ROOT_DIR/scripts/check.sh"
