#!/usr/bin/env bash
# Tests for scripts/host.sh. gh and glab are fakes on the PATH: they log the arguments they
# get and answer with canned JSON, so nothing touches the network or a real git host.
#
# Usage: tests/host.test.sh

set -uo pipefail

SOURCE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/scripts/host.sh"
TMP="$(mktemp -d)"
# host.sh runs issue commands from the ecosystem root, the folder above its own.
HOST="$TMP/eco/scripts/host.sh"
trap 'rm -rf "$TMP"' EXIT

passed=0 failed=0

pass() { passed=$((passed + 1)); echo "ok   $1"; }
fail() {
  failed=$((failed + 1)); echo "FAIL $1 ($2)"
  printf '     | %s\n' "${3//$'\n'/$'\n     | '}"
}

# expect <description> <expected output> <command...>
expect() {
  local desc="$1" want="$2" got; shift 2
  got="$("$@" 2>&1)"
  if [[ "$got" == "$want" ]]; then pass "$desc"; else fail "$desc" "expected: $want" "$got"; fi
}

# called <description> <regex a logged call must match>: the fake CLI got those arguments.
called() {
  if grep -qE -- "$2" "$FAKE_LOG"; then pass "$1"; else fail "$1" "no call matches /$2/" "$(cat "$FAKE_LOG")"; fi
}

# A fake CLI: logs "<name> <cwd folder> <args>" and prints $FAKE_DIR/<first two args>.out if
# it exists (e.g. issue-view.out for "gh issue view").
make_fake() {
  cat > "$TMP/bin/$1" <<'EOF'
#!/usr/bin/env bash
echo "$(basename "$0") $(basename "$PWD") $*" >> "$FAKE_LOG"
out="$FAKE_DIR/$1-$2.out"
[[ -f "$out" ]] && cat "$out"
exit "${FAKE_EXIT:-0}"
EOF
  chmod +x "$TMP/bin/$1"
}

mkdir -p "$TMP/bin" "$TMP/eco/api" "$TMP/eco/scripts"
cp "$SOURCE" "$HOST"
make_fake gh; make_fake glab
export PATH="$TMP/bin:$PATH" FAKE_DIR="$TMP/fake" FAKE_LOG="$TMP/calls"
mkdir -p "$FAKE_DIR"
echo "Body of the spec" > "$TMP/body.md"
cd "$TMP/eco" || exit 1

