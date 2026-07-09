#!/usr/bin/env bash
# Self-contained test runner for bin/harness (no bats — not installed).
# Runs on macOS system bash 3.2 + BSD tools. Sources bin/harness to unit-test
# the pure helpers; uses temp git repos to test cmd_release.
#
# Each assertion is isolated: a single failure records a FAIL and keeps going.
# Exits non-zero if any assertion failed.

HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/.." && pwd)

# Source the script under test. The guard in bin/harness prevents main from
# running on source.
. "$ROOT/bin/harness"

PASS=0
FAIL=0

TMPFILES=""
TMPDIRS=""
cleanup() {
  [ -n "$TMPFILES" ] && rm -f $TMPFILES
  [ -n "$TMPDIRS" ] && rm -rf $TMPDIRS
  return 0
}
trap cleanup EXIT

mktmp() {
  local f
  f=$(mktemp "${TMPDIR:-/tmp}/harness-test.XXXXXX")
  TMPFILES="$TMPFILES $f"
  printf '%s' "$f"
}

mktmpdir() {
  local d
  d=$(mktemp -d "${TMPDIR:-/tmp}/harness-test.XXXXXX")
  TMPDIRS="$TMPDIRS $d"
  printf '%s' "$d"
}

assert_eq() {
  # assert_eq "description" expected actual
  local desc="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    printf 'ok   - %s\n' "$desc"
    PASS=$((PASS + 1))
  else
    printf 'FAIL - %s\n' "$desc"
    printf '         expected: [%s]\n' "$expected"
    printf '         actual:   [%s]\n' "$actual"
    FAIL=$((FAIL + 1))
  fi
}

assert_ok() {
  # assert_ok "description" rc
  local desc="$1" rc="$2"
  if [ "$rc" -eq 0 ]; then
    printf 'ok   - %s\n' "$desc"
    PASS=$((PASS + 1))
  else
    printf 'FAIL - %s (expected rc 0, got %s)\n' "$desc" "$rc"
    FAIL=$((FAIL + 1))
  fi
}

assert_nonzero() {
  # assert_nonzero "description" rc
  local desc="$1" rc="$2"
  if [ "$rc" -ne 0 ]; then
    printf 'ok   - %s\n' "$desc"
    PASS=$((PASS + 1))
  else
    printf 'FAIL - %s (expected non-zero rc, got 0)\n' "$desc"
    FAIL=$((FAIL + 1))
  fi
}

# ---------------------------------------------------------------------------
# semver_cmp
# ---------------------------------------------------------------------------
assert_eq "semver_cmp 1.2.3 1.2.4 -> -1" "-1" "$(semver_cmp 1.2.3 1.2.4)"
assert_eq "semver_cmp 1.2.3 1.2.3 ->  0" "0" "$(semver_cmp 1.2.3 1.2.3)"
assert_eq "semver_cmp 2.0.0 1.9.9 ->  1" "1" "$(semver_cmp 2.0.0 1.9.9)"
assert_eq "semver_cmp 0.10.0 0.9.0 -> 1 (numeric, not lexical)" "1" "$(semver_cmp 0.10.0 0.9.0)"
assert_eq "semver_cmp 1.0.0 1.0.10 -> -1 (numeric, not lexical)" "-1" "$(semver_cmp 1.0.0 1.0.10)"

# ---------------------------------------------------------------------------
# semver_bump
# ---------------------------------------------------------------------------
assert_eq "semver_bump 0.1.0 patch -> 0.1.1" "0.1.1" "$(semver_bump 0.1.0 patch)"
assert_eq "semver_bump 0.1.0 minor -> 0.2.0" "0.2.0" "$(semver_bump 0.1.0 minor)"
assert_eq "semver_bump 0.1.0 major -> 1.0.0" "1.0.0" "$(semver_bump 0.1.0 major)"
assert_eq "semver_bump 1.4.9 minor -> 1.5.0 (resets patch)" "1.5.0" "$(semver_bump 1.4.9 minor)"
assert_eq "semver_bump 3.7.2 major -> 4.0.0 (resets minor+patch)" "4.0.0" "$(semver_bump 3.7.2 major)"
semver_bump 1.0.0 bogus >/dev/null 2>&1
assert_nonzero "semver_bump with unknown level fails" "$?"

