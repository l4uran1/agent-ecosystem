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

# check_absent <description> <regex the output must not match> <command...>
check_absent() {
  local desc="$1" pattern="$2"; shift 2
  local out
  out="$("$@" 2>&1)"
  if grep -qE -- "$pattern" <<< "$out"; then
    fail "$desc" "output must not match /$pattern/" "$out"
  else
    pass "$desc"
  fi
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

eco="$(setup branch-worktree-fails)"
mkdir -p "$eco/api/.worktrees/feature"
echo blocker > "$eco/api/.worktrees/feature/x"   # git cannot create the worktree there
check "branch: exits non-zero when the worktree cannot be created" 1 \
  bash -c "cd '$eco' && ./bootstrap.sh branch feature/x api web"

# --- branch: worktrees ----------------------------------------------------

eco="$(setup worktree-new)"
git -C "$eco/../remote-api" commit -q --allow-empty -m "after clone"
(cd "$eco" && ./bootstrap.sh branch feature/x api > /dev/null 2>&1)
check "worktree: creates the branch in <repo>/.worktrees/<branch>" 0 \
  bash -c "[[ \$(git -C '$eco/api/.worktrees/feature/x' branch --show-current) == feature/x ]]"
check "worktree: leaves the main checkout on the main branch" 0 \
  bash -c "[[ \$(git -C '$eco/api' branch --show-current) == main ]]"
check "worktree: starts from the latest main branch on the remote" 0 \
  bash -c "[[ \$(git -C '$eco/api/.worktrees/feature/x' rev-parse HEAD) == \$(git -C '$eco/../remote-api' rev-parse main) ]]"
check "worktree: the repo ignores .worktrees/ without touching its .gitignore" 0 \
  bash -c "[[ -z \$(git -C '$eco/api' status --porcelain) ]]"
check_output "worktree: run again, says where the existing worktree is" 0 "api/\.worktrees/feature/x" \
  bash -c "cd '$eco' && ./bootstrap.sh branch feature/x api"
check_output "status: lists the worktrees of each repo with their branch" 0 "\.worktrees/feature/x +feature/x" \
  bash -c "cd '$eco' && ./bootstrap.sh status"

eco="$(setup worktree-existing-branch)"
git -C "$eco/api" branch -q fix/old main
(cd "$eco" && ./bootstrap.sh branch fix/old api > /dev/null 2>&1)
check "worktree: an existing branch gets a worktree instead of a new branch" 0 \
  bash -c "[[ \$(git -C '$eco/api/.worktrees/fix/old' branch --show-current) == fix/old ]]"

eco="$(setup worktree-remote-branch)"
git -C "$eco/../remote-api" switch -q -c feature/shared
git -C "$eco/../remote-api" commit -q --allow-empty -m "pushed by someone else"
git -C "$eco/../remote-api" switch -q main
(cd "$eco" && ./bootstrap.sh branch feature/shared api > /dev/null 2>&1)
check "worktree: a branch already on the remote starts from it, not from the main branch" 0 \
  bash -c "[[ \$(git -C '$eco/api/.worktrees/feature/shared' rev-parse HEAD) == \$(git -C '$eco/../remote-api' rev-parse feature/shared) ]]"
check "worktree: a branch taken from the remote tracks it, so pull and push work" 0 \
  bash -c "[[ \$(git -C '$eco/api/.worktrees/feature/shared' rev-parse --abbrev-ref '@{upstream}') == origin/feature/shared ]]"

# A repo folder that is a symbolic link to a clone kept elsewhere.
setup_symlink() {
  local eco
  eco="$(setup "$1")"
  mv "$eco/api" "$eco/../clone-api" && ln -s ../clone-api "$eco/api"
  echo "$eco"
}

eco="$(setup_symlink worktree-symlink)"
(cd "$eco" && ./bootstrap.sh branch feature/x api > /dev/null 2>&1)
check "symlink: the link is replaced by a worktree of the branch at the same path" 0 \
  bash -c "[[ ! -L '$eco/api' && \$(git -C '$eco/api' branch --show-current) == feature/x ]]"
check "symlink: the clone the link pointed to stays on the main branch" 0 \
  bash -c "[[ \$(git -C '$eco/../clone-api' branch --show-current) == main ]]"
git -C "$eco/../remote-api" commit -q --allow-empty -m c2
check "sync: exits 0 and updates the main branch checked out in the clone the link pointed to" 0 \
  bash -c "cd '$eco' && ./bootstrap.sh > /dev/null \
    && [[ \$(git -C ../clone-api rev-parse main) == \$(git -C ../remote-api rev-parse main) ]]"
check_output "status: shows the branch of a repo folder that is a worktree" 0 "api +feature/x" \
  bash -c "cd '$eco' && ./bootstrap.sh status"

eco="$(setup_symlink worktree-symlink-fails)"
check "symlink: exits non-zero when the worktree cannot be created" 1 \
  bash -c "cd '$eco' && ./bootstrap.sh branch 'bad..name' api"
check "symlink: the link is restored when the worktree cannot be created" 0 \
  test -L "$eco/api"

eco="$(setup branch-fetch-fails)"
rm -rf "$eco/../remote-api"
check "branch: exits non-zero when the remote cannot be fetched" 1 \
  bash -c "cd '$eco' && ./bootstrap.sh branch feature/x api web"

# --- the workflow, with issues ------------------------------------------------
# scripts/host.sh and scripts/agent.sh are fakes: the host answers from .fake/ and logs every
# call, and the agent logs its arguments and, if asked, writes the file a step expects.

# An ecosystem repo with two cloned repos (api, web) and the fakes. Prints its folder.
setup_flow() {
  add_fakes "$(setup "$1")"
}

# Adds the fake host.sh and agent.sh to the ecosystem folder <eco>. Prints the folder.
add_fakes() {
  local eco="$1"
  mkdir -p "$eco/scripts" "$eco/.fake"
  cat > "$eco/scripts/host.sh" <<'EOF'
#!/usr/bin/env bash
F="$(cd "$(dirname "$0")/.." && pwd)/.fake"
echo "$*" >> "$F/host-calls"
case "$1" in
  issue-get)
    [[ -d "$F/issues/$2" ]] || { echo "!! no issue $2" >&2; exit 1; }
    cat "$F/issues/$2/$3" 2> /dev/null || true ;;
  pr-list) cat "$F/prs/$2/${3//\//_}" 2> /dev/null || true ;;
  pr-close) echo "  comment: $(cat "$4")" >> "$F/host-calls" ;;
  issue-comment) echo "  comment: $(cat "$3")" >> "$F/host-calls" ;;
  check-auth) [[ ! -f "$F/no-auth" ]] || { echo "!! gh is not logged in" >&2; exit 1; } ;;
