# Bioinformatics Agent Harness

An experimental Headlong-based harness for persistent bioinformatics research
and pipeline operations.

## Current direction

This project connects Headlong to the authenticated Codex CLI without placing
an OpenAI Platform API key in the harness:

```text
Headlong → LLM_ADAPTER → codex exec → ChatGPT login
```

The adapter is experimental. `codex exec` is an agent-oriented CLI, not a raw
chat-completions endpoint, so the bridge asks Codex to return only the
completion that Headlong expects.

## Files

- `adapters/codex-exec-adapter` — Headlong `LLM_ADAPTER` implementation.
- `scripts/checkpoint.sh` — stops an identity, copies resumable state, commits,
  and pushes to a private checkpoint repository.
- `scripts/restore.sh` — restores identity state in a fresh VM.
- `tests/test_codex_exec_adapter.sh` — offline adapter contract test.

## First VM setup

Install Headlong and Codex CLI in a private, trusted VM. Then authenticate the
Codex CLI once:

```bash
codex login
codex login status
```

Create or clone a private state repository, then configure:

```bash
export HEADLONG_HOME="$HOME/.headlong"
export HEADLONG_IDENTITY_NAME=ada
export HEADLONG_CHECKPOINT_REPO="$HOME/headlong-state"
export LLM_PROVIDER=adapter
export LLM_ADAPTER="$PWD/adapters/codex-exec-adapter"
```

The adapter must be executable and available at the same path to any
sandboxed Headlong caller. If Headlong runs the completion process in Docker,
mount the adapter into that container at the configured path.

## Checkpoint and restore

Checkpoint periodically while the VM is alive:

```bash
./scripts/checkpoint.sh
```

The checkpoint excludes `.env`, PID files, and other credentials. It includes
the identity's persona, memories, trajectory, workdir, and the named execution
environment metadata needed for logical continuation.

On a new VM:

```bash
git clone git@github.com:inkyunp/bioinformatics-agent-state.git "$HOME/headlong-state"
# Install the same Headlong version and dependencies first.
./scripts/restore.sh "$HOME/headlong-state"
```

This resumes from the last pushed checkpoint. An in-flight LLM call or an
uncommitted file change cannot be recovered.

## Safety

Use a private repository. Never commit API keys, `~/.codex/auth.json`, patient
data, FASTQ/BAM/VCF files, or internal analysis results. Headlong executes real
shell commands, so use a dedicated VM and a spend-limited ChatGPT/Codex setup.
