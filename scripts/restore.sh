#!/usr/bin/env bash
set -euo pipefail

# Restore identity state from a local checkout of the private checkpoint repo.

die() {
  printf 'restore: error: %s\n' "$*" >&2
  exit 1
}

identity_name="${HEADLONG_IDENTITY_NAME:-ada}"
headlong_home="${HEADLONG_HOME:-$HOME/.headlong}"
app_dir="${HEADLONG_APP_DIR:-$headlong_home/app}"
identity_dir="$app_dir/.identities/$identity_name"
checkpoint_repo="${1:-${HEADLONG_CHECKPOINT_REPO:-$HOME/headlong-state}}"

[[ -d "$checkpoint_repo/identity" ]] || die "checkpoint identity not found: $checkpoint_repo/identity"
command -v rsync >/dev/null 2>&1 || die "rsync is required"

if command -v "$identity_name" >/dev/null 2>&1; then
  "$identity_name" stop >/dev/null 2>&1 || true
elif command -v persona >/dev/null 2>&1; then
  persona "$identity_name" stop >/dev/null 2>&1 || true
fi

mkdir -p "$identity_dir"
rsync -a \
  --exclude='.env' \
  --exclude='*.pid' \
  --exclude='*.pid_file' \
  "$checkpoint_repo/identity/" "$identity_dir/"

if [[ -d "$checkpoint_repo/envs" ]]; then
  mkdir -p "$headlong_home/envs"
  rsync -a \
    --exclude='.env' \
    --exclude='*.pid' \
    --exclude='*.pid_file' \
    "$checkpoint_repo/envs/" "$headlong_home/envs/"
fi

if command -v "$identity_name" >/dev/null 2>&1; then
  "$identity_name" start
elif command -v persona >/dev/null 2>&1; then
  persona "$identity_name" start
else
  printf 'restore: state restored; run "%s start" after Headlong is on PATH\n' "$identity_name"
fi
