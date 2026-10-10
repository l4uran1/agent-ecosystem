#!/usr/bin/env bash
# Tests for the optional templates/Makefile. They build a fake ecosystem repo whose
# bootstrap.sh and repo Makefiles only print what they receive, so nothing touches git,
# Docker or the network.
#
# Usage: tests/makefile.test.sh

set -uo pipefail

MAKEFILE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/templates/Makefile"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

passed=0 failed=0

# A fake ecosystem repo with two repos, api and web. Like many real Makefiles, api lists
# a target named like one of its folders (build) in .PHONY.
eco="$TMP/eco"
mkdir -p "$eco"
cp "$MAKEFILE" "$eco/Makefile"
printf '#!/usr/bin/env bash\necho "bootstrap $*"\n' > "$eco/bootstrap.sh"
chmod +x "$eco/bootstrap.sh"
printf '# Repos\n\n' > "$eco/repos.txt"
for repo in api web; do
  mkdir -p "$eco/$repo"
  printf '.PHONY: build\nbuild:\n\t@echo "%s $@"\n%%:\n\t@echo "%s $@"\n' "$repo" "$repo" > "$eco/$repo/Makefile"
  echo "$repo git@example.com:acme/$repo.git core" >> "$eco/repos.txt"
done
mkdir -p "$eco/api/build"   # "make api/build" must still reach api's Makefile

run() { make --no-print-directory -C "$eco" "$@" 2>&1; }

# expect <description> <expected output> <make args...>
expect() {
  local desc="$1" want="$2" got; shift 2
  got="$(run "$@")"
  if [[ "$got" == "$want" ]]; then
    passed=$((passed + 1)); echo "ok   $desc"
  else
    failed=$((failed + 1)); echo "FAIL $desc"
    echo "     expected: $want"; echo "     got:      $got"
  fi
}

# expect_failure <description> <make args...>
expect_failure() {
  local desc="$1"; shift
  if run "$@" > /dev/null; then
    failed=$((failed + 1)); echo "FAIL $desc (exited 0)"
  else
    passed=$((passed + 1)); echo "ok   $desc"
  fi
}

# expect_listed <description> <regex> <make args...>
expect_listed() {
  local desc="$1" pattern="$2" got; shift 2
  got="$(run "$@")"
  if grep -qE -- "$pattern" <<< "$got"; then
    passed=$((passed + 1)); echo "ok   $desc"
  else
    failed=$((failed + 1)); echo "FAIL $desc (output must match /$pattern/)"
    printf '     | %s\n' "${got//$'\n'/$'\n     | '}"
  fi
}

# --- bootstrap.sh shortcuts ------------------------------------------------

expect "sync runs bootstrap.sh" "bootstrap " sync
expect "sync-all runs bootstrap.sh --all" "bootstrap --all" sync-all
expect "status runs bootstrap.sh status" "bootstrap status" status
expect "branch ID=<id> creates the branches of a change" "bootstrap branch add-dark-mode" branch ID=add-dark-mode
expect "branch NAME= REPOS= passes the repos" "bootstrap branch fix/login api web" branch NAME=fix/login "REPOS=api web"
expect_failure "branch without ID or NAME+REPOS fails" branch
expect_failure "branch with NAME and no REPOS fails" branch NAME=fix/login
expect "check-approved ID=<id> runs the check" "bootstrap check-approved add-dark-mode" check-approved ID=add-dark-mode
expect_failure "check-approved without ID fails" check-approved
expect "doctor runs bootstrap.sh doctor" "bootstrap doctor" doctor
expect "tests runs bootstrap.sh tests" "bootstrap tests" tests

# --- <repo>/<target> ------------------------------------------------------

expect "<repo>/<target> runs the target in that repo" "web test" web/test
expect "<repo>/<target> works even if the repo has a folder with that name" "api build" api/build
expect_failure "<repo>/<target> fails for a repo not in repos.txt" ghost/test

# --- development environment ----------------------------------------------

expect_failure "environment targets do not exist without ENV_REPO" up
expect "environment targets run in ENV_REPO" "api up" up ENV_REPO=api
expect "ENV_TARGETS sets which targets are delegated" "api seed" seed ENV_REPO=api "ENV_TARGETS=seed"

# --- help -----------------------------------------------------------------

expect_listed "help is the default target and lists the commands" "check-approved"
expect_listed "help lists <repo>/<target>" "<repo>/<target>" help
expect_listed "help lists the environment targets when ENV_REPO is set" "up.*api" help ENV_REPO=api

echo
echo "Passed: $passed · Failed: $failed"
[[ $failed -eq 0 ]]
