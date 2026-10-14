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

## First-time setup (once per machine)

You need **git**, **Node.js**, **bd** (beads), **Claude Code**, and optionally **gh** (the
GitHub CLI, used to create repos). The kit was built and tested with **bd 0.61**.

### Windows 11

Run these in **PowerShell**:

```powershell
winget install --id Git.Git -e            # includes Git Bash, which runs the kit's scripts
winget install --id OpenJS.NodeJS.LTS -e
winget install --id GitHub.cli -e
irm https://raw.githubusercontent.com/gastownhall/beads/main/install.ps1 | iex   # bd
irm https://claude.ai/install.ps1 | iex                                           # Claude Code
```

Then **open a new terminal** so the PATH changes take effect, and check everything:

```powershell
git --version; node --version; gh --version; bd version; claude --version
gh auth login
```

Notes:
- The kit's scripts are POSIX shell. Run them from **Git Bash** (`sh scripts/…`), not from
  PowerShell or cmd.
- If `bd init` reports that it can't find or start Dolt, install it (`scoop install dolt`, or
  the MSI from https://github.com/dolthub/dolt/releases) and open a new terminal.
- If a Windows firewall prompt appears for `bd.exe` or `dolt.exe`, allow it. bd talks to its
  database over a local loopback port.

### macOS

Install [Homebrew](https://brew.sh) if you don't have it, then:

```bash
xcode-select --install          # git and command-line tools (skip if already installed)
brew install node gh beads
curl -fsSL https://claude.ai/install.sh | bash      # Claude Code
git --version; node --version; gh --version; bd version; claude --version
gh auth login
```

### Linux

Debian/Ubuntu shown. On other distros, use the equivalent package manager for git and Node.js.

```bash
sudo apt update && sudo apt install -y git curl
# Node.js LTS via nvm (or your distro's package, if it's v20+)
curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
. ~/.nvm/nvm.sh && nvm install --lts
# GitHub CLI: follow https://github.com/cli/cli/blob/trunk/docs/install_linux.md
curl -fsSL https://raw.githubusercontent.com/gastownhall/beads/main/scripts/install.sh | bash   # bd
curl -fsSL https://claude.ai/install.sh | bash                                                 # Claude Code
git --version; node --version; gh --version; bd version; claude --version
gh auth login
```

If you use Homebrew on Linux, `brew install node gh beads` covers three of these.

### All platforms: install the plugin and get the scripts

1. Install the plugin, either from inside a Claude Code session:
   ```
   /plugin marketplace add domenickp/claude-agentic-kit
   /plugin install agentic-kit@domenickp-kit
   ```
   or from a terminal:
   ```bash
   claude plugin marketplace add domenickp/claude-agentic-kit
   claude plugin install agentic-kit@domenickp-kit
   ```
   Restart Claude Code afterwards. The `builder` agent and the skills load when a session starts.
2. Clone this repo somewhere stable so the setup scripts are easy to run by hand:
   ```bash
   git clone https://github.com/domenickp/claude-agentic-kit.git ~/claude-agentic-kit
   ```
3. Set your git identity if you haven't already, because the scripts make commits:
   ```bash
   git config --global user.name "Your Name"
   git config --global user.email "you@example.com"
   ```

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

Each session: `git pull --rebase && bd import` → work → `git commit` (auto-exports issues) → `git pull --rebase && bd import` → `git push`.
Always commit (export) issue changes **before** a pull + import, or the import reverts them.

## Updating the kit

Edit, bump `version` in `.claude-plugin/plugin.json`, commit and push. Then run
`/plugin update agentic-kit@domenickp-kit` (or `claude plugin update …`) on each machine.

## License

[MIT](LICENSE). Free to use and adapt, including commercially. Keep the copyright notice and license text in copies.
