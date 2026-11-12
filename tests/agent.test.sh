#!/usr/bin/env bash
# Tests for scripts/agent.sh. The agent is a fake that saves the first message it gets, and
# scripts/host.sh is a fake that answers from files, so nothing starts a real agent or calls
# a git host.
#
# Usage: tests/agent.test.sh

set -uo pipefail

SOURCE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/scripts/agent.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

passed=0 failed=0

pass() { passed=$((passed + 1)); echo "ok   $1"; }
fail() {
  failed=$((failed + 1)); echo "FAIL $1 ($2)"
  printf '     | %s\n' "${3//$'\n'/$'\n     | '}"
}

# check_output <description> <expected exit code> <regex the output must match> <command...>
check_output() {
  local desc="$1" expected="$2" pattern="$3" out code; shift 3
  out="$("$@" 2>&1)"; code=$?
  if [[ "$code" == "$expected" ]] && grep -qE -- "$pattern" <<< "$out"; then
    pass "$desc"
  else
    fail "$desc" "exit $code, expected $expected; output must match /$pattern/" "$out"
  fi
}

# prompt_has <description> <regex>: the first message the agent got matches the regex.
prompt_has() {
  if grep -qE -- "$2" "$TMP/prompt" 2> /dev/null; then pass "$1"; else fail "$1" "prompt must match /$2/" "$(cat "$TMP/prompt" 2> /dev/null)"; fi
}

# prompt_lacks <description> <regex>
prompt_lacks() {
  if grep -qE -- "$2" "$TMP/prompt" 2> /dev/null; then fail "$1" "prompt must not match /$2/" "$(cat "$TMP/prompt")"; else pass "$1"; fi
}

eco="$TMP/eco"
mkdir -p "$eco/scripts" "$eco/prompts/method/superpowers" "$eco/prompts/method/default" "$TMP/bin"
cp "$SOURCE" "$eco/scripts/agent.sh"
echo "WHAT TO DO IN APPLY" > "$eco/prompts/apply.md"
echo "WHAT TO DO IN EXPLORE" > "$eco/prompts/explore.md"
echo "HOW WITH SUPERPOWERS IN APPLY" > "$eco/prompts/method/superpowers/apply.md"
echo "HOW WITH DEFAULT" > "$eco/prompts/method/default/default.md"

# The fake host: issue 42 exists; any other number fails, like a missing issue.
cat > "$eco/scripts/host.sh" <<'EOF'
#!/usr/bin/env bash
[[ "$2" == 42 ]] || { echo "!! no issue $2" >&2; exit 1; }
case "$3" in
  title) echo "Export orders" ;;
  url) echo "https://github.com/acme/eco/issues/42" ;;
  body) printf '## Affected repos\n- api\n' ;;
esac
EOF
# The fake agent: saves its first message and the folder it was started in.
cat > "$TMP/bin/fake-agent" <<EOF
#!/usr/bin/env bash
printf '%s' "\$1" > "$TMP/prompt"
pwd > "$TMP/cwd"
EOF
chmod +x "$eco/scripts/host.sh" "$TMP/bin/fake-agent"
export PATH="$TMP/bin:$PATH"

run() { rm -f "$TMP/prompt"; (cd /tmp && AGENT=fake-agent "$eco/scripts/agent.sh" "$@"); }

run apply 42 "Branch: feature/42-export-orders" > /dev/null
prompt_has "the prompt starts with prompts/<step>.md" "^WHAT TO DO IN APPLY"
prompt_has "with METHOD unset, the default method instructions follow" "HOW WITH DEFAULT"
prompt_has "the issue number, title and url are added" "Issue #42: Export orders .*issues/42"
prompt_has "the issue body (the spec) is added" "^- api$"
prompt_has "context lines go at the end" "Branch: feature/42-export-orders$"
check_output "the agent starts at the ecosystem root" 0 "^$eco$" cat "$TMP/cwd"

METHOD=superpowers run apply 42 > /dev/null
prompt_has "the method's file for the step is used" "HOW WITH SUPERPOWERS IN APPLY"
prompt_lacks "only one method file is used" "HOW WITH DEFAULT"

METHOD=superpowers run explore "Idea: CSV export" > /dev/null
prompt_has "without a file for the step, the method's default.md is not required" "^WHAT TO DO IN EXPLORE"
prompt_has "a first argument that is not a number is context" "Idea: CSV export"
prompt_lacks "without an issue number, no issue is added" "Issue #"

check_output "an unknown method fails and lists the valid ones" 1 "openspec, superpowers or default" \
  bash -c "METHOD=magic AGENT=fake-agent '$eco/scripts/agent.sh' apply 42"
check_output "without AGENT it fails and says how to set it in local.mk" 1 "local.mk" \
  bash -c "unset AGENT; '$eco/scripts/agent.sh' apply 42"
check_output "an AGENT that is not installed fails" 1 "not installed" \
  bash -c "AGENT=no-such-agent '$eco/scripts/agent.sh' apply 42"
check_output "a step without prompts/<step>.md fails" 1 "prompts/deploy.md" \
  bash -c "AGENT=fake-agent '$eco/scripts/agent.sh' deploy"
rm -f "$TMP/prompt"
check_output "a missing issue fails before starting the agent" 1 "no issue 7" \
  bash -c "AGENT=fake-agent '$eco/scripts/agent.sh' apply 7"
if [[ -f "$TMP/prompt" ]]; then fail "the agent is not started for a missing issue" "it was" ""; else pass "the agent is not started for a missing issue"; fi

echo
echo "Passed: $passed · Failed: $failed"
[[ $failed -eq 0 ]]