esac
EOF
  cat > "$eco/scripts/agent.sh" <<'EOF'
#!/usr/bin/env bash
F="$(cd "$(dirname "$0")/.." && pwd)/.fake"
echo "AGENT=${AGENT:-} $*" >> "$F/agent-calls"
for a in "$@"; do
  case "$a" in
    "Summary: "*) [[ ! -f "$F/write-summary" ]] || echo "h2. Built" > "${a#Summary: }" ;;
    "Report: "*) [[ ! -f "$F/write-report" ]] || echo "All good" > "${a#Report: }" ;;
  esac
done
EOF
  chmod +x "$eco/scripts/host.sh" "$eco/scripts/agent.sh"
  echo "$eco"
}

# issue <eco> <n> <title> <repo...>: an issue whose spec lists the repos. LABELS sets its labels.
issue() {
  local d="$1/.fake/issues/$2" title="$3"; shift 3
  mkdir -p "$d"
  echo "$title" > "$d/title"
  { printf '## Context\nWhy.\n\n## Affected repos\n'
    printf -- '- %s\n' "$@"
    printf '\n## Acceptance criteria\n1. Given a user, when they export, then they get a CSV\n'
  } > "$d/body"
  printf '%s\n' ${LABELS:-} > "$d/labels"
}

# prs <eco> <repo> <branch> <lines>: the PRs the host lists for that branch.
prs() { mkdir -p "$1/.fake/prs/$2"; printf '%s\n' "$4" > "$1/.fake/prs/$2/${3//\//_}"; }

# logged <description> <eco> <host-calls|agent-calls> <regex>
logged() {
  if grep -qE -- "$4" "$2/.fake/$3" 2> /dev/null; then pass "$1"
  else fail "$1" "no line of $3 matches /$4/" "$(cat "$2/.fake/$3" 2> /dev/null)"; fi
}

