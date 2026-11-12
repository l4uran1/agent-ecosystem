#!/usr/bin/env bash
# Sets up the ecosystem repo: clones missing repos and keeps every repo's main branch up to date.
#
# Usage:
#   ./bootstrap.sh            clone/update the "core" repos
#   ./bootstrap.sh --all      also include the "optional" repos
#   ./bootstrap.sh status     show the branch and state of each repo and of its worktrees
#   ./bootstrap.sh branch X   create branch X (the local one, the remote one someone else pushed,
#                             or a new one from the main branch) in a worktree
#                             <repo>/.worktrees/X of each given repo, without touching its main
#                             checkout. If <repo> is a symbolic link, it is replaced by the
#                             worktree at that same path:
#                             ./bootstrap.sh branch fix/login-loop api web
#   ./bootstrap.sh branch ID  with the id of a published OpenSpec change and no repos: create
#                             feature/ID (fix/<rest> for a fix-<rest> id) in the repos tagged
#                             in its published tasks.md, only if its PR (spec/ID) is open
#   ./bootstrap.sh check-spec ID
#                             say whether the proposal ID is published, merged or archived; exit 1
#                             if it is not on the ecosystem remote
#   ./bootstrap.sh doctor     check the ecosystem repo is filled in and set up (placeholders, TODOs,
#                             OpenSpec, system map age, files left out by .gitignore, and that the
#                             ecosystem repo is on its main branch, up to date)
#   ./bootstrap.sh tests      run every suite in tests/ (and shellcheck, if installed)
#
# Safe to run as often as you like: it never deletes anything, never switches your
# branch and never touches your files (branch only replaces repo symbolic links). If a
# repo is on another branch, its main branch is updated in the background without moving
# you off your branch.

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

    if [[ ! -e "$dir/.git" ]]; then
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

    # On another branch, with the main branch checked out in another worktree (e.g. the clone
    # a repo link pointed to): git cannot move it from here, so pull it there if it is clean.
    local other
    other="$(worktree_of "$dir" "$main")"
    if [[ -n "$other" ]]; then
      if [[ -n "$(git -C "$other" status --porcelain)" ]]; then
        echo "   $dir: on '$branch'; $main is in $other with uncommitted changes, not updated"
        skipped=$((skipped + 1))
      elif git -C "$other" pull --quiet --ff-only origin "$main"; then
        updated=$((updated + 1))
      else
        echo "!! $dir: could not fast-forward $main in $other"; failed=$((failed + 1))
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

# "clean" or "uncommitted changes", for the checkout or worktree <dir>.
work_state() {
  if [[ -n "$(git -C "$1" status --porcelain)" ]]; then echo "uncommitted changes"; else echo "clean"; fi
}

cmd_status() {
  printf '%-20s %-34s %s\n' "REPO" "BRANCH" "STATE"
  while read -r dir _url _group _main; do
    if [[ ! -e "$dir/.git" ]]; then
      printf '%-20s %-34s %s\n' "$dir" "-" "not cloned"; continue
    fi
    printf '%-20s %-34s %s\n' "$dir" "$(git -C "$dir" rev-parse --abbrev-ref HEAD)" "$(work_state "$dir")"
    # Below it, the repo's other worktrees: path relative to the repo when inside it.
    local top path branch
    top="$(git -C "$dir" rev-parse --show-toplevel)"
    while read -r path branch; do
      [[ "$path" == "$top" ]] && continue
      printf '  └ %-32s %-34s %s\n' "${path#"$top"/}" "${branch:-(detached)}" "$(work_state "$path")"
    done < <(git -C "$dir" worktree list --porcelain \
      | awk '/^worktree /{if (p) print p, b; p=substr($0, 10); b=""} /^branch /{b=substr($0, 19)} END{if (p) print p, b}')
  done < <(read_repos)
}

# Path of the worktree of <repo> that has <branch> checked out, or nothing.
worktree_of() {
  git -C "$1" worktree list --porcelain \
    | awk -v b="branch refs/heads/$2" '/^worktree /{p=substr($0, 10)} $0 == b {print p}'
}

# Creates the worktree <path> of <repo> on <branch>: the local one if it exists; otherwise
# the one on the remote (someone else pushed it); otherwise a new one from origin/<main>.
add_worktree() {
  local repo="$1" path="$2" name="$3" main="$4"
  if git -C "$repo" show-ref --verify --quiet "refs/heads/$name"; then
    git -C "$repo" worktree add --quiet "$path" "$name"
  elif git -C "$repo" show-ref --verify --quiet "refs/remotes/origin/$name"; then
    git -C "$repo" worktree add --quiet --track -b "$name" "$path" "origin/$name"
  else
    git -C "$repo" worktree add --quiet --no-track -b "$name" "$path" "origin/$main"
  fi
}

