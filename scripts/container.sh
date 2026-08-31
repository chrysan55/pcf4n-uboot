#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=/dev/null
source "$ROOT_DIR/config/versions.env"
# shellcheck source=/dev/null
source "$ROOT_DIR/config/board.env"

command -v docker >/dev/null 2>&1 || { echo 'docker is required' >&2; exit 1; }
(( $# > 0 )) || { echo 'usage: container.sh COMMAND [ARG...]' >&2; exit 1; }

mkdir -p "$ROOT_DIR/.work" "$ROOT_DIR/output"
cache_dir=${BUILD_CACHE_DIR:-"$ROOT_DIR/.work/cache"}
mkdir -p "$cache_dir"

proxy=${BUILDER_HTTP_PROXY:-${HTTPS_PROXY:-${HTTP_PROXY:-}}}
docker_args=(
  run --rm --network host
  --ulimit nofile=65536:65536
  --user "$(id -u):$(id -g)"
  --volume "$ROOT_DIR:/workspace"
  --volume "$cache_dir:/cache"
  --workdir /workspace
  --env HOME=/tmp
  --env BUILD_CACHE_DIR=/cache
  --env JOBS="$JOBS"
  --env MEMORY_HEAVY_JOBS="$MEMORY_HEAVY_JOBS"
)

if [[ -n "$proxy" ]]; then
  docker_args+=(
    --env HTTP_PROXY="$proxy" --env HTTPS_PROXY="$proxy" --env ALL_PROXY="$proxy"
    --env http_proxy="$proxy" --env https_proxy="$proxy" --env all_proxy="$proxy"
  )
fi

exec docker "${docker_args[@]}" "$BUILDER_IMAGE" "$@"
