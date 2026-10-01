#!/usr/bin/env bash
# Sets up the ecosystem repo: clones missing repos and keeps every repo's main branch up to date.
#
# Usage:
#   ./bootstrap.sh            clone/update the "core" repos
#   ./bootstrap.sh --all      also include the "optional" repos
#   ./bootstrap.sh status     show the branch and state of each repo
#   ./bootstrap.sh branch X   create (from the main branch) or switch to branch X in the given repos:
#                             ./bootstrap.sh branch feature/add-dark-mode api web
#   ./bootstrap.sh check-approved ID
#                             exit 0 only if the proposal ID is merged into the ecosystem main branch
#   ./bootstrap.sh doctor     check the ecosystem repo is filled in and set up (placeholders, TODOs,
#                             OpenSpec, system map age, files left out by .gitignore)
#   ./bootstrap.sh tests      run the tests of this script (and shellcheck, if installed)
#
# Safe to run as often as you like: it never deletes anything, never switches your
# branch and never touches your files. If a repo is on another branch, its main
# branch is updated in the background without moving you off your branch.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIST="$ROOT/repos.txt"

# Main branch used when repos.txt does not set one for a repo.
# Override for a single run with: DEFAULT_BRANCH=master ./bootstrap.sh
DEFAULT_BRANCH="${DEFAULT_BRANCH:-main}"

cd "$ROOT"

# Reads repos.txt and prints "folder url group branch" per line, skipping comments and blanks.
read_repos() {
  grep -vE '^\s*(#|$)' "$LIST" | awk -v def="$DEFAULT_BRANCH" '{print $1, $2, $3, ($4 == "" ? def : $4)}'
}

want_group() {
  local group="$1" include_optional="$2"
  [[ "$group" == "core" || "$include_optional" == "yes" ]]
}

# Main branch of a repo already in the ecosystem repo, as configured in repos.txt.
main_branch_of() {
  local target="$1" dir _url _group branch
  while read -r dir _url _group branch; do
    [[ "$dir" == "$target" ]] && { echo "$branch"; return; }
  done < <(read_repos)
  echo "$DEFAULT_BRANCH"
}

cmd_sync() {
  local include_optional="no"
  [[ "${1:-}" == "--all" ]] && include_optional="yes"

  local cloned=0 updated=0 background=0 skipped=0 failed=0
  while read -r dir url group main; do
    want_group "$group" "$include_optional" || continue

    if [[ ! -d "$dir/.git" ]]; then
      if [[ -e "$dir" ]]; then
        echo "!! $dir exists but is not a git repo. Check it manually."
        failed=$((failed + 1)); continue
      fi
      echo "-> cloning $dir (large repos can take a few minutes)"
      if git clone --progress --branch "$main" "$url" "$dir"; then
        cloned=$((cloned + 1))
      else
        echo "!! could not clone $dir ($url, branch $main)"; failed=$((failed + 1))
      fi
      continue
    fi

    local branch dirty=""
    branch="$(git -C "$dir" rev-parse --abbrev-ref HEAD)"
    [[ -n "$(git -C "$dir" status --porcelain)" ]] && dirty="yes"

    # On the main branch, clean: regular pull.
    if [[ "$branch" == "$main" && -z "$dirty" ]]; then
      if git -C "$dir" pull --quiet --ff-only origin "$main"; then
        updated=$((updated + 1))
      else
        echo "!! $dir: could not fast-forward $main (local commits on $main?)"
        failed=$((failed + 1))
      fi
      continue
    fi

    # On the main branch with uncommitted changes: git cannot move the checked-out
    # branch without touching your files, so only fetch. Your changes are left alone.
    if [[ "$branch" == "$main" ]]; then
      if git -C "$dir" fetch --quiet origin "$main"; then
        echo "   $dir: uncommitted changes on $main; fetched, pull once you commit them"
        skipped=$((skipped + 1))
      else
        echo "!! $dir: could not fetch from the remote"; failed=$((failed + 1))
      fi
      continue
    fi

    # On another branch (clean or not): update the main branch in the background, without
    # switching branches or touching files. Only fast-forwards; otherwise git refuses.
    local before after
    before="$(git -C "$dir" rev-parse --quiet --verify "refs/heads/$main" || true)"
    if git -C "$dir" fetch --quiet origin "$main:$main"; then
      after="$(git -C "$dir" rev-parse "refs/heads/$main")"
      if [[ "$before" != "$after" ]]; then
        echo "   $dir: on '$branch'; $main updated in the background"
        background=$((background + 1))
      else
        echo "   $dir: on '$branch'; $main already up to date"
        skipped=$((skipped + 1))
      fi
    else
      echo "!! $dir: on '$branch'; could not update $main (local commits not on the remote?)"
      failed=$((failed + 1))
    fi
  done < <(read_repos)

  echo
  echo "Cloned: $cloned · Updated: $updated · Main updated in background: $background · Unchanged: $skipped · Errors: $failed"
  [[ $failed -eq 0 ]]
}

