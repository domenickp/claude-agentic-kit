# claude-agentic-kit

A Claude Code plugin for running projects with a **coordinator agent (Opus) + builder
subagents (Sonnet)**, tracking tasks in **bd (beads)** set up so issues travel between
machines through git.

| Component | What it does |
|---|---|
| `agents/builder.md` | Sonnet builder: implements one scoped brief, validates, commits, returns a structured report. Never writes to bd, never pushes or deploys. |
| `skills/coordinate` | Coordinator workflow: bd decomposition, contracts first, brief template, dispatch (sequential or parallel worktrees), independent verification, merge and close. |
| `skills/beads-portable` | Portable beads setup and per-session routine; why each fix exists. |
| `scripts/beads-init.sh` | First-time bd setup in a repo, with all portability fixes. Idempotent. |
| `scripts/beads-clone-setup.sh` | Sets up bd on a fresh clone / new machine. Idempotent. |
| `templates/` | AGENTS.md, CLAUDE.md, `.claude/settings.json`, gitignore/gitattributes blocks, and the pre-commit export block. |

## Set up a machine (once per machine)

1. Install the prerequisites: **git**, **bd** (beads, verified with 0.61), **Node.js** (for
   project tooling such as clasp), and optionally **gh** (GitHub CLI). On Windows, use the
   Git Bash that ships with git to run the scripts.
2. Install the plugin in Claude Code:
   ```
   /plugin marketplace add domenickp/claude-agentic-kit
   /plugin install agentic-kit@domenickp-kit
   ```
   or from a shell: `claude plugin marketplace add domenickp/claude-agentic-kit && claude plugin install agentic-kit@domenickp-kit`.
   The repo is private, so the machine needs GitHub access (`gh auth login`, or git credentials).
3. Optional: also clone this repo somewhere stable (for example `~/claude-agentic-kit`) to run
   the scripts by hand outside Claude.

## Start a new project

```bash
cd my-project
sh ~/claude-agentic-kit/scripts/beads-init.sh <issue-prefix> "<Project Name>"
# fill in the Project / Who-this-is-for sections of AGENTS.md
gh repo create <owner>/<repo> --private --source . --push
```

Then, in Claude Code (Opus), ask it to use the `coordinate` skill to plan and build.

## Pick up a project on another machine

```bash
git clone <repo-url> && cd <repo>
sh ~/claude-agentic-kit/scripts/beads-clone-setup.sh
```

Each session: `git pull --rebase && bd import` → work → `git commit` (auto-exports issues) → `git push`.

## Verified behaviour (bd 0.61, Windows / Git Bash)

- A fresh clone reproduces the full issue list: ids, statuses, priorities and dependencies.
- Changes made on the clone come back through `git pull` + `bd import`.
- `bd init`'s credential key is removed from history before the first push.
- Commits in linked worktrees (builder branches) don't touch `.beads/issues.jsonl`.

## Updating the kit

Edit, bump `version` in `.claude-plugin/plugin.json`, commit and push. Then run
`/plugin update agentic-kit@domenickp-kit` (or `claude plugin update …`) on each machine.
