
# --- BEGIN PORTABLE BEADS EXPORT (agentic-kit) ---
# Keep .beads/issues.jsonl in sync with the local database on every commit.
# Deliberately outside the beads-managed block above so a bd upgrade cannot drop it.
# bd has no working auto-export, so without this the committed issue list silently
# drifts from the database and machines disagree about issue state.
# Skipped in linked worktrees: builders commit there, and only the main checkout's
# coordinator writes issues, so exporting there would just cause merge conflicts.
if command -v bd >/dev/null 2>&1 && [ -d .beads ] && \
   [ "$(git rev-parse --git-dir)" = "$(git rev-parse --git-common-dir)" ]; then
  if bd export -o .beads/issues.jsonl >/dev/null 2>&1; then
    git add .beads/issues.jsonl
  fi
fi
# --- END PORTABLE BEADS EXPORT (agentic-kit) ---