# not_logged <description> <eco> <host-calls|agent-calls> <regex>
not_logged() {
  if grep -qE -- "$4" "$2/.fake/$3" 2> /dev/null; then fail "$1" "a line of $3 matches /$4/" "$(cat "$2/.fake/$3")"
  else pass "$1"; fi
}

has_branch() { git -C "$1" show-ref --verify --quiet "refs/heads/$2"; }

# branch <n>

eco="$(setup_flow issue-branch)"
issue "$eco" 42 "Export orders to CSV!" api
check_output "branch <n>: exits 0 and names the repos of the issue" 0 "repos of issue #42: api" \
  bash -c "cd '$eco' && ./bootstrap.sh branch 42"
check "branch <n>: creates feature/<n>-<slug of the title> in the repos of Affected repos" 0 \
  has_branch "$eco/api" feature/42-export-orders-to-csv
check "branch <n>: leaves the repos that are not listed alone" 1 \
  has_branch "$eco/web" feature/42-export-orders-to-csv

eco="$(setup_flow issue-branch-bug)"
LABELS="ui bug" issue "$eco" 7 "Login loops forever" web
(cd "$eco" && ./bootstrap.sh branch 7 > /dev/null 2>&1)
check "branch <n>: an issue labelled bug gets fix/<n>-<slug>" 0 \
  has_branch "$eco/web" fix/7-login-loops-forever

eco="$(setup_flow issue-branch-crlf)"
issue "$eco" 8 "Edited on the web" api web
sed -i.bak 's/$/\r/' "$eco/.fake/issues/8/body" && rm "$eco/.fake/issues/8/body.bak"
(cd "$eco" && ./bootstrap.sh branch 8 > /dev/null 2>&1)
check "branch <n>: reads a spec with Windows line ends (edited in the browser)" 0 \
  has_branch "$eco/web" feature/8-edited-on-the-web

eco="$(setup_flow issue-branch-unknown)"
issue "$eco" 9 "Ghost" api ghost
check_output "branch <n>: exits 1 when Affected repos names a repo not in repos.txt" 1 "repos.txt.*ghost" \
  bash -c "cd '$eco' && ./bootstrap.sh branch 9"
check "branch <n>: creates no branch when a repo is unknown" 1 has_branch "$eco/api" feature/9-ghost

eco="$(setup_flow issue-branch-no-repos)"
issue "$eco" 10 "No repos"
check_output "branch <n>: exits 1 when the spec lists no repo" 1 "Affected repos" \
  bash -c "cd '$eco' && ./bootstrap.sh branch 10"
check_output "branch <n>: exits 1 when the issue does not exist" 1 "no issue 11" \
  bash -c "cd '$eco' && ./bootstrap.sh branch 11"

eco="$(setup branch-no-repos)"
check_output "branch: exits 1 without repos and without an issue number" 1 "repos" \
  bash -c "cd '$eco' && ./bootstrap.sh branch feature/x"

# explore, propose, verify

eco="$(setup_flow flow-explore)"
(cd "$eco" && ./bootstrap.sh explore "CSV export" > /dev/null 2>&1)
logged "explore: starts the agent with the idea" "$eco" agent-calls "^AGENT= explore Idea: CSV export$"

eco="$(setup_flow flow-propose)"
(cd "$eco" && ./bootstrap.sh propose bug "Login loops" > /dev/null 2>&1)
logged "propose: starts the agent with the type, a draft folder in .work/ and the idea" "$eco" agent-calls \
  "^AGENT= propose Type: bug Draft: \.work/draft-[0-9]{8}-[A-Za-z0-9]{4} Idea: Login loops$"
check "propose: creates the draft folder" 0 bash -c "ls -d '$eco'/.work/draft-*/"
check_output "propose: exits 1 with an unknown type" 1 "feature.bug" \
  bash -c "cd '$eco' && ./bootstrap.sh propose story"

eco="$(setup_flow flow-verify)"
issue "$eco" 42 "Export orders" api
(cd "$eco" && ./bootstrap.sh verify 42 > /dev/null 2>&1)
logged "verify: starts the agent with the issue" "$eco" agent-calls "^AGENT= verify 42$"
check_output "verify: exits 1 without an issue number" 1 "verify 42" \
  bash -c "cd '$eco' && ./bootstrap.sh verify abc"

