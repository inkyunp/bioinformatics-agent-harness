#!/usr/bin/env bash
set -euo pipefail

# Save Headlong's resumable identity state into a separate private Git repo.

die() {
  printf 'checkpoint: error: %s\n' "$*" >&2
  exit 1
}

identity_name="${HEADLONG_IDENTITY_NAME:-ada}"
headlong_home="${HEADLONG_HOME:-$HOME/.headlong}"
app_dir="${HEADLONG_APP_DIR:-$headlong_home/app}"
identity_dir="$app_dir/.identities/$identity_name"
checkpoint_repo="${HEADLONG_CHECKPOINT_REPO:-$HOME/headlong-state}"

[[ -d "$identity_dir" ]] || die "identity directory not found: $identity_dir"
[[ -d "$checkpoint_repo/.git" ]] || die "not a Git repository: $checkpoint_repo"
command -v rsync >/dev/null 2>&1 || die "rsync is required"

resume_identity() {
  if command -v "$identity_name" >/dev/null 2>&1; then
    "$identity_name" start >/dev/null 2>&1 || true
  elif command -v persona >/dev/null 2>&1; then
    persona "$identity_name" start >/dev/null 2>&1 || true
  fi
}
trap resume_identity EXIT

# Stop before copying JSONL trajectory files so the checkpoint is a clean
# restart point rather than a snapshot of a partially-written final line.
if command -v "$identity_name" >/dev/null 2>&1; then
  "$identity_name" stop >/dev/null 2>&1 || die "could not stop identity $identity_name"
elif command -v persona >/dev/null 2>&1; then
  persona "$identity_name" stop >/dev/null 2>&1 || die "could not stop identity $identity_name"
else
  die "cannot find the Headlong identity command: $identity_name"
fi

mkdir -p "$checkpoint_repo/identity" "$checkpoint_repo/envs"

rsync -a --delete \
  --exclude='.env' \
  --exclude='*.pid' \
  --exclude='*.pid_file' \
  "$identity_dir/" "$checkpoint_repo/identity/"

if [[ -d "$headlong_home/envs" ]]; then
  rsync -a --delete \
    --exclude='.env' \
    --exclude='*.pid' \
    --exclude='*.pid_file' \
    "$headlong_home/envs/" "$checkpoint_repo/envs/"
fi

git -C "$checkpoint_repo" add -A
if git -C "$checkpoint_repo" diff --cached --quiet; then
  printf 'checkpoint: no changes to commit\n'
  exit 0
fi

commit_message="headlong checkpoint $(date -u +%Y-%m-%dT%H:%M:%SZ)"
git -C "$checkpoint_repo" commit -m "$commit_message"
git -C "$checkpoint_repo" push
printf 'checkpoint: pushed %s\n' "$commit_message"
