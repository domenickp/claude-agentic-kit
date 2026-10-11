#!/usr/bin/env sh
# beads-init.sh — set up portable bd (beads) in a git repo, the first time, on one machine.
#
# Usage:  sh <kit>/scripts/beads-init.sh <issue-prefix> [project-name]
#
# Run from the repo root. Safe to re-run: every step checks before acting.
# Issues travel between machines as the git-tracked .beads/issues.jsonl.
# The Dolt database stays local. On other machines, run beads-clone-setup.sh.
set -eu

PREFIX="${1:?usage: beads-init.sh <issue-prefix> [project-name]}"
PROJECT="${2:-$(basename "$(pwd)")}"
KIT="$(cd "$(dirname "$0")/.." && pwd)"
T="$KIT/templates"

say() { printf '==> %s\n' "$*"; }

command -v bd  >/dev/null 2>&1 || { echo "bd not found on PATH" >&2; exit 1; }
command -v git >/dev/null 2>&1 || { echo "git not found on PATH" >&2; exit 1; }

# 1. Git repo with a commit (bd init commits; worktree builders need a HEAD).
if [ ! -d .git ]; then
  say "git init"
  git init -q
fi

# 2. bd init. It auto-commits (including the credential key, fixed in step 3).
if [ ! -d .beads ]; then
  say "bd init -p $PREFIX"
  bd init -p "$PREFIX" -q --skip-agents
  BD_INIT_COMMITTED=1
else
  say ".beads exists; skipping bd init"
  BD_INIT_COMMITTED=0
fi

# 3. Never track the machine-local credential key.
if git ls-files --error-unmatch .beads/.beads-credential-key >/dev/null 2>&1; then
  say "untracking .beads/.beads-credential-key"
  git rm -q --cached .beads/.beads-credential-key
fi

# 4. Root .gitignore: drop bd's bare '*.db' rule (it hides every .db in the project)
#    and add the portable-beads block.
if [ -f .gitignore ] && grep -qx '\*\.db' .gitignore; then
  say "removing bare '*.db' rule from .gitignore (scoped .beads/*.db rule added instead)"
  grep -vx '\*\.db' .gitignore > .gitignore.tmp && mv -f .gitignore.tmp .gitignore
fi
if ! grep -q 'BEGIN PORTABLE BEADS' .gitignore 2>/dev/null; then
  say "adding portable-beads block to .gitignore"
  { [ -s .gitignore ] && echo; cat "$T/gitignore-beads.txt"; } >> .gitignore
fi

# 5. .gitattributes: LF for issues.jsonl and hook scripts.
if ! grep -q 'BEGIN PORTABLE BEADS' .gitattributes 2>/dev/null; then
  say "adding portable-beads block to .gitattributes"
  { [ -s .gitattributes ] && echo; cat "$T/gitattributes-beads.txt"; } >> .gitattributes
fi

# 6. Hooks: committed in .beads/hooks, wired with a RELATIVE path (bd init writes an
#    absolute, machine-specific one).
git config --local core.hooksPath .beads/hooks
if ! grep -q 'BEGIN PORTABLE BEADS EXPORT' .beads/hooks/pre-commit 2>/dev/null; then
  say "appending issues.jsonl export block to .beads/hooks/pre-commit"
  cat "$T/pre-commit-export.sh" >> .beads/hooks/pre-commit
fi

# 7. Silence bd's role warning on this machine.
git config --local beads.role maintainer

# 8. Agent instructions and Claude permissions (only if missing; never overwrite).
if [ ! -f AGENTS.md ]; then
  say "writing AGENTS.md"
  sed -e "s/{{PROJECT}}/$PROJECT/g" -e "s/{{PREFIX}}/$PREFIX/g" "$T/AGENTS.md.tmpl" > AGENTS.md
fi
if [ ! -f CLAUDE.md ]; then
  say "writing CLAUDE.md"
  sed -e "s/{{PROJECT}}/$PROJECT/g" "$T/CLAUDE.md.tmpl" > CLAUDE.md
fi
if [ ! -f .claude/settings.json ]; then
  say "writing .claude/settings.json"
  mkdir -p .claude
  cp -f "$T/settings.json" .claude/settings.json
fi

# 9. Initial export, then commit.
bd export -o .beads/issues.jsonl >/dev/null
git add .gitignore .gitattributes .beads AGENTS.md CLAUDE.md .claude/settings.json
if git ls-files --cached | grep -q '^\.beads/\.beads-credential-key$'; then
  echo "refusing to commit: credential key is staged" >&2; exit 1
fi

# Rewrite bd's own init commit if it has never been pushed, so the credential key is not
# left in history. Otherwise, add a new commit.
if [ "$BD_INIT_COMMITTED" = 1 ] && \
   git log -1 --format=%s | grep -q '^bd init' && \
   [ -z "$(git branch -r --contains HEAD 2>/dev/null)" ]; then
  say "amending bd's init commit (credential key removed from history)"
  git commit -q --amend -m "Set up portable beads issue tracking"
elif ! git diff --cached --quiet; then
  git commit -q -m "Set up portable beads issue tracking"
fi

say "done. Next: commit normally (issues.jsonl auto-exports), and on other machines run"
say "  sh <kit>/scripts/beads-clone-setup.sh"