# Worktrees live in <repo>/.worktrees/: the repo ignores them without touching its .gitignore.
ignore_worktrees() {
  local exclude
  exclude="$(git -C "$1" rev-parse --path-format=absolute --git-common-dir)/info/exclude"
  mkdir -p "$(dirname "$exclude")"
  grep -qxF '/.worktrees/' "$exclude" 2>/dev/null || echo '/.worktrees/' >> "$exclude"
}

# The workflow commands are files of the ecosystem repo: on another branch, or with its main
# branch behind, another version of them runs. Prints a one-line warning, or nothing.
ecosystem_warning() {
  local main branch behind
  main="$(ecosystem_branch)"
  branch="$(git -C "$ROOT" branch --show-current 2> /dev/null)" || return 0
  if [[ "$branch" != "$main" ]]; then
    echo "The ecosystem repo is on ${branch:-a detached HEAD}, not on $main: the commands of that branch run"
    return 0
  fi
  git -C "$ROOT" fetch --quiet origin "$main" 2> /dev/null || return 0
  behind="$(git -C "$ROOT" rev-list --count "HEAD..origin/$main" 2> /dev/null)" || return 0
  if [[ "$behind" -gt 0 ]]; then
    echo "The ecosystem repo is $behind commit(s) behind origin/$main: update it with git pull"
  fi
}

# Warns (without stopping) before a workflow command if the ecosystem repo is not on its
# main branch, up to date.
warn_ecosystem() {
  local warning
  warning="$(ecosystem_warning)"
  if [[ -n "$warning" ]]; then echo "!! $warning" >&2; fi
}

cmd_branch() {
  local name="${1:?Give the branch name}"; shift
  warn_ecosystem

  # Without repos, <name> is the id of a published change: its repos come from its tasks.
  if [[ $# -eq 0 ]]; then
    is_change_id "$name" \
      || { echo "Give the affected repos, e.g.: branch $name api web, or the id of a published change"; exit 1; }
    local repos
    repos="$(change_repos "$name")" || exit 1
    # shellcheck disable=SC2086 # repo names have no spaces
    set -- $repos
    if [[ "$name" == fix-* ]]; then name="fix/${name#fix-}"; else name="feature/$name"; fi
    echo "   repos of the change: $*"
  fi

  # Keeps going after a failure so the other repos still get the branch, but exits
  # non-zero if any repo failed: callers (people or agents) must not miss it.
  local failed=0 dir main path link target
  for dir in "$@"; do
    [[ -e "$dir/.git" ]] || { echo "!! $dir is not cloned"; failed=$((failed + 1)); continue; }
    path="$(worktree_of "$dir" "$name")"
    if [[ -n "$path" ]]; then
      echo "   $dir: $name is already in ${path#"$ROOT"/}"; continue
    fi
    # New branches always start from the latest main branch on the remote,
    # even if the repo is on another branch or its local main branch is behind.
    main="$(main_branch_of "$dir")"
    git -C "$dir" fetch --quiet origin "$main" \
      || { echo "!! $dir: could not fetch $main"; failed=$((failed + 1)); continue; }
    # If the branch is already on the remote (someone else pushed it), it starts from there.
    git -C "$dir" fetch --quiet origin "+refs/heads/$name:refs/remotes/origin/$name" 2> /dev/null || true

    # A linked repo is replaced by a worktree at the same path, so nothing is written to
    # the clone the link points to. The link is put back if that fails.
    if [[ -L "$dir" ]]; then
      link="$(readlink "$dir")"; target="$(cd "$dir" && pwd -P)"; path="$dir"
      rm "$dir"
      add_worktree "$target" "$ROOT/$dir" "$name" "$main" || { ln -s "$link" "$dir"; path=""; }
    else
      path="$dir/.worktrees/$name"
      ignore_worktrees "$dir"
      add_worktree "$dir" "$ROOT/$path" "$name" "$main" || path=""
    fi
    if [[ -n "$path" ]]; then
      echo "-> $dir: $name in $path"
    else
      echo "!! $dir: could not create the worktree of $name"; failed=$((failed + 1))
    fi
  done

  [[ $failed -eq 0 ]] || { echo; echo "Errors: $failed"; return 1; }
}

# Main branch of the ecosystem repo itself: the remote's default branch if git knows it,
# otherwise DEFAULT_BRANCH.
ecosystem_branch() {
  local head
  head="$(git -C "$ROOT" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null || true)"
  if [[ -n "$head" ]]; then echo "${head#origin/}"; else echo "$DEFAULT_BRANCH"; fi
}

is_change_id() { [[ "$1" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]; }

# Where the proposal <id> is on the ecosystem remote. Prints one of:
#   "archived"                 the change is finished
#   "merged origin/<main>"     its PR was merged before the change was built
#   "published origin/spec/<id>"  its PR is open: spec/<id> exists on the remote. It is
#                              merged at the end, after the code PRs and with the archive.
# Returns 1 if the proposal is not on the remote, 2 if the remote cannot be fetched.
spec_state() {
  local id="$1" dir="openspec/changes/$1" main branch="spec/$1" archived
  main="$(ecosystem_branch)"
  git fetch --quiet origin "$main" || { echo "!! could not fetch $main from the remote" >&2; return 2; }

  archived="$(git ls-tree -r --name-only "origin/$main" -- openspec/changes/archive/)"
  if grep -qE "^openspec/changes/archive/[0-9]{4}-[0-9]{2}-[0-9]{2}-$id/proposal\.md$" <<< "$archived"; then
    echo "archived"; return 0
  fi
  if git cat-file -e "origin/$main:$dir/proposal.md" 2>/dev/null; then
    echo "merged origin/$main"; return 0
  fi
  # Asks the remote itself: a stale origin/spec/<id> left by an earlier fetch does not count
  # once its PR is closed and the branch deleted.
  if git ls-remote --exit-code origin "refs/heads/$branch" > /dev/null 2>&1 \
    && git fetch --quiet origin "+refs/heads/$branch:refs/remotes/origin/$branch" \
    && git cat-file -e "origin/$branch:$dir/proposal.md" 2>/dev/null; then
    echo "published origin/$branch"; return 0
  fi
  return 1
}

# A change can be implemented as soon as its proposal is published: its PR is open.
cmd_check_spec() {
  local id="${1:-}" state rc=0
  is_change_id "$id" || { echo "Give the change id in kebab-case, e.g.: check-spec add-dark-mode"; return 1; }

  state="$(spec_state "$id")" || rc=$?
  case "$rc:${state%% *}" in
    0:published) echo "$id: published (its PR is open on spec/$id): it can be implemented" ;;
    0:merged)    echo "$id: merged into $(ecosystem_branch) before being built: it can be implemented" ;;
    0:archived)  echo "$id: archived: the change is finished" ;;
    2:*)         return 1 ;;
    *)           echo "!! $id: not published. Push spec/$id with openspec/changes/$id/ and open its PR (spec: $id) before implementing."
                 return 1 ;;
  esac
}