# apply

eco="$(setup_flow flow-apply)"
issue "$eco" 42 "Export orders" api web
(cd "$eco" && ./bootstrap.sh apply 42 > /dev/null 2>&1)
check "apply: creates the worktrees of the issue" 0 \
  test -d "$eco/web/.worktrees/feature/42-export-orders"
logged "apply: starts the agent with the issue, its branch and its worktrees" "$eco" agent-calls \
  "^AGENT= apply 42 Branch: feature/42-export-orders Worktrees: api/\.worktrees/feature/42-export-orders web/\.worktrees/feature/42-export-orders$"
check "apply: creates .work/<n>/ for the temporary documents" 0 test -d "$eco/.work/42"

eco="$(setup_flow flow-apply-no-repos)"
issue "$eco" 43 "No repos"
check "apply: exits 1 when the spec lists no repo" 1 bash -c "cd '$eco' && ./bootstrap.sh apply 43"
not_logged "apply: does not start the agent when the spec lists no repo" "$eco" agent-calls "apply"

# review

eco="$(setup_flow flow-review)"
issue "$eco" 42 "Export orders" api
prs "$eco" api feature/42-export-orders "open 7 https://host/acme/api/pull/7"
(cd "$eco" && AGENT=claude ./bootstrap.sh review 42 > /dev/null 2>&1)
logged "review: starts the agent with the worktrees, the PRs and the path of its report" "$eco" agent-calls \
  "^AGENT=claude review 42 Branch: feature/42-export-orders Worktrees: api/\.worktrees/feature/42-export-orders PRs of api: open 7 https://host/acme/api/pull/7 Report: \.work/42/review\.md$"
check_output "review: with AGENT_REVIEWER unset, only one agent reviews" 0 "^1$" \
  bash -c "grep -c review '$eco/.fake/agent-calls'"

eco="$(setup_flow flow-review-two)"
issue "$eco" 42 "Export orders" api
touch "$eco/.fake/write-report"
(cd "$eco" && AGENT=claude AGENT_REVIEWER=codex ./bootstrap.sh review 42 > /dev/null 2>&1)
logged "review: AGENT_REVIEWER reviews first, with its own report" "$eco" agent-calls \
  "^AGENT=codex review 42 .* Report: \.work/42/review-codex\.md$"
logged "review: then AGENT reviews, with the first report" "$eco" agent-calls \
  "^AGENT=claude review 42 .* First review: \.work/42/review-codex\.md, by codex Report: \.work/42/review\.md$"

eco="$(setup_flow flow-review-two-no-report)"
issue "$eco" 42 "Export orders" api
check_output "review: says so when AGENT_REVIEWER leaves no report" 0 "codex left no report" \
  bash -c "cd '$eco' && AGENT=claude AGENT_REVIEWER=codex ./bootstrap.sh review 42"
not_logged "review: without a first report, AGENT reviews alone" "$eco" agent-calls "First review"

# archive

# An issue implemented in api: worktree, branch pushed to the remote, and .work/42/.
setup_built() {
  local eco
  eco="$(setup_flow "$1")"
  issue "$eco" 42 "Export orders" api
  (cd "$eco" && ./bootstrap.sh apply 42 > /dev/null 2>&1)
  git -C "$eco/api/.worktrees/feature/42-export-orders" push -q origin HEAD 2> /dev/null
  rm "$eco/.fake/agent-calls"
  echo "$eco"
}

eco="$(setup_built archive-open-pr)"
prs "$eco" api feature/42-export-orders $'merged 6 https://host/pull/6\nopen 7 https://host/pull/7'
check_output "archive: exits 1 and names the PR when one is still open" 1 "api: PR not merged: https://host/pull/7" \
  bash -c "cd '$eco' && ./bootstrap.sh archive 42"
not_logged "archive: does not start the agent while a PR is open" "$eco" agent-calls "archive"

eco="$(setup_built archive-no-merged)"
check_output "archive: exits 1 when a repo has no merged PR of the branch" 1 "api: no merged PR of feature/42-export-orders" \
  bash -c "cd '$eco' && ./bootstrap.sh archive 42"

