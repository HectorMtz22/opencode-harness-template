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
# Summary
# ---------------------------------------------------------------------------
printf '\n%s passed, %s failed (%s total)\n' "$PASS" "$FAIL" "$((PASS + FAIL))"
[ "$FAIL" -eq 0 ]