# Prints the repos of the "(repo)" tags in the tasks of a published change, once each.
# Tasks are read from the remote (spec/<id>, or the main branch if the proposal was merged
# there), not the local copy: that is what reviewers see. Fails before anything is created
# if the change is not published, is already archived, has no tags, or names a repo that
# is not in repos.txt.
change_repos() {
  local id="$1" dir="openspec/changes/$1" state rc=0 ref tasks repos known repo unknown=""
  state="$(spec_state "$id")" || rc=$?
  case "$rc" in
    0) ;;
    2) return 1 ;;
    *) cmd_check_spec "$id" >&2; return 1 ;;
  esac
  if [[ "$state" == archived ]]; then
    echo "!! $id is already archived: the change is finished, open a new proposal to change it again" >&2
    return 1
  fi

  ref="${state#* }"
  tasks="$(git show "$ref:$dir/tasks.md" 2>/dev/null)" \
    || { echo "!! $dir/tasks.md is not on $ref" >&2; return 1; }

  repos="$(sed -nE 's/^[[:space:]]*- \[[ xX]\] [0-9.]+ \(([A-Za-z0-9._-]+)\).*/\1/p' <<< "$tasks" | sort -u)"
  [[ -n "$repos" ]] \
    || { echo "!! $dir/tasks.md has no task tagged with its repo, e.g.: - [ ] 1.1 (repo) ..." >&2; return 1; }

  known="$(read_repos | awk '{print $1}')"
  for repo in $repos; do
    grep -qxF "$repo" <<< "$known" || unknown="$unknown $repo"
  done
  [[ -z "$unknown" ]] || { echo "!! $dir/tasks.md names repos that are not in repos.txt:$unknown" >&2; return 1; }

  echo "$repos"
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

  local warning
  warning="$(ecosystem_warning)"
  if [[ -n "$warning" ]]; then echo "   $warning"; warnings=$((warnings + 1)); fi

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

# Runs every suite in tests/, even after a failure, then shellcheck if it is installed.
# Returns the code of the first suite that failed.
cmd_tests() {
  local code=0 suite status
  for suite in "$ROOT"/tests/*.test.sh; do
    status=0; "$suite" || status=$?
    [[ $code -ne 0 ]] || code=$status
  done
  if command -v shellcheck > /dev/null; then
    shellcheck "$ROOT/bootstrap.sh" "$ROOT"/tests/*.test.sh || { [[ $code -ne 0 ]] || code=1; }
  else
    echo "   shellcheck is not installed: lint skipped"
  fi
  return "$code"
}

case "${1:-}" in
  status) cmd_status ;;
  branch) shift; cmd_branch "$@" ;;
  check-spec) shift; cmd_check_spec "$@" ;;
  doctor) cmd_doctor ;;
  tests) cmd_tests ;;
  ""|--all) cmd_sync "${1:-}" ;;
  *) awk 'NR > 1 && /^#/ { sub(/^# ?/, ""); print; next } NR > 1 { exit }' "$0"; exit 1 ;;
esac