# ---------------------------------------------------------------------------
# manifest_tier / manifest_paths
# ---------------------------------------------------------------------------
MANIFEST=$(mktmp)
cat > "$MANIFEST" <<'EOF'
# harness manifest fixture
sync   HARNESS.md
sync   .claude/commands/task-init.md

region CLAUDE.md
region .gitignore

# trailing comment
ignore README.md
ignore VERSION
EOF

assert_eq "manifest_tier: sync path" "sync" "$(manifest_tier "$MANIFEST" HARNESS.md)"
assert_eq "manifest_tier: region path" "region" "$(manifest_tier "$MANIFEST" CLAUDE.md)"
assert_eq "manifest_tier: listed ignore path" "ignore" "$(manifest_tier "$MANIFEST" README.md)"

t_out=$(manifest_tier "$MANIFEST" nope/not-listed.md)
t_rc=$?
assert_eq "manifest_tier: unlisted path prints nothing" "" "$t_out"
assert_nonzero "manifest_tier: unlisted path returns non-zero" "$t_rc"

MANIFEST_UNKNOWN_TIER=$(mktmp)
cat > "$MANIFEST_UNKNOWN_TIER" <<'EOF'
sync HARNESS.md
bogus some/path.md
EOF
manifest_tier "$MANIFEST_UNKNOWN_TIER" HARNESS.md >/dev/null 2>&1
assert_nonzero "manifest_tier: unknown tier is malformed -> non-zero" "$?"

MANIFEST_MISSING_PATH=$(mktmp)
cat > "$MANIFEST_MISSING_PATH" <<'EOF'
sync HARNESS.md
sync
EOF
manifest_tier "$MANIFEST_MISSING_PATH" HARNESS.md >/dev/null 2>&1
assert_nonzero "manifest_tier: line without a path -> non-zero" "$?"

exp_sync=$(printf '%s\n' 'HARNESS.md' '.claude/commands/task-init.md')
assert_eq "manifest_paths sync" "$exp_sync" "$(manifest_paths "$MANIFEST" sync)"
exp_region=$(printf '%s\n' 'CLAUDE.md' '.gitignore')
assert_eq "manifest_paths region" "$exp_region" "$(manifest_paths "$MANIFEST" region)"
exp_ignore=$(printf '%s\n' 'README.md' 'VERSION')
assert_eq "manifest_paths ignore" "$exp_ignore" "$(manifest_paths "$MANIFEST" ignore)"

# ---------------------------------------------------------------------------
# cmd_release (exercised against throwaway temp git repos)
# ---------------------------------------------------------------------------
setup_release_repo() {
  # Creates a clean git repo with VERSION=0.1.0, a Keep-a-Changelog CHANGELOG
  # with content under Unreleased, and an unrelated tracked file. Echoes path.
  local repo
  repo=$(mktmpdir)
  git -C "$repo" init -q
  git -C "$repo" config user.email "test@example.com"
  git -C "$repo" config user.name "Harness Test"
  git -C "$repo" config commit.gpgsign false
  printf '0.1.0\n' > "$repo/VERSION"
  cat > "$repo/CHANGELOG.md" <<'EOF'
# Changelog

All notable changes to this harness are documented here.
The format is based on Keep a Changelog.

## [Unreleased]

- Added the widget.
- Fixed the doodad.
EOF
  printf 'unrelated tracked file\n' > "$repo/notes.txt"
  git -C "$repo" add -A
  git -C "$repo" commit -q -m "init"
  printf '%s' "$repo"
}

# --- happy path: minor release ---
REPO=$(setup_release_repo)
(cd "$REPO" && HARNESS_RELEASE_DATE=2026-07-08 cmd_release minor) >/dev/null 2>&1
assert_ok "cmd_release minor exits 0" "$?"
assert_eq "cmd_release bumps VERSION 0.1.0 -> 0.2.0" "0.2.0" "$(cat "$REPO/VERSION")"

