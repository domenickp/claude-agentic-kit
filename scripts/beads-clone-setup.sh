#!/usr/bin/env sh
# beads-clone-setup.sh — set up bd on a fresh clone of a portable-beads repo (new machine).
#
# Usage:  sh <kit>/scripts/beads-clone-setup.sh
#
# Run from the repo root after `git clone`. Safe to re-run.
# Rebuilds the local Dolt database from the committed .beads/issues.jsonl and rewires
# the per-machine pieces git does not carry (hook path, role).
set -eu

say() { printf '==> %s\n' "$*"; }

command -v bd >/dev/null 2>&1 || { echo "bd not found on PATH" >&2; exit 1; }
[ -d .beads ] || { echo "no .beads/ here; run from the repo root (or use beads-init.sh for a new repo)" >&2; exit 1; }

say "bd bootstrap"
bd bootstrap

if [ -f .beads/issues.jsonl ]; then
  say "bd import (from .beads/issues.jsonl)"
  bd import
fi

# Hooks are committed in .beads/hooks. Wire them with a relative path. We don't run
# `bd hooks install` here: it would rewrite the committed hook files.
git config --local core.hooksPath .beads/hooks
git config --local beads.role maintainer

if ! grep -q 'BEGIN PORTABLE BEADS EXPORT' .beads/hooks/pre-commit 2>/dev/null; then
  echo "WARNING: .beads/hooks/pre-commit lacks the issues.jsonl export block;" >&2
  echo "         issue changes will not be committed. Re-run beads-init.sh to restore it." >&2
fi

say "issues now in local db:"
bd list --all --json 2>/dev/null | grep -c '"id"' || true
say "done. Each session: git pull --rebase && bd import"
