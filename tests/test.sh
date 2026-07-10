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

# --- refuses to re-release an existing tag, leaving NO partial commit ---
REPO4=$(setup_release_repo)
git -C "$REPO4" tag v0.2.0                       # tag for the next minor already exists
before_head=$(git -C "$REPO4" rev-parse HEAD)
(cd "$REPO4" && HARNESS_RELEASE_DATE=2026-07-08 cmd_release minor) >/dev/null 2>&1
assert_nonzero "cmd_release refuses when tag v0.2.0 already exists" "$?"
assert_eq "VERSION untouched after tag-exists refusal" "0.1.0" "$(cat "$REPO4/VERSION")"
assert_eq "no partial release commit after tag-exists refusal" "$before_head" "$(git -C "$REPO4" rev-parse HEAD)"

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
assert_eq "real manifest: tests/test.sh is sync" "sync" "$(manifest_tier "$REAL_MANIFEST" tests/test.sh)"
assert_eq "real manifest: LICENSE is ignore" "ignore" "$(manifest_tier "$REAL_MANIFEST" LICENSE)"

# ---------------------------------------------------------------------------
# region_splice — replace only the marked block, preserve the rest
# ---------------------------------------------------------------------------
RB='<!-- HARNESS:BEGIN -->'
RE='<!-- HARNESS:END -->'

SPLICE_FILE=$(mktmp)
cat > "$SPLICE_FILE" <<EOF
project intro line
$RB
old harness line 1
old harness line 2
$RE
project outro line
EOF

NEWC=$(mktmp)
cat > "$NEWC" <<'EOF'
new harness line A
new harness line B
EOF

region_splice "$SPLICE_FILE" "$RB" "$RE" "$NEWC"
assert_ok "region_splice exits 0 on a well-formed file" "$?"
grep -q '^project intro line$' "$SPLICE_FILE"
assert_ok "region_splice preserves text before the block" "$?"
grep -q '^project outro line$' "$SPLICE_FILE"
assert_ok "region_splice preserves text after the block" "$?"
grep -q '^new harness line B$' "$SPLICE_FILE"
assert_ok "region_splice inserts the new content" "$?"
grep -q 'old harness line' "$SPLICE_FILE"
assert_nonzero "region_splice drops the old block content" "$?"
assert_eq "region_splice keeps exactly one BEGIN marker" "1" "$(grep -cxF "$RB" "$SPLICE_FILE")"
assert_eq "region_splice keeps exactly one END marker" "1" "$(grep -cxF "$RE" "$SPLICE_FILE")"

# --- error: markers missing, file untouched ---
NOMARK=$(mktmp)
printf 'just a normal file\nno markers here\n' > "$NOMARK"
NOMARK_BEFORE=$(cat "$NOMARK")
region_splice "$NOMARK" "$RB" "$RE" "$NEWC" >/dev/null 2>&1
assert_nonzero "region_splice fails when markers are missing" "$?"
assert_eq "region_splice leaves file unchanged when markers missing" "$NOMARK_BEFORE" "$(cat "$NOMARK")"

# --- error: unbalanced (BEGIN without END), file untouched ---
UNBAL=$(mktmp)
printf 'intro\n%s\nblock\n' "$RB" > "$UNBAL"
UNBAL_BEFORE=$(cat "$UNBAL")
region_splice "$UNBAL" "$RB" "$RE" "$NEWC" >/dev/null 2>&1
assert_nonzero "region_splice fails when END marker is missing (unbalanced)" "$?"
assert_eq "region_splice leaves file unchanged when unbalanced" "$UNBAL_BEFORE" "$(cat "$UNBAL")"

# ---------------------------------------------------------------------------
# lock_read / lock_write — consumer-side synced state round-trip
# ---------------------------------------------------------------------------
LOCK=$(mktmp)
lock_write "$LOCK" 0.3.0 abc123def harness
assert_ok "lock_write exits 0" "$?"
assert_eq "lock round-trip: version" "0.3.0" "$(lock_read "$LOCK" version)"
assert_eq "lock round-trip: commit" "abc123def" "$(lock_read "$LOCK" commit)"
assert_eq "lock round-trip: remote" "harness" "$(lock_read "$LOCK" remote)"

lock_read "$LOCK" nope >/dev/null 2>&1
assert_nonzero "lock_read on an absent key returns non-zero" "$?"
lock_read "${LOCK}.does-not-exist" version >/dev/null 2>&1
assert_nonzero "lock_read on a missing file returns non-zero" "$?"

# ---------------------------------------------------------------------------
# _max_semver — highest X.Y.Z from stdin, ignoring non-semver lines
# ---------------------------------------------------------------------------
assert_eq "_max_semver picks the highest (numeric, not lexical)" "0.10.0" \
  "$(printf '0.2.0\n0.10.0\n0.9.0\n' | _max_semver)"
assert_eq "_max_semver ignores non-semver lines" "1.0.0" \
  "$(printf 'garbage\nv1.0.0\n1.0.0\n0.9.9\n' | _max_semver)"
assert_eq "_max_semver with a single version" "2.3.4" "$(printf '2.3.4\n' | _max_semver)"
printf 'nope\n\n' | _max_semver >/dev/null 2>&1
assert_nonzero "_max_semver fails when no valid version present" "$?"

# ---------------------------------------------------------------------------
# region_extract — the lines strictly between the markers (exclusive)
# ---------------------------------------------------------------------------
EXTRACT_FILE=$(mktmp)
cat > "$EXTRACT_FILE" <<EOF
before
$RB
line one
line two
$RE
after
EOF
exp_block=$(printf '%s\n' 'line one' 'line two')
assert_eq "region_extract returns only the block content" "$exp_block" \
  "$(region_extract "$EXTRACT_FILE" "$RB" "$RE")"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
printf '\n%s passed, %s failed (%s total)\n' "$PASS" "$FAIL" "$((PASS + FAIL))"
[ "$FAIL" -eq 0 ]
