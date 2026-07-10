# Claude Code Harness Template

A drop-in **development harness** for working with [Claude Code](https://claude.com/claude-code)
(and the [`superpowers`](https://github.com/obra/superpowers) plugin) on any repo.

It encodes one repeatable loop — **brainstorm → spec → issue → worktree → TDD →
verify → review → PR** — and wraps it in slash commands so an agent (or you)
can drive a change end-to-end without improvising the process. A planning pair
(`/task-init`, `/issues-init`) and a building pair (`/task-implement`,
`/task-run`) scale the loop from a single task up to a whole epic/backlog.

> This template was extracted from a real multi-project repo. The project-specific
> bits (project names, issue-tracker IDs, test commands) have been replaced with
> `<placeholders>`. Fill them in once and the workflow is yours.

## What's in here

| File | What it is |
|---|---|
| [`CLAUDE.md`](CLAUDE.md) | Project instructions Claude Code reads first. Edit the project table + commands. |
| [`HARNESS.md`](HARNESS.md) | The TDD loop in detail — the *how* of every stage. |
| [`AGENTS.md`](AGENTS.md) | The *why* of worktrees, specs, and issue tracking. |
| [`.claude/commands/task-init.md`](.claude/commands/task-init.md) | `/task-init` — brainstorm → local spec → file issue(s). |
| [`.claude/commands/issues-init.md`](.claude/commands/issues-init.md) | `/issues-init` — decompose an epic → many linked issues (parent grouping + blocks relations). |
| [`.claude/commands/task-implement.md`](.claude/commands/task-implement.md) | `/task-implement` — worktree → TDD → verify → review → PR. |
| [`.claude/commands/task-run.md`](.claude/commands/task-run.md) | `/task-run` — read the backlog, order it (relations + file-overlap), drive `/task-implement` batch by batch. |
| [`.claude/commands/harness-setup.md`](.claude/commands/harness-setup.md) | `/harness-setup` — choose tracker, write `.claude/tracker.md` (offline). |
| [`.claude/commands/harness-bootstrap.md`](.claude/commands/harness-bootstrap.md) | `/harness-bootstrap` — create project, states, labels, and weekly cycles in the live tracker (idempotent). |
| [`.claude/commands/harness-sync.md`](.claude/commands/harness-sync.md) | `/harness-sync` — pull harness updates in, or push local harness changes back as a PR. |
| [`.claude/commands/harness-release.md`](.claude/commands/harness-release.md) | `/harness-release` — cut a version (template repo only). |
| [`bin/harness`](bin/harness) | Tested bash helper behind `/harness-release` + `/harness-sync` (semver, manifest, region splice, lock). |
| [`.claude/harness-manifest`](.claude/harness-manifest) | Classifies every path into a sync tier: `sync` / `region` / `ignore`. |
| [`.claude/tracker.md`](.claude/tracker.md) | Tracker config (single source of truth). Written by `/harness-setup`. |
| [`.gitignore`](.gitignore) | Ignores the local-only spec workspace and agent worktrees. |

## The loop

```
brainstorm ─▶ spec ─▶ issue(s) ─▶ worktree ─▶ TDD ─▶ verify ─▶ review ─▶ PR
  (skill)    (local)  (tracker)  (gitignored) (R/G/R) (skill)  (skill)
└─────────── /task-init ──────┘  └──────────── /task-implement ───────────┘
└────────── /issues-init ──────┘  └───────────────── /task-run ────────────┘
      (one epic → many                  (read the backlog and order
        linked issues)                    the batches for you)
```

- **Specs and plans stay local** under `docs/superpowers/` (gitignored). The
  durable record is the code, the tracked issue, and the PR — never the scratch spec.
- **Implementation always happens in a worktree** under `.worktrees/`
  (gitignored), never in the main checkout.
- **Issues live in your tracker** (Plane, Linear, GitHub Issues, …), not in local files.

## Use it

1. Click **Use this template** on GitHub (or copy these files into your repo).
2. Run `/harness-setup` (choose tracker, default Plane) — writes `.claude/tracker.md`.
3. Run `/harness-bootstrap` to create the project, states, labels, and 8 weekly cycles in your tracker.
4. Make sure Claude Code has the `superpowers` plugin and, optionally, an MCP
   server for your issue tracker.
5. Run `/task-init <idea>` to start a task, then `/task-implement <ISSUE-ID>`.
   For a bigger effort, `/issues-init <epic>` files a whole linked backlog and
   `/task-run` builds it in dependency order.

## Staying in sync with the template

The harness is versioned, so a repo that adopted it can keep up to date — and
send improvements back — instead of copy-pasting files.

- **Versions.** This template carries a [`VERSION`](VERSION) (semver) and a
  [`CHANGELOG.md`](CHANGELOG.md). The maintainer cuts a release with
  `/harness-release <major|minor|patch>`, which tags `vX.Y.Z`.
- **What's managed.** [`.claude/harness-manifest`](.claude/harness-manifest)
  sorts every path into a tier: `sync` (harness-owned — replaced wholesale on a
  pull), `region` (mixed — only the `HARNESS:BEGIN…END` block is replaced, your
  project content is kept), or `ignore` (never synced).
- **Pull updates** into a consumer with `/harness-sync` (needs the template
  added as a git remote named `harness`). It plans first (a dry run of every
  overwrite/splice + the version delta), then, on approval, applies and records
  the synced state in `.claude/harness.lock`.
- **Push a local harness fix back** with `/harness-sync push <topic>` — it
  branches, commits just the managed files, and opens a PR against the template.

Everything risky (semver math, manifest parsing, region splicing, lock I/O)
lives in the tested [`bin/harness`](bin/harness) helper; the commands are thin
orchestrators.

## Placeholders to fill in

Search the repo for these remaining placeholders and replace them with your specifics (tracker coordinates are handled separately — see below):

| Placeholder | Replace with | Appears in |
|---|---|---|
| `<project>` / `<project-a>` | Your sub-project directory name(s) | `CLAUDE.md`, `HARNESS.md`, `AGENTS.md`, commands |
| `<test command>` | How you run that project's tests (e.g. `uv run pytest`) | `CLAUDE.md`, `HARNESS.md` |
| `<run command>` | How you run the project | `CLAUDE.md` |

**Tracker coordinates** (formerly `<TRACKER>`, `<PROJECT-CODE>`, `<PROJECT_ID>`, `<tracker_mcp>`) are no longer edited by hand — run `/harness-setup` to choose your tracker and write `.claude/tracker.md`.

If you only have one project (a single script or package), drop the per-project
table and the parallel-agents section entirely — the harness works for a single
project too.

## License

[MIT](LICENSE) — do whatever you like with it.