grep -q '^## \[0.2.0\] - 2026-07-08$' "$REPO/CHANGELOG.md"
assert_ok "changelog gains '## [0.2.0] - 2026-07-08' heading" "$?"
grep -q '^## \[Unreleased\]$' "$REPO/CHANGELOG.md"
assert_ok "changelog keeps '## [Unreleased]' heading" "$?"

uline=$(grep -n '^## \[Unreleased\]$' "$REPO/CHANGELOG.md" | head -1 | cut -d: -f1)
hline=$(grep -n '^## \[0.2.0\] - 2026-07-08$' "$REPO/CHANGELOG.md" | head -1 | cut -d: -f1)
cline=$(grep -n '^- Added the widget.$' "$REPO/CHANGELOG.md" | head -1 | cut -d: -f1)
if [ -n "$uline" ] && [ -n "$hline" ] && [ -n "$cline" ] && [ "$uline" -lt "$hline" ] && [ "$hline" -lt "$cline" ]; then
  release_order_ok=0
else
  release_order_ok=1
fi
assert_ok "prior Unreleased content now sits under the new version heading" "$release_order_ok"

assert_eq "release commit subject" "chore(harness): release v0.2.0" "$(git -C "$REPO" log -1 --pretty=%s)"
git -C "$REPO" rev-parse -q --verify refs/tags/v0.2.0 >/dev/null 2>&1
assert_ok "tag v0.2.0 created" "$?"
[ -z "$(git -C "$REPO" status --porcelain)" ]
assert_ok "working tree clean after release (VERSION+CHANGELOG committed)" "$?"

# --- refuses on a dirty unrelated tracked file ---
REPO2=$(setup_release_repo)
printf 'local edit\n' >> "$REPO2/notes.txt"
(cd "$REPO2" && HARNESS_RELEASE_DATE=2026-07-08 cmd_release patch) >/dev/null 2>&1
assert_nonzero "cmd_release refuses on dirty unrelated tracked file" "$?"
assert_eq "VERSION untouched after refusal" "0.1.0" "$(cat "$REPO2/VERSION")"
git -C "$REPO2" rev-parse -q --verify refs/tags/v0.1.1 >/dev/null 2>&1
assert_nonzero "no tag created on refusal" "$?"

# --- allowed: only VERSION/CHANGELOG dirty ---
REPO3=$(setup_release_repo)
printf '\n- Pending tweak.\n' >> "$REPO3/CHANGELOG.md"
(cd "$REPO3" && HARNESS_RELEASE_DATE=2026-07-08 cmd_release patch) >/dev/null 2>&1
assert_ok "cmd_release proceeds when only CHANGELOG is pre-dirty" "$?"
assert_eq "VERSION bumped 0.1.0 -> 0.1.1" "0.1.1" "$(cat "$REPO3/VERSION")"

# ---------------------------------------------------------------------------
# The repo's real .claude/harness-manifest is well-formed
# ---------------------------------------------------------------------------
REAL_MANIFEST="$ROOT/.claude/harness-manifest"
manifest_paths "$REAL_MANIFEST" sync >/dev/null 2>&1
assert_ok "real manifest parses without error" "$?"
assert_eq "real manifest: bin/harness is sync" "sync" "$(manifest_tier "$REAL_MANIFEST" bin/harness)"
assert_eq "real manifest: CLAUDE.md is region" "region" "$(manifest_tier "$REAL_MANIFEST" CLAUDE.md)"
assert_eq "real manifest: README.md is ignore" "ignore" "$(manifest_tier "$REAL_MANIFEST" README.md)"
assert_eq "real manifest: harness-release.md is ignore" "ignore" "$(manifest_tier "$REAL_MANIFEST" .claude/commands/harness-release.md)"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
printf '\n%s passed, %s failed (%s total)\n' "$PASS" "$FAIL" "$((PASS + FAIL))"
[ "$FAIL" -eq 0 ]