# reset: empties the log and the canned answers.
reset() { rm -f "$FAKE_LOG" "$FAKE_DIR"/*; touch "$FAKE_LOG"; }

# --- GitHub (gh) ------------------------------------------------------------

export GIT_HOST=gh

reset
echo "https://github.com/acme/eco/issues/42" > "$FAKE_DIR/issue-create.out"
expect "gh: issue-create prints the number of the new issue" "42" \
  "$HOST" issue-create feature "Export orders" "$TMP/body.md"
called "gh: issue-create passes the title and the body file" "^gh eco issue create --title Export orders --body-file $TMP/body.md$"

reset
echo "https://github.com/acme/eco/issues/43" > "$FAKE_DIR/issue-create.out"
"$HOST" issue-create bug "Login loop" "$TMP/body.md" > /dev/null
called "gh: issue-create of a bug makes sure the bug label exists" "^gh eco label create bug --force"
called "gh: issue-create of a bug adds the bug label" "issue create .* --label bug$"

reset
printf '%s' '{"title":"Export orders","body":"## Affected repos\n- api","labels":[{"name":"bug"},{"name":"ui"}],"url":"https://github.com/acme/eco/issues/42","state":"OPEN"}' \
  > "$FAKE_DIR/issue-view.out"
expect "gh: issue-get title" "Export orders" "$HOST" issue-get 42 title
expect "gh: issue-get body" $'## Affected repos\n- api' "$HOST" issue-get 42 body
expect "gh: issue-get labels, one per line" $'bug\nui' "$HOST" issue-get 42 labels
expect "gh: issue-get url" "https://github.com/acme/eco/issues/42" "$HOST" issue-get 42 url
expect "gh: issue-get state in lower case" "open" "$HOST" issue-get 42 state
expect "gh: issue-get with an unknown field fails" "!! Unknown field: owner (title, body, labels, url, state)" \
  "$HOST" issue-get 42 owner

reset
"$HOST" issue-set-body 42 "$TMP/body.md"
called "gh: issue-set-body edits the body from the file" "^gh eco issue edit 42 --body-file $TMP/body.md$"
"$HOST" issue-comment 42 "$TMP/body.md"
called "gh: issue-comment comments from the file" "^gh eco issue comment 42 --body-file $TMP/body.md$"
"$HOST" issue-close 42 completed
called "gh: issue-close completed" "^gh eco issue close 42 --reason completed$"
"$HOST" issue-close 42 not-planned
called "gh: issue-close not-planned" "^gh eco issue close 42 --reason not planned$"

reset
printf '%s' '[{"number":7,"state":"MERGED","url":"https://github.com/acme/api/pull/7"},{"number":9,"state":"OPEN","url":"https://github.com/acme/api/pull/9"}]' \
  > "$FAKE_DIR/pr-list.out"
expect "gh: pr-list prints state, number and url of every PR of the branch" \
  $'merged 7 https://github.com/acme/api/pull/7\nopen 9 https://github.com/acme/api/pull/9' \
  "$HOST" pr-list api feature/42-export
called "gh: pr-list runs in the repo folder, with every state" "^gh api pr list --head feature/42-export --state all --json number,state,url$"

reset
"$HOST" pr-close api 9 "$TMP/body.md"
called "gh: pr-close closes the PR in the repo folder with the comment" "^gh api pr close 9 --comment Body of the spec$"

reset
FAKE_EXIT=1 expect "gh: a failing command makes host.sh fail" "1" \
  bash -c "'$HOST' issue-comment 42 '$TMP/body.md' > /dev/null 2>&1; echo \$?"

# --- GitLab (glab) ----------------------------------------------------------

export GIT_HOST=glab

reset
printf 'Creating issue in acme/eco\nhttps://gitlab.com/acme/eco/-/issues/12\n' > "$FAKE_DIR/issue-create.out"
expect "glab: issue-create prints the number of the new issue" "12" \
  "$HOST" issue-create bug "Login loop" "$TMP/body.md"
called "glab: issue-create of a bug makes sure the bug label exists" "^glab eco label create --name bug$"
called "glab: issue-create passes title, body file and label, without prompting" \
  "^glab eco issue create --title Login loop --description-file $TMP/body.md --yes --label bug$"

reset
printf '%s' '{"title":"Login loop","description":"Spec","labels":["bug"],"web_url":"https://gitlab.com/acme/eco/-/issues/12","state":"opened"}' \
  > "$FAKE_DIR/issue-view.out"
expect "glab: issue-get body is the description" "Spec" "$HOST" issue-get 12 body
expect "glab: issue-get labels" "bug" "$HOST" issue-get 12 labels
expect "glab: issue-get url" "https://gitlab.com/acme/eco/-/issues/12" "$HOST" issue-get 12 url
expect "glab: issue-get state opened is open" "open" "$HOST" issue-get 12 state
called "glab: issue-get reads the issue as JSON" "^glab eco issue view 12 -F json$"

reset
"$HOST" issue-set-body 12 "$TMP/body.md"
called "glab: issue-set-body updates the description from the file" "^glab eco issue update 12 --description-file $TMP/body.md$"
"$HOST" issue-comment 12 "$TMP/body.md"
called "glab: issue-comment adds a note" "^glab eco issue note 12 -m Body of the spec$"
"$HOST" issue-close 12 not-planned
called "glab: issue-close closes the issue" "^glab eco issue close 12$"

reset
printf '%s' '[{"iid":3,"state":"opened","web_url":"https://gitlab.com/acme/api/-/merge_requests/3"},{"iid":2,"state":"closed","web_url":"https://gitlab.com/acme/api/-/merge_requests/2"}]' \
  > "$FAKE_DIR/mr-list.out"
expect "glab: pr-list prints state (opened is open), number and url" \
  $'open 3 https://gitlab.com/acme/api/-/merge_requests/3\nclosed 2 https://gitlab.com/acme/api/-/merge_requests/2' \
  "$HOST" pr-list api fix/12-login-loop
called "glab: pr-list runs in the repo folder, with every state" "^glab api mr list -A --source-branch fix/12-login-loop -F json$"

reset
"$HOST" pr-close api 3 "$TMP/body.md"
called "glab: pr-close comments on the MR" "^glab api api --method POST projects/:id/merge_requests/3/notes -f body=Body of the spec$"
called "glab: pr-close closes the MR" "^glab api mr close 3$"

# --- Host detection -----------------------------------------------------------

unset GIT_HOST
git -C "$TMP/eco" init -q
git -C "$TMP/eco" remote add origin git@gitlab.example.com:acme/eco.git
reset
printf 'https://gitlab.example.com/acme/eco/-/issues/5\n' > "$FAKE_DIR/issue-create.out"
expect "detection: an origin URL with gitlab uses glab" "5" "$HOST" issue-create feature "X" "$TMP/body.md"
git -C "$TMP/eco" remote set-url origin git@github.com:acme/eco.git
reset
echo "https://github.com/acme/eco/issues/6" > "$FAKE_DIR/issue-create.out"
expect "detection: any other origin URL uses gh" "6" "$HOST" issue-create feature "X" "$TMP/body.md"

expect "an unknown command prints the usage and fails" "1" \
  bash -c "'$HOST' frobnicate > /dev/null 2>&1; echo \$?"

echo
echo "Passed: $passed · Failed: $failed"
[[ $failed -eq 0 ]]
