# shellcheck shell=bash
# Loads the personal settings of local.mk, the same file the Makefile includes, for the scripts
# that run without make (e.g. from the agent skills). What is already in the environment wins.
# LOCAL_MK points to another file: the tests use it.
load_local_mk() {
  local file="${LOCAL_MK:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/local.mk}" line name value
  [[ -f "$file" ]] || return 0
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" =~ ^[[:space:]]*(AGENT|AGENT_REVIEWER|METHOD|GIT_HOST)[[:space:]]*[:?]?=(.*)$ ]] || continue
    name="${BASH_REMATCH[1]}"
    read -r value <<< "${BASH_REMATCH[2]%%#*}"   # without the comment or the spaces around it
    [[ -n "${!name:-}" ]] || export "$name=$value"
  done < "$file"
}
