---
name: coordinate
description: Coordinator workflow for building a project with Sonnet builder subagents. Covers breaking work into bd (beads) issues, writing interface contracts first, sending builders self-contained briefs, checking their results yourself, merging and closing. Use when the user asks to coordinate or orchestrate builders, to run the coordinator/builder setup, or to build a multi-part project with subagents.
---

# Coordinating builders

You are the **coordinator**. You plan, write contracts, send out work, verify it and merge it.
**Builders** (the `builder` agent from this plugin, running on Sonnet) implement one scoped
task each. Your judgement is the expensive, scarce resource, so spend it on decomposition,
contracts and verification, not on typing code a builder can write.

This skill assumes the repo uses portable beads (see the `beads-portable` skill). Start every
session with that skill's session-start routine.

## Ground rules

- **You own bd.** Only you create, claim, update and close issues. Builders never write to bd,
  which avoids database contention and keeps one source of truth.
- **A builder's report is a claim, not proof.** You close an issue only after you have verified
  the work yourself.
- **Builders start cold.** They see only your brief and the repo. Anything they need must be
  in the brief or committed to the repo before you dispatch.
- **Is it worth it?** If the whole job is a single small change, do it yourself. Builders pay
  off when tasks are separable and each one is big enough to be worth writing a brief for.

## 1. Decompose into bd issues

Create an epic, then one issue per builder-sized task. A good task:
- has one clear owner: a set of files no other open task touches
- can be verified in a few minutes by a command or a short inspection
- fits in a single builder session (if you can't describe it in one brief, split it)

```bash
bd create "Workout tracker v1" -t epic -p 1 --description "..." --json
bd create "Routine JSON exporter" -t task -p 1 --parent <epic-id> \
  --description "..." --acceptance "..." --json
bd dep add <later-id> <earlier-id>      # later depends on earlier
bd ready --json                          # what is unblocked now
```

Steps that need a person (logins, consoles, physical devices, approvals) get their own issue
with `[human]` in the title, so they are never handed to a builder by mistake.

## 2. Write contracts before dispatching anything

Most multi-agent failures happen at the seams between agents, not inside a task. Before any
builder starts, commit to the repo:
- **Data shapes**: JSON schemas or annotated examples, field names and types, with one real sample
- **Interfaces**: function names, parameters, return values and error behaviour across module boundaries
- **File ownership**: which task owns which paths
- **Conventions**: language/runtime versions, test commands, folder layout

Put these in `docs/contracts.md` (or the language's natural home, such as a `types` file) and
**commit them**. Worktree builders branch from your current HEAD, so uncommitted contracts are
invisible to them. Small projects can put a short contract in each brief instead.

## 3. Write the brief

Each brief is self-contained. Use this template. Its sections match the report format the
builder agent returns.

```
## Brief: <bd issue id> — <title>

**Issue**: <id>   (read-only: `bd show <id> --readonly`)

**Goal**: <one or two sentences: what must be true when done>

**Context**:
- <why this exists, relevant decisions, pointers to files and docs to read first>

**Owns** (you may create/modify only these):
- <paths>

**Do not touch**:
- <paths owned by others, plus anything not listed above>

**Contract**:
- <exact interface, or "follow docs/contracts.md §X exactly">

**Acceptance criteria**:
- [ ] <checkable statement>
- [ ] <checkable statement>

**Validation** (run these, include their output):
$ <command>     # expect: <what passing looks like>

**Out of scope**: <tempting adjacent work to leave alone>
```

Mirror the acceptance criteria into the issue (`--acceptance`), so the issue alone is a
complete record.

## 4. Dispatch

Claim the issue first: `bd update <id> --claim`.

Use the Agent tool with the builder agent: `subagent_type: "builder"`, or
`"agentic-kit:builder"` if it is listed under the plugin namespace. Check the available agent
types in your context. Put the whole brief in `prompt`.

- **Sequential (default):** run in the main checkout. Use this when a task depends on another
  one, or when only one task is ready.
- **Parallel:** for two or more *independent* ready tasks with disjoint file ownership, send
  them in one message, each with `isolation: "worktree"`. Each builder works on its own branch
  in its own worktree. This needs a git repo with at least one commit.
- Keep about 2–4 builders in flight. More rarely helps: merge and verification work grows with
  every parallel stream, and that work is yours.

Never fill in a builder's result yourself. Wait for its report.

## 5. Verify, don't trust

For each report:
1. Read the diff: `git show <sha>` (or `git diff main...<branch>` for a worktree branch).
   Check that it stays within *Owns* and follows the contract.
2. **Rerun the validation commands yourself** and compare the output with the report.
3. Check every acceptance criterion against what you observed, not what the report says.
4. Act on the outcome:
   - Passes → merge (step 6).
   - Small gap → send the same builder a follow-up (SendMessage keeps its context) or fix it
     yourself if it's trivial.
   - Wrong approach → discard the branch, improve the brief, and dispatch again. A rewritten
     brief beats a long correction thread.

## 6. Merge and close

```bash
git merge --no-ff <builder-branch> -m "<id>: <title>"   # worktree tasks only
bd close <id> --reason "<what was delivered and how it was verified>" --json
bd create "<follow-up>" -p 2 --deps discovered-from:<id> --json   # one per DISCOVERED WORK item
git worktree remove <path> && git branch -d <builder-branch>      # after merging
```

Merge parallel branches one at a time, rerunning the validation after each merge. Two
correct branches can still break each other.

## 7. Close the session

Follow the `beads-portable` skill's session-end routine (commit, which exports
`issues.jsonl`, then push). Leave the next coordinator a short handoff: what's done, what's
in progress, and the next ready issue.

## Scaling to larger projects

- **Plan in layers.** Epic → feature issues → builder tasks. Write contracts at each boundary
  before going deeper.
- **Do integration tasks yourself.** Wiring modules together, end-to-end tests and anything
  that spans file ownership belongs to the coordinator, or to a dedicated integration issue
  dispatched only after its dependencies have merged.
- **Add specialist agents as patterns repeat.** If you keep writing the same kind of brief
  (tests, docs, migrations), copy `builder.md` into the project's `.claude/agents/` with that
  specialty baked in. Builders stay Sonnet; escalate a task to an Opus builder (`model:
  "opus"` on the Agent call) only if it failed twice on Sonnet with a good brief.
- **Hand off to the human** for credentials, paid or irreversible actions, product decisions,
  and anything a builder flagged as BLOCKED twice.
