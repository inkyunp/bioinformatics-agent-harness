#!/usr/bin/env bash
set -euo pipefail

test_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
adapter="$test_root/adapters/codex-exec-adapter"
tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/headlong-adapter-test.XXXXXX")
trap 'rm -rf "$tmp_dir"' EXIT

cat > "$tmp_dir/codex" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" > "$CODEX_TEST_ARGS"
printf '%s' "${*: -1}" > "$CODEX_TEST_PROMPT"
printf '```bash\nFINAL="mock completion"\n```\n'
EOF
chmod +x "$tmp_dir/codex"

cat > "$tmp_dir/system.txt" <<'EOF'
Write a bash code block and nothing else.
EOF

output=$(
  PATH="$tmp_dir:$PATH" \
  CODEX_TEST_ARGS="$tmp_dir/args" \
  CODEX_TEST_PROMPT="$tmp_dir/prompt" \
  "$adapter" \
    --model gpt-5.5 \
    --max-tokens 1024 \
    --system-prompt-file "$tmp_dir/system.txt" \
    --effort high \
    --thinking medium \
    <<'JSON'
[{"role":"user","content":"Return the completion."}]
JSON
)

grep -q 'FINAL="mock completion"' <<<"$output"
grep -q 'Write a bash code block' "$tmp_dir/prompt"
grep -q 'Return the completion' "$tmp_dir/prompt"
grep -q -- '--model gpt-5.5' "$tmp_dir/args"
printf 'test_codex_exec_adapter: PASS\n'
