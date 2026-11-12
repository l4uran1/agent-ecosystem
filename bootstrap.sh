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
#   ./bootstrap.sh branch N   with the number of an issue of the ecosystem repo and no repos:
#                             create feature/N-<slug> (fix/N-<slug> if it is labelled bug) in
#                             the repos of the "Affected repos" section of its spec; <slug>
#                             comes from its title
#
# The workflow (README.md). Each step starts your agent (AGENT and METHOD, see
# scripts/agent.sh) with prompts/<step>.md; scripts/host.sh talks to the git host:
#   ./bootstrap.sh explore [idea]
#                             explore an idea, without code or issues
#   ./bootstrap.sh propose <feature|bug> [idea]
#                             write the spec and create its issue
#   ./bootstrap.sh verify N   review the spec of issue N before building it, in a new session
#   ./bootstrap.sh apply N    branch N, then implement it with TDD and open one PR per repo
#   ./bootstrap.sh review N   review the implementation against the spec, in a new session
#                             (creates the worktrees if needed). With AGENT_REVIEWER set to
#                             another agent, that agent reviews first and yours checks its report
#   ./bootstrap.sh archive N  once every PR is merged: your agent writes the final summary and
#                             checks docs/; then the summary is published, the issue closed and
#                             its worktrees, branches and temporary files removed
#   ./bootstrap.sh reject N <reason>
#                             drop issue N: close its open PRs with the reason, publish it on the
#                             issue, close it as not planned and remove worktrees, branches and
#                             temporary files (does nothing if a PR is already merged)
#
#   ./bootstrap.sh doctor     check the ecosystem repo is filled in and set up (placeholders, TODOs,
#                             system map age, files left out by .gitignore, the git host CLI, and
#                             that the ecosystem repo is on its main branch, up to date)
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

  # Without repos, <name> is the number of an issue: the branch and the repos come from it.
  if [[ $# -eq 0 ]]; then
    is_issue "$name" \
      || { echo "Give the affected repos, e.g.: branch $name api web, or the number of an issue"; exit 1; }
    local n="$name" out
    out="$(issue_branch "$n")" || exit 1
    name="${out%%$'\n'*}"
    # shellcheck disable=SC2086 # repo names have no spaces
    set -- ${out#*$'\n'}
    echo "   repos of issue #$n: $*"
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

is_issue() { [[ "$1" =~ ^[0-9]+$ ]]; }

# Branch-friendly form of an issue title: "Export orders to CSV!" -> export-orders-to-csv.
slug() {
  tr '[:upper:]' '[:lower:]' <<< "$1" | sed -E 's/[^a-z0-9]+/-/g; s/^-+//' | cut -c1-40 | sed -E 's/-+$//'
}

# Prints the branch of issue <n> and, on the next lines, the repos of the "Affected repos"
# section of its spec, once each. Fails before anything is created if the issue does not
# exist, its spec lists no repo, or names a repo that is not in repos.txt.
issue_branch() {
  local n="$1" title body labels type repos known repo unknown=""
  title="$(scripts/host.sh issue-get "$n" title)" || return 1
  body="$(scripts/host.sh issue-get "$n" body | tr -d '\r')" || return 1
  labels="$(scripts/host.sh issue-get "$n" labels)" || return 1

  repos="$(awk '
    /^##[[:space:]]+Affected repos/ { on = 1; next }
    /^#/ { on = 0 }
    on && /^[[:space:]]*[-*][[:space:]]+/ { sub(/^[[:space:]]*[-*][[:space:]]+/, ""); gsub(/`/, ""); print $1 }
  ' <<< "$body" | sort -u)"
  [[ -n "$repos" ]] \
    || { echo "!! The spec of issue #$n lists no repo under \"## Affected repos\" (see templates/spec.md)" >&2; return 1; }

  known="$(read_repos | awk '{print $1}')"
  for repo in $repos; do
    grep -qxF "$repo" <<< "$known" || unknown="$unknown $repo"
  done
  [[ -z "$unknown" ]] || { echo "!! The spec of issue #$n names repos that are not in repos.txt:$unknown" >&2; return 1; }

  if grep -qxF bug <<< "$labels"; then type=fix; else type=feature; fi
  echo "$type/$n-$(slug "$title")"
  echo "$repos"
}

# Leaves the branch of issue <n> in worktrees of its repos. Sets ISSUE_BRANCH, ISSUE_REPOS
# (one per line) and ISSUE_WORKTREES (paths from the root, separated by spaces).
checkout_issue() {
  local out repo path
  out="$(issue_branch "$1")" || return 1
  ISSUE_BRANCH="${out%%$'\n'*}"; ISSUE_REPOS="${out#*$'\n'}"; ISSUE_WORKTREES=""
  # shellcheck disable=SC2086 # repo names have no spaces
  cmd_branch "$ISSUE_BRANCH" $ISSUE_REPOS || return 1
  for repo in $ISSUE_REPOS; do
    path="$(worktree_of "$repo" "$ISSUE_BRANCH")"
    ISSUE_WORKTREES+="${ISSUE_WORKTREES:+ }${path#"$(cd "$ROOT" && pwd -P)"/}"
  done
}

need_issue() {
  is_issue "${2:-}" || { echo "Give the number of the issue, e.g.: $1 42" >&2; exit 1; }
}

cmd_explore() {
  warn_ecosystem
  exec scripts/agent.sh explore ${1:+"Idea: $1"}
}

# Drafts go to a folder of their own in .work/ until the issue has a number: the agent
# renames it to .work/<n>/ once it creates the issue.
cmd_propose() {
  warn_ecosystem
  local type="${1:-}" idea="${2:-}" draft
  [[ "$type" == feature || "$type" == bug ]] || { echo "Give the type: propose <feature|bug> [idea]" >&2; exit 1; }
  mkdir -p .work
  draft="$(mktemp -d ".work/draft-$(date +%Y%m%d)-XXXX")"
  exec scripts/agent.sh propose "Type: $type" "Draft: $draft" ${idea:+"Idea: $idea"}
}

cmd_verify() {
  warn_ecosystem
  need_issue verify "${1:-}"
  exec scripts/agent.sh verify "$1"
}

cmd_apply() {
  warn_ecosystem
  need_issue apply "${1:-}"
  checkout_issue "$1" || exit 1
  mkdir -p ".work/$1"
  exec scripts/agent.sh apply "$1" "Branch: $ISSUE_BRANCH" "Worktrees: $ISSUE_WORKTREES"
}

# Reviewed in a new session, from the worktrees (from the remote branch if someone else built
# it) and its PRs, against the spec.
cmd_review() {
  warn_ecosystem
  need_issue review "${1:-}"
  local n="$1" repo prs context=()
  checkout_issue "$n" || exit 1
  context=("Branch: $ISSUE_BRANCH" "Worktrees: $ISSUE_WORKTREES")
  for repo in $ISSUE_REPOS; do
    prs="$(scripts/host.sh pr-list "$repo" "$ISSUE_BRANCH" 2> /dev/null | paste -sd ',' - | sed 's/,/, /g')" \
      || prs="could not be listed"
    context+=("PRs of $repo: ${prs:-none}")
  done
  mkdir -p ".work/$n"

  # With AGENT_REVIEWER set to another agent, that agent reviews first and AGENT checks its report.
  local reviewer="${AGENT_REVIEWER:-}" first
  if [[ -n "$reviewer" && "$reviewer" != "${AGENT:-}" ]]; then
    first=".work/$n/review-$reviewer.md"
    rm -f "$first"
    AGENT="$reviewer" scripts/agent.sh review "$n" "${context[@]}" "Report: $first" \
      || echo "!! The review by $reviewer ended with an error"
    if [[ -s "$first" ]]; then
      context+=("First review: $first, by $reviewer")
    else
      echo "!! $reviewer left no report in $first: ${AGENT:-the main agent} reviews alone"
    fi
  fi
  exec scripts/agent.sh review "$n" "${context[@]}" "Report: .work/$n/review.md"
}

# Only once every PR of the issue is merged: the agent writes the final summary (and opens the
# docs/ PR if needed); then the summary is published, the issue closed and its worktrees,
# branches and temporary files removed.
cmd_archive() {
  warn_ecosystem
  need_issue archive "${1:-}"
  local n="$1" out branch repos repo state _number url merged open problems=() summary
  out="$(issue_branch "$n")" || exit 1
  branch="${out%%$'\n'*}"; repos="${out#*$'\n'}"

  for repo in $repos; do
    merged=0; open=""
    out="$(scripts/host.sh pr-list "$repo" "$branch")" || { problems+=("$repo: its PRs could not be listed"); continue; }
    while read -r state _number url; do
      case "$state" in
        merged) merged=$((merged + 1)) ;;
        open) open+="${open:+, }$url" ;;
      esac
    done <<< "$out"
    if [[ -n "$open" ]]; then problems+=("$repo: PR not merged: $open")
    elif [[ $merged -eq 0 ]]; then problems+=("$repo: no merged PR of $branch")
    fi
  done
  if [[ ${#problems[@]} -gt 0 ]]; then
    echo "!! #$n cannot be closed yet:" >&2
    printf '   - %s\n' "${problems[@]}" >&2
    exit 1
  fi

  summary=".work/$n/summary.md"
  mkdir -p ".work/$n"
  scripts/agent.sh archive "$n" "Branch: $branch" "Repos: ${repos//$'\n'/ }" "Summary: $summary" || true
  [[ -s "$summary" ]] || { echo "!! No summary in $summary: #$n is not closed and nothing is removed" >&2; exit 1; }
  scripts/host.sh issue-comment "$n" "$summary"
  scripts/host.sh issue-close "$n" completed

  for repo in $repos; do remove_issue_branch "$repo" "$branch"; done
  rm -rf ".work/$n"
  echo "-> #$n closed, with the summary published"
}

# Drops an issue: closes its open PRs with the reason, publishes it on the issue, closes it as
# not planned and removes worktrees, branches and temporary files. Does nothing if a PR is
# already merged: revert it first. If the spec lists no valid repo (a proposal left halfway),
# only the issue is closed.
cmd_reject() {
  warn_ecosystem
  need_issue reject "${1:-}"
  local n="$1" reason="${2:-}" out branch="" repos="" repo state number url problems=() closes=() pr
  [[ -n "$reason" ]] || { echo "Give the reason: reject $n \\"<reason>\\"" >&2; exit 1; }
  if out="$(issue_branch "$n" 2> /dev/null)"; then
    branch="${out%%$'\n'*}"; repos="${out#*$'\n'}"
  else
    echo "   The spec of #$n lists no valid repo: only the issue is closed"
  fi

  for repo in $repos; do
    out="$(scripts/host.sh pr-list "$repo" "$branch")" || { problems+=("$repo: its PRs could not be listed"); continue; }
    while read -r state number url; do
      case "$state" in
        merged) problems+=("$repo: $url is already merged; revert it with another PR (see the spec's Rollback)") ;;
        open) closes+=("$repo $number") ;;
      esac
    done <<< "$out"
  done
  if [[ ${#problems[@]} -gt 0 ]]; then
    echo "!! #$n cannot be rejected yet:" >&2
    printf '   - %s\n' "${problems[@]}" >&2
    exit 1
  fi

  mkdir -p ".work/$n"
  printf '%s\n' "$reason" > ".work/$n/reason.md"
  for pr in ${closes[@]+"${closes[@]}"}; do
    repo="${pr% *}"; number="${pr#* }"
    scripts/host.sh pr-close "$repo" "$number" ".work/$n/reason.md" \
      || { echo "!! $repo: could not close PR $number; close it by hand and run reject again" >&2; exit 1; }
    echo "-> $repo: closed PR $number"
  done
  scripts/host.sh issue-comment "$n" ".work/$n/reason.md"
  scripts/host.sh issue-close "$n" not-planned

  for repo in $repos; do remove_issue_branch "$repo" "$branch"; done
  rm -rf ".work/$n"
  echo "-> #$n rejected, with the reason published"
}

# Removes the worktree and the branch (local and remote) of an issue in a repo. A worktree
# with uncommitted changes is kept, with its branch.
remove_issue_branch() {
  local repo="$1" branch="$2" path main linked=""
  path="$(worktree_of "$repo" "$branch")"
  main="$(git -C "$repo" worktree list --porcelain | sed -n '1s/^worktree //p')"
  if [[ -n "$path" ]]; then
    if [[ -n "$(git -C "$path" status --porcelain)" ]]; then
      echo "   $repo: $path has uncommitted changes; it is kept, with its branch"; return
    fi
    [[ "$path" == "$(cd "$repo" && pwd -P)" ]] && linked=yes
    if ! git -C "$main" worktree remove "$path" 2> /dev/null; then
      # Containers leave files owned by root (caches, reports) that only root can delete.
      echo "!! $repo: could not remove $path (files owned by another user, e.g. root from a container?)."
      echo "   Remove it with: sudo rm -rf '$path' && git -C '$main' worktree prune"
      return
    fi
    # It was a linked repo: it becomes the link again.
    [[ -z "$linked" ]] || ln -s "$main" "$repo"
  fi
  git -C "$main" branch -D "$branch" > /dev/null 2>&1 || true
  if git -C "$main" ls-remote --exit-code --heads origin "$branch" > /dev/null 2>&1; then
    git -C "$main" push --quiet origin --delete "$branch"
  fi
  echo "-> $repo: removed the worktree and the branch $branch"
}

# Files a team fills in when adopting the template.
context_files() {
  local f
  for f in AGENTS.md openspec/config.yaml docs/system-map.md docs/product/*.md docs/product/decisions/[0-9]*.md; do
    [[ -f "$f" && "$f" != */README.md ]] && echo "$f"
  done
}

# Prints "P file:line: <token>" for each unfilled placeholder and "T file:line: text" for
# each TODO, ignoring HTML comments. <id>, <n>, <slug>, <repo>, <branch>, <step>, <reason>
# and <short-description> are notation used by the rules themselves, not placeholders.
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
        if (token !~ /^<(id|n|slug|repo|branch|step|reason|short-description)>$/) print "P " FILENAME ":" FNR ": " token
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

  # The workflow commands need the git host CLI, logged in.
  if ! warning="$(scripts/host.sh check-auth 2>&1)"; then
    echo "   ${warning#!! }: the workflow commands need it"; warnings=$((warnings + 1))
  fi

  # Anything ignored that is not a service repo never reaches the rest of the team.
  if git rev-parse --git-dir > /dev/null 2>&1; then
    local services path top
    services=" $(read_repos | awk '{printf "%s ", $1}')"
    while read -r path; do
      top="${path%%/*}"
      [[ "$services" == *" $top "* ]] && continue
      # Personal settings and temporary files, ignored on purpose.
      case "$path" in
        .claude/settings.local.json|local.mk|.work/*|.worktrees/*|docs/superpowers/*|openspec/changes/*) continue ;;
      esac
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
    shellcheck "$ROOT/bootstrap.sh" "$ROOT"/scripts/*.sh "$ROOT"/tests/*.test.sh || { [[ $code -ne 0 ]] || code=1; }
  else
    echo "   shellcheck is not installed: lint skipped"
  fi
  return "$code"
}

case "${1:-}" in
  status) cmd_status ;;
  branch) shift; cmd_branch "$@" ;;
  explore) shift; cmd_explore "$@" ;;
  propose) shift; cmd_propose "$@" ;;
  verify) shift; cmd_verify "$@" ;;
  apply) shift; cmd_apply "$@" ;;
  review) shift; cmd_review "$@" ;;
  archive) shift; cmd_archive "$@" ;;
  reject) shift; cmd_reject "$@" ;;
  doctor) cmd_doctor ;;
  tests) cmd_tests ;;
  ""|--all) cmd_sync "${1:-}" ;;
  *) awk 'NR > 1 && /^#/ { sub(/^# ?/, ""); print; next } NR > 1 { exit }' "$0"; exit 1 ;;
esac