eco="$(setup_built archive-no-summary)"
prs "$eco" api feature/42-export-orders "merged 7 https://host/pull/7"
check_output "archive: exits 1 when the agent leaves no summary" 1 "No summary" \
  bash -c "cd '$eco' && ./bootstrap.sh archive 42"
not_logged "archive: without a summary the issue stays open" "$eco" host-calls "issue-close"
check "archive: without a summary the worktree is kept" 0 test -d "$eco/api/.worktrees/feature/42-export-orders"

eco="$(setup_built archive-ok)"
prs "$eco" api feature/42-export-orders "merged 7 https://host/pull/7"
touch "$eco/.fake/write-summary"
check_output "archive: exits 0 and says the issue is closed" 0 "#42 closed" \
  bash -c "cd '$eco' && ./bootstrap.sh archive 42"
logged "archive: starts the agent with the branch, the repos and the path of the summary" "$eco" agent-calls \
  "^AGENT= archive 42 Branch: feature/42-export-orders Repos: api Summary: \.work/42/summary\.md$"
logged "archive: publishes the summary on the issue" "$eco" host-calls "^  comment: h2. Built$"
logged "archive: closes the issue as completed" "$eco" host-calls "^issue-close 42 completed$"
check "archive: removes the worktree" 1 test -d "$eco/api/.worktrees/feature/42-export-orders"
check "archive: deletes the local branch" 1 has_branch "$eco/api" feature/42-export-orders
check "archive: deletes the remote branch" 1 has_branch "$eco/../remote-api" feature/42-export-orders
check "archive: deletes .work/<n>/" 1 test -d "$eco/.work/42"

eco="$(setup_built archive-dirty)"
prs "$eco" api feature/42-export-orders "merged 7 https://host/pull/7"
touch "$eco/.fake/write-summary"
echo wip > "$eco/api/.worktrees/feature/42-export-orders/wip"
check_output "archive: keeps a worktree with uncommitted changes, and says so" 0 "uncommitted changes" \
  bash -c "cd '$eco' && ./bootstrap.sh archive 42"
check "archive: keeps the branch of a worktree with uncommitted changes" 0 has_branch "$eco/api" feature/42-export-orders

eco="$(setup_built archive-undeletable)"
prs "$eco" api feature/42-export-orders "merged 7 https://host/pull/7"
touch "$eco/.fake/write-summary"
wt="$eco/api/.worktrees/feature/42-export-orders"
mkdir -p "$wt/cache" && echo x > "$wt/cache/f" && echo '/cache/' >> "$eco/api/.git/info/exclude"
chmod 555 "$wt/cache"   # like files a container left owned by root
check_output "archive: says how to remove a worktree it cannot delete" 0 "sudo rm -rf .*worktree prune" \
  bash -c "cd '$eco' && ./bootstrap.sh archive 42"
chmod -R u+w "$wt" 2> /dev/null

eco="$(add_fakes "$(setup_symlink archive-symlink)")"
issue "$eco" 42 "Export orders" api
(cd "$eco" && ./bootstrap.sh apply 42 > /dev/null 2>&1)
prs "$eco" api feature/42-export-orders "merged 7 https://host/pull/7"
touch "$eco/.fake/write-summary"
(cd "$eco" && ./bootstrap.sh archive 42 > /dev/null 2>&1)
check "archive: a repo that was a symbolic link is a link to its clone again" 0 \
  bash -c "[[ -L '$eco/api' && \$(git -C '$eco/api' branch --show-current) == main ]]"

# reject

eco="$(setup_built reject-no-reason)"
check_output "reject: exits 1 without a reason" 1 "reason" \
  bash -c "cd '$eco' && ./bootstrap.sh reject 42"

eco="$(setup_built reject-merged)"
prs "$eco" api feature/42-export-orders "merged 7 https://host/pull/7"
check_output "reject: exits 1 when a PR is already merged, and says to revert it" 1 "revert" \
  bash -c "cd '$eco' && ./bootstrap.sh reject 42 'Not needed'"
not_logged "reject: with a merged PR the issue stays open" "$eco" host-calls "issue-close"

eco="$(setup_built reject-ok)"
prs "$eco" api feature/42-export-orders "open 7 https://host/pull/7"
check_output "reject: exits 0 and says the issue is rejected" 0 "#42 rejected" \
  bash -c "cd '$eco' && ./bootstrap.sh reject 42 'Not needed any more'"