cmd_status() {
  printf '%-20s %-34s %s\n' "REPO" "BRANCH" "STATE"
  while read -r dir _url _group _main; do
    if [[ ! -d "$dir/.git" ]]; then
      printf '%-20s %-34s %s\n' "$dir" "-" "not cloned"; continue
    fi
    local branch state
    branch="$(git -C "$dir" rev-parse --abbrev-ref HEAD)"
    if [[ -n "$(git -C "$dir" status --porcelain)" ]]; then state="uncommitted changes"; else state="clean"; fi
    printf '%-20s %-34s %s\n' "$dir" "$branch" "$state"
  done < <(read_repos)
}

cmd_branch() {
  local name="${1:?Give the branch name}"; shift
  [[ $# -gt 0 ]] || { echo "Give the affected repos, e.g.: branch $name api web"; exit 1; }

  # Keeps going after a failure so the other repos still get the branch, but exits
  # non-zero if any repo failed: callers (people or agents) must not miss it.
  local failed=0
  for dir in "$@"; do
    [[ -d "$dir/.git" ]] || { echo "!! $dir is not cloned"; failed=$((failed + 1)); continue; }
    if git -C "$dir" show-ref --verify --quiet "refs/heads/$name"; then
      if git -C "$dir" switch --quiet "$name"; then
        echo "   $dir: switched to $name"
      else
        echo "!! $dir: could not switch to $name"; failed=$((failed + 1))
      fi
    else
      # New branches always start from the latest main branch on the remote,
      # even if the repo is on another branch or its local main branch is behind.
      local main
      main="$(main_branch_of "$dir")"
      if git -C "$dir" fetch --quiet origin "$main" \
        && git -C "$dir" switch --quiet --no-track -c "$name" "origin/$main"; then
        echo "-> $dir: created $name from $main"
      else
        echo "!! $dir: could not create $name from $main"; failed=$((failed + 1))
      fi
    fi
  done

  [[ $failed -eq 0 ]] || { echo; echo "Errors: $failed"; return 1; }
}

# Main branch of the ecosystem repo itself: the remote's default branch if git knows it,
# otherwise DEFAULT_BRANCH.
ecosystem_branch() {
  local head
  head="$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null || true)"
  if [[ -n "$head" ]]; then echo "${head#origin/}"; else echo "$DEFAULT_BRANCH"; fi
}

# A proposal is approved when its PR is merged: its proposal.md is on the remote main
# branch, either still in openspec/changes/ or already archived.
cmd_check_approved() {
  local id="${1:-}"
  [[ "$id" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]] \
    || { echo "Give the change id in kebab-case, e.g.: check-approved add-dark-mode"; return 1; }

  local main archived
  main="$(ecosystem_branch)"
  git fetch --quiet origin "$main" || { echo "!! could not fetch $main from the remote"; return 1; }

  if git cat-file -e "origin/$main:openspec/changes/$id/proposal.md" 2>/dev/null; then
    echo "$id: approved (proposal merged into $main)"; return 0
  fi
  archived="$(git ls-tree -r --name-only "origin/$main" -- openspec/changes/archive/)"
  if grep -qE "^openspec/changes/archive/[0-9]{4}-[0-9]{2}-[0-9]{2}-$id/proposal\.md$" <<< "$archived"; then
    echo "$id: approved (proposal merged into $main and already archived)"; return 0
  fi
  echo "!! $id: not approved. openspec/changes/$id/proposal.md is not on $main yet: its PR must be merged first."
  return 1
}

# Files a team fills in when adopting the template.
context_files() {
  local f
  for f in AGENTS.md openspec/config.yaml docs/system-map.md docs/product/*.md docs/product/decisions/[0-9]*.md; do
    [[ -f "$f" && "$f" != */README.md ]] && echo "$f"
  done
}

# Prints "P file:line: <token>" for each unfilled placeholder and "T file:line: text" for
# each TODO, ignoring HTML comments. <id>, <change-id>, <repo> and <short-description>
# are notation used by the rules themselves, not placeholders.
scan_context() {
  awk '
    FNR == 1 { in_comment = 0 }
    {
      line = $0; text = ""
      while (line != "") {
        if (in_comment) {
          i = index(line, "-->"); if (!i) break
          line = substr(line, i + 3); in_comment = 0
        } else {
          i = index(line, "<!--"); if (!i) { text = text line; break }
          text = text substr(line, 1, i - 1); line = substr(line, i + 4); in_comment = 1
        }
      }
      if (text ~ /TODO:/) print "T " FILENAME ":" FNR ": " text
      while (match(text, /<[^<>]+>/)) {
        token = substr(text, RSTART, RLENGTH)
        if (token !~ /^<(id|change-id|repo|short-description)>$/) print "P " FILENAME ":" FNR ": " token
        text = substr(text, RSTART + RLENGTH)
      }
    }' "$@"
}

