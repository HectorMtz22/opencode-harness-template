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
# Summary
# ---------------------------------------------------------------------------
printf '\n%s passed, %s failed (%s total)\n' "$PASS" "$FAIL" "$((PASS + FAIL))"
[ "$FAIL" -eq 0 ]