logged "reject: closes the open PRs" "$eco" host-calls "^pr-close api 7 "
logged "reject: with the reason as a comment" "$eco" host-calls "^  comment: Not needed any more$"
logged "reject: closes the issue as not planned" "$eco" host-calls "^issue-close 42 not-planned$"
check "reject: removes the worktree" 1 test -d "$eco/api/.worktrees/feature/42-export-orders"
check "reject: deletes .work/<n>/" 1 test -d "$eco/.work/42"

eco="$(setup_flow reject-no-repos)"
issue "$eco" 44 "Half-written proposal"
check "reject: an issue whose spec lists no repo is still rejected" 0 \
  bash -c "cd '$eco' && ./bootstrap.sh reject 44 'Duplicate'"
logged "reject: closes an issue whose spec lists no repo" "$eco" host-calls "^issue-close 44 not-planned$"

# --- sync -----------------------------------------------------------------

eco="$(setup sync-background)"
git -C "$eco/api" switch -q -c feature/x
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
printf '#!/usr/bin/env bash\necho second suite ran\n' > "$eco/tests/makefile.test.sh"
chmod +x "$eco/tests/makefile.test.sh"
check_output "tests: runs every tests/*.test.sh and fails if any fails" 3 "second suite ran" \
  bash -c "cd '$eco' && ./bootstrap.sh tests"

# --- doctor ---------------------------------------------------------------

# A filled-in ecosystem repo whose git host CLI is logged in. Prints its folder.
setup_filled() {
  local eco="$TMP/$1/eco"
  mkdir -p "$eco/docs/product/decisions" "$eco/scripts" "$eco/api/.git"
  git init -q -b main "$eco"
  cp "$SCRIPT" "$(dirname "$SCRIPT")/.gitignore" "$eco/"
  echo "api git@example.com:acme/api.git core" > "$eco/repos.txt"
  printf '# Acme ecosystem\n\nMain branch: main. Branches: feature/<n>-<slug>.\n' > "$eco/AGENTS.md"
  printf 'schema: spec-driven\ncontext: |\n  Product: invoicing for small shops.\n' > "$eco/openspec/config.yaml"
  printf '# System map\n\nLast reviewed: %s\n\n| api | user:<id>:events |\n' "$(date +%Y-%m-%d)" > "$eco/docs/system-map.md"
  printf '# Sensitive areas\n\n## Payments\n' > "$eco/docs/product/sensitive-areas.md"
  printf '# 0001 · Ecosystem repo\n\n- Date: 2026-01-15\n' > "$eco/docs/product/decisions/0001-ecosystem-repo.md"
  printf '#!/usr/bin/env bash\n[[ ! -f "$(dirname "$0")/no-auth" ]] || { echo "!! gh is not logged in" >&2; exit 1; }\n' \
    > "$eco/scripts/host.sh"
  chmod +x "$eco/scripts/host.sh"
  echo "$eco"
}

eco="$(setup_filled doctor-ok)"
check "doctor: exits 0 on a filled-in ecosystem repo" 0 \
  bash -c "cd '$eco' && ./bootstrap.sh doctor"

eco="$(setup_filled doctor-placeholder)"
printf '# <Company> ecosystem\n<!-- <ignored in comments> -->\n' > "$eco/AGENTS.md"
check_output "doctor: exits 1 and names the file when a placeholder is left" 1 "AGENTS.md.*<Company>" \
  bash -c "cd '$eco' && ./bootstrap.sh doctor"
check_absent "doctor: ignores placeholders inside HTML comments" "ignored in comments" \
  bash -c "cd '$eco' && ./bootstrap.sh doctor"

eco="$(setup_filled doctor-notation)"
printf '# Acme ecosystem\n\nWork in <repo>/.worktrees/<branch>, prompts/<step>.md, REASON="<reason>", #<n>.\n' > "$eco/AGENTS.md"
check "doctor: <branch>, <step>, <reason> and <n> are notation used by the rules, not placeholders" 0 \
  bash -c "cd '$eco' && ./bootstrap.sh doctor"

eco="$(setup_filled doctor-no-openspec)"
rm -rf "$eco/openspec"
check "doctor: OpenSpec is optional" 0 \
  bash -c "cd '$eco' && ./bootstrap.sh doctor"

