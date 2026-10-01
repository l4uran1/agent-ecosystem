#!/usr/bin/env bash
# Tests for bootstrap.sh. No dependencies beyond bash and git: every "remote" is a
# local repo in a temporary folder, so nothing touches the network.
#
# Usage: tests/bootstrap.test.sh

set -uo pipefail

SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/bootstrap.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com
export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com

passed=0 failed=0

# Creates a fresh ecosystem folder with two cloned repos (api, web) whose remotes are
# local repos on main. Prints the ecosystem folder.
setup() {
  local case_dir="$TMP/$1"
  mkdir -p "$case_dir/eco"
  for r in api web; do
    git init -q -b main "$case_dir/remote-$r"
    git -C "$case_dir/remote-$r" commit -q --allow-empty -m init
    printf '%s file://%s core\n' "$r" "$case_dir/remote-$r" >> "$case_dir/eco/repos.txt"
  done
  cp "$SCRIPT" "$case_dir/eco/"
  (cd "$case_dir/eco" && ./bootstrap.sh > /dev/null 2>&1)
  echo "$case_dir/eco"
}

pass() { passed=$((passed + 1)); echo "ok   $1"; }

# fail <description> <reason> <command output>
fail() {
  failed=$((failed + 1)); echo "FAIL $1 ($2)"
  printf '     | %s\n' "${3//$'\n'/$'\n     | '}"
}

# check_output <description> <expected exit code> <regex the output must match> <command...>
check_output() {
  local desc="$1" expected="$2" pattern="$3"; shift 3
  local out code
  out="$("$@" 2>&1)"; code=$?
  if [[ "$code" == "$expected" ]] && grep -qE -- "$pattern" <<< "$out"; then
    pass "$desc"
  else
    fail "$desc" "exit $code, expected $expected${pattern:+; output must match /$pattern/}" "$out"
  fi
}

# check <description> <expected exit code> <command...>
check() {
  local desc="$1" expected="$2"; shift 2
  check_output "$desc" "$expected" "" "$@"
}

# --- branch ---------------------------------------------------------------
# The failing repo goes first: a failure must not be hidden by a later success.

eco="$(setup branch-ok)"
check "branch: exits 0 when every repo gets the branch" 0 \
  bash -c "cd '$eco' && ./bootstrap.sh branch feature/x api web"

eco="$(setup branch-missing)"
check "branch: exits non-zero when a repo is not cloned" 1 \
  bash -c "cd '$eco' && ./bootstrap.sh branch feature/x ghost api"
check "branch: still creates the branch in the repos that exist" 0 \
  git -C "$eco/api" show-ref --verify --quiet refs/heads/feature/x

eco="$(setup branch-switch-fails)"
(cd "$eco" && ./bootstrap.sh branch feature/x api > /dev/null)
echo committed > "$eco/api/a"
git -C "$eco/api" add a && git -C "$eco/api" commit -q -m a
git -C "$eco/api" switch -q main
echo untracked > "$eco/api/a"   # switching back would overwrite it, so git refuses
check "branch: exits non-zero when switching to an existing branch fails" 1 \
  bash -c "cd '$eco' && ./bootstrap.sh branch feature/x api web"

eco="$(setup branch-fetch-fails)"
rm -rf "$eco/../remote-api"
check "branch: exits non-zero when the remote cannot be fetched" 1 \
  bash -c "cd '$eco' && ./bootstrap.sh branch feature/x api web"

# --- sync -----------------------------------------------------------------

eco="$(setup sync-background)"
(cd "$eco" && ./bootstrap.sh branch feature/x api > /dev/null)
git -C "$eco/../remote-api" commit -q --allow-empty -m c2
check "sync: exits 0 and updates main without leaving the feature branch" 0 \
  bash -c "cd '$eco' && ./bootstrap.sh > /dev/null \
    && [[ \$(git -C api branch --show-current) == feature/x ]] \
    && [[ \$(git -C api rev-parse main) == \$(git -C ../remote-api rev-parse main) ]]"

