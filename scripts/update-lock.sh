#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=/dev/null
source "$ROOT_DIR/config/versions.env"

resolve_ref() {
  local repo=$1 ref=$2 lines commit
  lines=$(git ls-remote "$repo" \
    "refs/tags/$ref^{}" "refs/tags/$ref" "refs/heads/$ref")
  commit=$(printf '%s\n' "$lines" | awk '$2 ~ /\^\{\}$/ {print $1; exit}')
  [[ -n "$commit" ]] || commit=$(printf '%s\n' "$lines" | awk '$2 ~ /^refs\/tags\// {print $1; exit}')
  [[ -n "$commit" ]] || commit=$(printf '%s\n' "$lines" | awk '$2 ~ /^refs\/heads\// {print $1; exit}')
  [[ "$commit" =~ ^[0-9a-f]{40}$ ]] || {
    printf 'could not resolve %s at %s\n' "$ref" "$repo" >&2
    return 1
  }
  printf '%s\n' "$commit"
}

printf 'Resolving Altera and Buildroot release refs...\n'
uboot_commit=$(resolve_ref "$UBOOT_REPO" "$UBOOT_REF")
linux_commit=$(resolve_ref "$LINUX_REPO" "$LINUX_REF")
atf_commit=$(resolve_ref "$ATF_REPO" "$ATF_REF")
buildroot_commit=$(resolve_ref "$BUILDROOT_REPO" "$BUILDROOT_REF")

lock_tmp=$(mktemp "$ROOT_DIR/config/sources.lock.XXXXXX")
trap 'rm -f -- "$lock_tmp"' EXIT
{
  printf '%s\n' '# Generated from config/versions.env by scripts/update-lock.sh.'
  printf '%s\n' '# Full object IDs make the checkout independent of moving branches.'
  printf 'UBOOT_COMMIT=%s\n' "$uboot_commit"
  printf 'LINUX_COMMIT=%s\n' "$linux_commit"
  printf 'ATF_COMMIT=%s\n' "$atf_commit"
  printf 'BUILDROOT_COMMIT=%s\n' "$buildroot_commit"
} >"$lock_tmp"
mv "$lock_tmp" "$ROOT_DIR/config/sources.lock"
trap - EXIT

printf 'U-Boot:   %s\nLinux:    %s\nATF:      %s\nBuildroot:%s\n' \
  "$uboot_commit" "$linux_commit" "$atf_commit" "$buildroot_commit"
