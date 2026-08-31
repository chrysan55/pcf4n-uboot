#!/usr/bin/env bash

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
CONFIG_DIR="$ROOT_DIR/config"
WORK_DIR=${WORK_DIR:-"$ROOT_DIR/.work"}
SOURCE_DIR=${SOURCE_DIR:-"$WORK_DIR/src"}
BUILD_DIR=${BUILD_DIR:-"$WORK_DIR/build"}
STAGING_DIR=${STAGING_DIR:-"$WORK_DIR/staging"}
OUTPUT_DIR=${OUTPUT_DIR:-"$ROOT_DIR/output"}
BUILD_CACHE_DIR=${BUILD_CACHE_DIR:-"$WORK_DIR/cache"}

# shellcheck source=/dev/null
source "$CONFIG_DIR/versions.env"
# shellcheck source=/dev/null
source "$CONFIG_DIR/sources.lock"
# shellcheck source=/dev/null
source "$CONFIG_DIR/board.env"

JOBS=${JOBS:-2}
MEMORY_HEAVY_JOBS=${MEMORY_HEAVY_JOBS:-1}

log() {
  printf '\n==> %s\n' "$*"
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"
}

require_file() {
  [[ -f "$1" ]] || die "required file not found: $1"
}

require_locked_commit() {
  local name=$1 value=$2
  [[ "$value" =~ ^[0-9a-f]{40}$ ]] || die "$name is not a locked 40-character commit: $value"
}

validate_source_locks() {
  require_locked_commit UBOOT_COMMIT "$UBOOT_COMMIT"
  require_locked_commit LINUX_COMMIT "$LINUX_COMMIT"
  require_locked_commit ATF_COMMIT "$ATF_COMMIT"
  require_locked_commit BUILDROOT_COMMIT "$BUILDROOT_COMMIT"
}

prepare_directories() {
  mkdir -p "$SOURCE_DIR" "$BUILD_DIR" "$STAGING_DIR" "$OUTPUT_DIR" "$BUILD_CACHE_DIR"
}

source_date_epoch() {
  local epoch=0 repo commit_time
  for repo in u-boot linux atf buildroot; do
    if [[ -d "$SOURCE_DIR/$repo/.git" ]]; then
      commit_time=$(git -C "$SOURCE_DIR/$repo" show -s --format=%ct HEAD)
      (( commit_time > epoch )) && epoch=$commit_time
    fi
  done
  printf '%s\n' "$epoch"
}

fetch_repo() {
  local name=$1 url=$2 commit=$3 destination="$SOURCE_DIR/$1"
  require_locked_commit "${name}_COMMIT" "$commit"

  if [[ -d "$destination/.git" ]]; then
    if [[ "$(git -C "$destination" rev-parse HEAD 2>/dev/null || true)" == "$commit" ]]; then
      log "$name already at $commit"
      return
    fi
  else
    mkdir -p "$destination"
    git -C "$destination" init --quiet
    git -C "$destination" remote add origin "$url"
  fi

  log "fetching $name at $commit"
  git -C "$destination" fetch --no-tags --depth=1 origin "$commit"
  git -C "$destination" checkout --quiet --detach FETCH_HEAD
  [[ "$(git -C "$destination" rev-parse HEAD)" == "$commit" ]] || die "$name checkout mismatch"
}

# Source trees under .work/src are disposable, pinned build inputs. Restore all
# tracked files before applying the project's patch series so editing a patch
# cannot leave an older version of that patch in the source tree.
restore_tracked_source() {
  local name=$1 commit=$2 destination="$SOURCE_DIR/$1"

  [[ "$(git -C "$destination" rev-parse HEAD)" == "$commit" ]] || \
    die "$name source is not at locked commit $commit"
  git -C "$destination" restore --source="$commit" --staged --worktree -- .
}

render_template() {
  local input=$1 output=$2
  shift 2
  cp "$input" "$output"
  while (($#)); do
    local key=$1 value=$2
    shift 2
    sed -i.bak "s|@$key@|$value|g" "$output"
    rm -f -- "$output.bak"
  done
  if grep -Eq '@[A-Z0-9_]+@' "$output"; then
    grep -En '@[A-Z0-9_]+@' "$output" >&2
    die "unresolved template token in $output"
  fi
}
