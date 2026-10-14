---
name: beads-portable
description: Set up and run bd (beads) issue tracking so issues travel between machines through git (a committed .beads/issues.jsonl) instead of a Dolt remote. Use when starting a new project with bd, setting up an existing bd repo on a new machine or fresh clone, starting or ending a session in a portable-beads repo, or when bd issues seem missing or out of sync between machines.
---

# Portable beads

bd keeps issues in a local Dolt database (`.beads/dolt/`), which is **gitignored and does
not travel**. Without a Dolt remote, the portable artifact is **`.beads/issues.jsonl`**,
committed to git. This skill sets that up, plus the per-machine and per-session routines.
It is verified on bd 0.61.

The scripts live in this plugin's `scripts/` directory: `../../scripts/` relative to this
skill's base directory. Below, `<kit>` means the plugin root.

## Which situation are you in?

| Situation | Do this |
|---|---|
| New project, bd never set up | `sh <kit>/scripts/beads-init.sh <prefix> [name]`, then fill in the project sections of `AGENTS.md` |
| Existing portable-beads repo, new machine or fresh clone | `git clone …`, then `sh <kit>/scripts/beads-clone-setup.sh` |
| Starting a session | export + commit any uncommitted issue changes, then `git pull --rebase && bd import`, then `bd ready` |
| Ending a session | see *Session end* below |
| Issues look stale or missing | `bd import`, then compare `bd list --all --json` with `.beads/issues.jsonl` |
| Repo has bd but no `issues.jsonl` and no export hook | run `beads-init.sh`. It skips `bd init` when `.beads/` exists and only adds the missing pieces |

Before running either script, check that `bd` and `git` are on PATH. On Windows, run the
scripts with Git Bash's `sh`.

## What `beads-init.sh` fixes, and why

Each step corrects a real bd behaviour found in practice:

1. **`bd init` auto-commits `.beads/.beads-credential-key`**, a machine-local secret that
   bd's own `.beads/.gitignore` does not exclude. The script untracks it, gitignores it, and
   amends bd's init commit if it hasn't been pushed, so the key never reaches history.
2. **`bd init` appends a bare `*.db` rule to the root `.gitignore`**, which hides every `.db`
   file in the project. The script replaces it with scoped `.beads/*.db` rules.
3. **`bd init` sets `core.hooksPath` to an absolute, machine-specific path.** The script sets
   it to the relative `.beads/hooks`. Hook files are committed, so they travel. The wiring is
   per-machine config, which the clone script re-creates.
4. **bd has no working auto-export.** The `auto-export` config key is accepted but does
   nothing. The script appends an export block to `.beads/hooks/pre-commit`, **outside** bd's
   `BEGIN/END BEADS INTEGRATION` markers so a bd upgrade can't drop it. Every commit runs
   `bd export -o .beads/issues.jsonl` and stages the file. The block skips linked worktrees,
   so builder commits never touch the issue file.
5. **Line endings.** `.gitattributes` pins `*.jsonl` and `.beads/hooks/*` to LF. CRLF hooks
   fail with "bad interpreter" on macOS/Linux, and CRLF JSONL churns between OSes.
6. **Agent docs.** Writes `AGENTS.md` (source of truth, read by all agents), a thin
   `CLAUDE.md` pointing to it, and a committed `.claude/settings.json` allowing read-only bd
   commands. None of these overwrite existing files. `bd init --skip-agents` stops bd from
   writing its own AGENTS.md block, which tells agents to use `bd dolt push`. That is wrong here.
7. Sets `git config beads.role maintainer`; otherwise bd warns on every command.

## Per-machine setup (`beads-clone-setup.sh`)

```bash
bd bootstrap                                  # create the local db (non-destructive)
bd import                                     # load .beads/issues.jsonl
git config --local core.hooksPath .beads/hooks
git config --local beads.role maintainer
```

The script deliberately does **not** run `bd hooks install`. The hooks are already committed,
and reinstalling would rewrite the files. Verified result: a fresh clone reproduces the full
issue list, with open/in_progress/closed statuses intact.

## Session start

```bash
git pull --rebase
bd import      # NOT automatic; bd's post-merge hook can't be relied on.
bd ready --json
```

**Export before you import.** `bd import` makes the database match the JSONL, so any issue
change made since the last commit (a `bd close`, `bd update`, `--claim`) is silently reverted
to the file's older state. Found in practice: an issue closed after verification was reopened
by the `bd import` that followed a `git pull`. Whenever the database may be ahead of the file,
run `bd export -o .beads/issues.jsonl` and commit first. `bd import` is only harmless when
the database has no unexported changes.

## Session end ("landing the plane")

1. File issues for leftover and discovered work (`--deps discovered-from:<id>`).
2. Run the quality gates if code changed.
3. Close or update issues.
4. Sync and push:
   ```bash
   git add -A && git commit -m "..."   # hook exports + stages issues.jsonl FIRST
   git pull --rebase && bd import       # safe now: the JSONL already holds your changes
   git push
   git status                           # must say "up to date with origin"
   ```
   If there are bd changes but nothing else to commit, run
   `bd export -o .beads/issues.jsonl && git add .beads/issues.jsonl && git commit -m "Update issues"`.
5. Skip `bd dolt push` unless `bd dolt remote list` shows a remote. Its failure must not block
   the push.

## What does NOT travel

| Item | Why | Where it should go instead |
|---|---|---|
| Dolt db `.beads/dolt/` | gitignored | rebuilt from `issues.jsonl` by the clone script |
| `bd remember` memories | stored in the db, not in `bd export` | durable facts → `AGENTS.md`; `bd remember` only for machine-local notes |
| `core.hooksPath`, `beads.role` | git config is per-clone | clone script |
| `.beads/.beads-credential-key` | secret | never commit; bd regenerates it |

## Resolving `issues.jsonl` merge conflicts

The file has one JSON object per line, one line per issue id. Keep every id from both sides.
Where the same id appears on both sides, keep the line with the later `updated_at`. Then:

```bash
bd import && git add .beads/issues.jsonl && git commit
```

## Checks (use these after setup, or when something seems off)

```bash
git ls-files | grep -E 'credential-key|\.beads/dolt/'   # must print nothing
git config --get core.hooksPath                          # .beads/hooks
grep -c 'BEGIN PORTABLE BEADS EXPORT' .beads/hooks/pre-commit   # 1
bd export | diff - .beads/issues.jsonl && echo in-sync    # after a commit
```
