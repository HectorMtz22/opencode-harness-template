# CLAUDE.md

Guidance for Claude Code working in this repo. Read this first, then
[`HARNESS.md`](HARNESS.md) for the day-to-day TDD + agent workflow.

## What this is

<!-- Describe your repo in one or two sentences. The template assumes a
     multi-project monorepo, but a single script or package works just as well —
     in that case, delete the project table and the parallel-agents notes. -->

`<repo>` is a **multi-project monorepo**. Each top-level directory is a
self-contained project with its own dependencies, README, and tests. There is no
shared package — keep projects independent.

| Project | What | Stack | Tests |
|---|---|---|---|
| [`<project-a>/`](<project-a>/) | <one-line description> | <stack> | `<test command>` |
| [`<project-b>/`](<project-b>/) | <one-line description> | <stack> | `<test command>` |

Pick one project as the **gold-standard layout** and mirror it when another
project grows past a single script. A typical layout:

```
src/<pkg>/
  features/<feature>/{service,command,screen}.py   # one folder per feature
  shared/{...}.py                                   # cross-feature helpers
tests/
  features/<feature>/test_*.py                      # mirrors src tree
  shared/test_*.py
  conftest.py                                        # fixtures
```

## Core principles

1. **Simplest thing that works.** Prefer the smallest change that satisfies the
   test. No speculative abstraction, no new dependency without a reason. A shell
   script or single file is a valid project — don't "promote" it to a package
   until it earns it.
2. **TDD, always.** Red → green → refactor. New behavior starts with a failing
   test. See [`HARNESS.md`](HARNESS.md).
3. **Verify before claiming done.** Run the tests (or the actual command) and
   report real output. Never say "done" on an unrun change.
4. **Keep projects isolated.** Don't reach across project boundaries or add a
   root-level dependency.
5. **Match the surrounding code** — naming, comment density, idioms.

## Per-project commands

```bash
# <project-a>
<test command>          # test
<run command>           # run
```

## Conventions

- **Commits:** [Conventional Commits](https://www.conventionalcommits.org/),
  scoped per project: `feat(<project>): …`, `fix(<project>): …`,
  `test(<project>): …`, `chore: …`. One project per commit where possible.
- **PRs:** one feature per PR; opened once the branch is verified, green,
  committed, and clean (see [`HARNESS.md`](HARNESS.md)). Code-review *fixes* wait
  for the user.
- **Branch off the default branch first — never commit to it directly.** Commit
  at green points so the branch is PR-ready.

## Workflow & agents

The full loop (brainstorm → spec → issue(s) → worktree → TDD → verify → review →
PR) lives in [`HARNESS.md`](HARNESS.md) and [`AGENTS.md`](AGENTS.md), wrapped by
four commands — a planning pair, **`/task-init`** (one task → issue(s)) and
**`/issues-init`** (one epic → many linked issues), and a building pair,
**`/task-implement`** (issues you name → PRs) and **`/task-run`** (the whole
backlog, auto-ordered → PRs). Key rules:

- **Always use superpowers.** Invoke the named skill at each stage
  (`brainstorming`, `using-git-worktrees`, `test-driven-development`,
  `dispatching-parallel-agents`, `verification-before-completion`,
  `requesting-code-review`). **Report findings, don't auto-fix.**
- **Specs and plans are local-only** under `docs/superpowers/` (gitignored).
  **Never commit them.** The committed record is the code + PR.
- **Issues live in the tracker** (configured in `.claude/tracker.md` — run `/harness-setup` to create it) — project
  `project_code`. Each issue gets a project label and a type label
  (`feat`/`fix`/`refactor`/`test`/`docs`/`chore`); states go
  `Todo → In Progress → In Review (PR open) → Done (merged)`. Not in local files.
- **Always use worktrees** under `.worktrees/` (gitignored) for implementation;
  never work in the main checkout. Multiple issues run as parallel agents, one
  worktree each.
- **Conventional commits always**, scoped per sub-project.
