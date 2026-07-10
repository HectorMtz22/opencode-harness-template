# Changelog

All notable changes to the Claude Code harness template are documented here.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Releases are cut with `/harness-release` (`bin/harness release <level>`), which
rolls the **Unreleased** section below into a dated version heading and tags
`vX.Y.Z`. Add your in-flight changes under **Unreleased**.

## [Unreleased]

## [0.1.0] - 2026-07-08

### Added

- Harness versioning: a `VERSION` file, this `CHANGELOG.md`, and a
  `/harness-release` command backed by a tested `bin/harness` helper
  (semver bump, changelog roll, `git commit` + `git tag vX.Y.Z`).
- `.claude/harness-manifest` classifying every harness path as `sync`,
  `region`, or `ignore` — the basis for a future `/harness-sync`.
- `tests/test.sh`, the repo's first test harness (self-contained, no bats).
- Planning and building commands: `/task-init`, `/issues-init`,
  `/task-implement`, `/task-run`, plus tracker setup via `/harness-setup`
  and `/harness-bootstrap`.