# Seconds since the epoch for a YYYY-MM-DD date, with GNU date or BSD/macOS date.
to_epoch() {
  date -d "$1" +%s 2>/dev/null || date -j -f %Y-%m-%d "$1" +%s 2>/dev/null
}

cmd_doctor() {
  local errors=0 warnings=0 kind rest f
  local files=()
  while read -r f; do files+=("$f"); done < <(context_files)

  # Placeholders are errors: the agent would read them as real values. TODOs are warnings.
  if [[ ${#files[@]} -gt 0 ]]; then
    while read -r kind rest; do
      if [[ "$kind" == P ]]; then
        echo "!! $rest  (placeholder not filled in)"; errors=$((errors + 1))
      else
        echo "   $rest"; warnings=$((warnings + 1))
      fi
    done < <(scan_context "${files[@]}")

    for f in "${files[@]}"; do
      if grep -q 'TEMPLATE:' "$f"; then
        echo "   $f: TEMPLATE comment still in place; delete it once the file is filled in"
        warnings=$((warnings + 1))
      fi
    done
  fi

  # OpenSpec must be initialised: its folders exist and it generated commands or skills
  # for at least one agent (.claude/, .cursor/, .agents/, .github/...).
  local generated=""
  for f in .[!.]*/; do
    [[ -d "$f" && "$f" != .git/ ]] || continue
    generated="$(find "$f" -maxdepth 3 \( -name '*opsx*' -o -name 'openspec-*' \) -print 2>/dev/null | head -n 1)"
    [[ -n "$generated" ]] && break
  done
  if [[ ! -d openspec/specs || ! -d openspec/changes || -z "$generated" ]]; then
    echo "!! OpenSpec is not set up for any agent: run openspec init (SETUP.md, step 3)"
    errors=$((errors + 1))
  fi

  # The system map must be reviewed regularly: an outdated map misleads the agent.
  local max_age="${MAP_MAX_AGE_DAYS:-90}" reviewed epoch age
  if [[ -f docs/system-map.md ]]; then
    reviewed="$(sed -n 's/^Last reviewed: *\([0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}\).*/\1/p' docs/system-map.md | head -n 1)"
    if [[ -n "$reviewed" ]] && epoch="$(to_epoch "$reviewed")"; then
      age=$(( ($(date +%s) - epoch) / 86400 ))
      if [[ $age -gt $max_age ]]; then
        echo "   docs/system-map.md: last reviewed $reviewed, $age days ago (limit: $max_age)"
        warnings=$((warnings + 1))
      fi
    elif ! grep -q '^Last reviewed: *<' docs/system-map.md; then
      echo "   docs/system-map.md: no 'Last reviewed: YYYY-MM-DD' line"
      warnings=$((warnings + 1))
    fi
  fi

  # Anything ignored that is not a service repo never reaches the rest of the team.
  if git rev-parse --git-dir > /dev/null 2>&1; then
    local services path top
    services=" $(read_repos | awk '{printf "%s ", $1}')"
    while read -r path; do
      top="${path%%/*}"
      [[ "$services" == *" $top "* || "$path" == .claude/settings.local.json ]] && continue
      echo "   $path: ignored by .gitignore; if the team needs it, add it with '!' (see .gitignore)"
      warnings=$((warnings + 1))
    done < <(git status --ignored --porcelain | sed -n 's/^!! //p')
  fi

  echo
  echo "Errors: $errors · Warnings: $warnings"
  [[ $errors -eq 0 ]]
}

# Runs the tests of this script, then shellcheck if it is installed.
cmd_tests() {
  local code=0
  "$ROOT/tests/bootstrap.test.sh" || code=$?
  if command -v shellcheck > /dev/null; then
    shellcheck "$ROOT/bootstrap.sh" "$ROOT/tests/bootstrap.test.sh" || { [[ $code -ne 0 ]] || code=1; }
  else
    echo "   shellcheck is not installed: lint skipped"
  fi
  return "$code"
}

case "${1:-}" in
  status) cmd_status ;;
  branch) shift; cmd_branch "$@" ;;
  check-approved) shift; cmd_check_approved "$@" ;;
  doctor) cmd_doctor ;;
  tests) cmd_tests ;;
  ""|--all) cmd_sync "${1:-}" ;;
  *) awk 'NR > 1 && /^#/ { sub(/^# ?/, ""); print; next } NR > 1 { exit }' "$0"; exit 1 ;;
esac