eco="$(setup_filled doctor-no-auth)"
touch "$eco/scripts/no-auth"
check_output "doctor: warns when the git host CLI is not logged in" 0 "gh is not logged in" \
  bash -c "cd '$eco' && ./bootstrap.sh doctor"

eco="$(setup_filled doctor-temporary)"
mkdir -p "$eco/.work/42" "$eco/docs/superpowers" "$eco/openspec/changes/42" "$eco/.worktrees/docs"
touch "$eco/.work/42/spec.md" "$eco/local.mk" "$eco/docs/superpowers/plan.md" "$eco/openspec/changes/42/proposal.md" \
  "$eco/.worktrees/docs/x"
check_absent "doctor: does not warn about temporary files ignored on purpose" "\.work|local\.mk|superpowers|openspec/changes|\.worktrees" \
  bash -c "cd '$eco' && ./bootstrap.sh doctor"

eco="$(setup_filled doctor-todo)"
echo "- TODO: who owns the worker?" >> "$eco/docs/product/sensitive-areas.md"
check_output "doctor: warns about TODOs without failing" 0 "sensitive-areas.md.*TODO" \
  bash -c "cd '$eco' && ./bootstrap.sh doctor"

eco="$(setup_filled doctor-template-comment)"
printf '<!--\n  TEMPLATE: replace the example rows.\n-->\n' >> "$eco/docs/system-map.md"
check_output "doctor: warns about template comments left in place" 0 "system-map.md.*TEMPLATE" \
  bash -c "cd '$eco' && ./bootstrap.sh doctor"

eco="$(setup_filled doctor-stale-map)"
sed -i.bak 's/^Last reviewed: .*/Last reviewed: 2020-01-01/' "$eco/docs/system-map.md" && rm "$eco/docs/system-map.md.bak"
check_output "doctor: warns when the system map has not been reviewed for a long time" 0 "system-map.md.*2020-01-01" \
  bash -c "cd '$eco' && ./bootstrap.sh doctor"

eco="$(setup_filled doctor-ignored)"
mkdir -p "$eco/.cursor/commands" && echo x > "$eco/.cursor/commands/opsx-propose.md"
check_output "doctor: warns about ignored folders that are not service repos" 0 "\.cursor" \
  bash -c "cd '$eco' && ./bootstrap.sh doctor"
check_absent "doctor: does not warn about service repos" "api/" \
  bash -c "cd '$eco' && ./bootstrap.sh doctor"

# A filled-in ecosystem repo with a remote, on main and up to date. Prints its folder.
setup_filled_remote() {
  local eco
  eco="$(setup_filled "$1")"
  git -C "$eco" add -A && git -C "$eco" commit -q -m init
  git clone -q --bare "$eco" "$TMP/$1/remote-eco.git"
  git -C "$eco" remote add origin "$TMP/$1/remote-eco.git"
  git -C "$eco" fetch -q origin && git -C "$eco" branch -q -u origin/main
  echo "$eco"
}

eco="$(setup_filled_remote doctor-eco-main)"
check_absent "doctor: no warning when the ecosystem repo is on its main branch, up to date" "ecosystem repo is" \
  bash -c "cd '$eco' && ./bootstrap.sh doctor"

eco="$(setup_filled_remote doctor-eco-branch)"
git -C "$eco" switch -q -c feature/docs
check_output "doctor: warns when the ecosystem repo is not on its main branch" 0 "ecosystem repo is on feature/docs" \
  bash -c "cd '$eco' && ./bootstrap.sh doctor"
check_output "branch: warns when the ecosystem repo is not on its main branch" 0 "ecosystem repo is on feature/docs" \
  bash -c "cd '$eco' && ./bootstrap.sh branch feature/x api 2>&1 | head -n 1; true"

eco="$(setup_filled_remote doctor-eco-behind)"
git clone -q "$eco/../remote-eco.git" "$eco/../other"
git -C "$eco/../other" commit -q --allow-empty -m "merged later" && git -C "$eco/../other" push -q origin main
check_output "doctor: warns when the ecosystem repo is behind its remote main branch" 0 "ecosystem repo is 1 commit\(s\) behind origin/main" \
  bash -c "cd '$eco' && ./bootstrap.sh doctor"

echo
echo "Passed: $passed · Failed: $failed"
[[ $failed -eq 0 ]]