eco="$(setup sync-dirty-main)"
echo wip > "$eco/web/wip"
check "sync: exits 0 and leaves uncommitted changes on main alone" 0 \
  bash -c "cd '$eco' && ./bootstrap.sh > /dev/null && [[ \$(cat web/wip) == wip ]]"

eco="$(setup sync-fetch-fails)"
rm -rf "$eco/../remote-web"
check "sync: exits non-zero when a remote cannot be reached" 1 \
  bash -c "cd '$eco' && ./bootstrap.sh"

# --- tests ----------------------------------------------------------------

eco="$TMP/tests-cmd"
mkdir -p "$eco/tests" && cp "$SCRIPT" "$eco/"
printf '#!/usr/bin/env bash\necho fake suite ran\nexit 3\n' > "$eco/tests/bootstrap.test.sh"
chmod +x "$eco/tests/bootstrap.test.sh"
check_output "tests: runs the test suite and returns its exit code" 3 "fake suite ran" \
  bash -c "cd '$eco' && ./bootstrap.sh tests"

# --- check-approved -------------------------------------------------------

# An ecosystem repo cloned from a local "remote" whose main branch holds the proposal
# for add-dark-mode and the archived proposal for old-change. Prints its folder.
setup_approved() {
  local case_dir="$TMP/$1" remote="$TMP/$1/remote-eco"
  git init -q -b main "$remote"
  mkdir -p "$remote/openspec/changes/add-dark-mode" "$remote/openspec/changes/archive/2026-01-15-old-change"
  echo proposal > "$remote/openspec/changes/add-dark-mode/proposal.md"
  echo proposal > "$remote/openspec/changes/archive/2026-01-15-old-change/proposal.md"
  git -C "$remote" add . && git -C "$remote" commit -q -m proposals
  git clone -q "$remote" "$case_dir/eco"
  cp "$SCRIPT" "$case_dir/eco/"
  echo "$case_dir/eco"
}

eco="$(setup_approved approved)"
check "check-approved: exits 0 when the proposal is on the remote main branch" 0 \
  bash -c "cd '$eco' && ./bootstrap.sh check-approved add-dark-mode"
check "check-approved: exits 0 when the proposal is already archived" 0 \
  bash -c "cd '$eco' && ./bootstrap.sh check-approved old-change"
check "check-approved: exits 1 when the proposal is not on the remote main branch" 1 \
  bash -c "cd '$eco' && ./bootstrap.sh check-approved unknown-change"
mkdir -p "$eco/openspec/changes/local-only" && echo draft > "$eco/openspec/changes/local-only/proposal.md"
check "check-approved: exits 1 when the proposal only exists locally" 1 \
  bash -c "cd '$eco' && ./bootstrap.sh check-approved local-only"
git -C "$eco/../remote-eco" switch -q -c spec/pending
mkdir -p "$eco/../remote-eco/openspec/changes/pending"
echo proposal > "$eco/../remote-eco/openspec/changes/pending/proposal.md"
git -C "$eco/../remote-eco" add . && git -C "$eco/../remote-eco" commit -q -m pending
git -C "$eco/../remote-eco" switch -q main
check "check-approved: exits 1 when the proposal is only on an unmerged branch" 1 \
  bash -c "cd '$eco' && ./bootstrap.sh check-approved pending"
check "check-approved: sees proposals merged after the last fetch" 0 \
  bash -c "cd '$eco' && git -C ../remote-eco merge -q spec/pending && ./bootstrap.sh check-approved pending"
check "check-approved: exits 1 without an id" 1 \
  bash -c "cd '$eco' && ./bootstrap.sh check-approved"
check "check-approved: exits 1 with an id that is not kebab-case" 1 \
  bash -c "cd '$eco' && ./bootstrap.sh check-approved ../add-dark-mode"

echo
echo "Passed: $passed · Failed: $failed"
[[ $failed -eq 0 ]]
