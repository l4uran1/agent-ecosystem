#!/usr/bin/env bash
# The git host's issues and pull requests, with gh (GitHub) or glab (GitLab), so the workflow
# commands and the agents use the same few operations on either host.
#
# Usage: scripts/host.sh <command> [args]
#   issue-create <feature|bug> <title> <body-file>
#                                  create an issue in the ecosystem repo and print its number.
#                                  A bug gets the label "bug" (created if it does not exist)
#   issue-get <n> <field>          print a field of issue <n>: title, body, labels (one per
#                                  line), url or state (open or closed)
#   issue-set-body <n> <file>      replace the body of issue <n> (the spec)
#   issue-comment <n> <file>       comment on issue <n>
#   issue-close <n> <completed|not-planned>
#   pr-list <repo> <branch>        PRs of <branch> in the service repo <repo>, in any state, one
#                                  per line: "<open|merged|closed> <number> <url>"
#   pr-close <repo> <number> <comment-file>
#                                  comment on a PR of <repo> and close it
#   check-auth                     check the CLI is installed and logged in
#
# Issues live in the ecosystem repo; PRs in each service repo. GIT_HOST picks the CLI (gh or
# glab); by default, glab if the ecosystem repo's origin URL contains "gitlab", gh otherwise.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

die() { echo "!! $*" >&2; exit 1; }

host="${GIT_HOST:-}"
if [[ -z "$host" ]]; then
  case "$(git -C "$ROOT" remote get-url origin 2> /dev/null || true)" in
    *gitlab*) host=glab ;;
    *) host=gh ;;
  esac
fi
[[ "$host" == gh || "$host" == glab ]] || die "GIT_HOST=$host is not valid: use gh or glab"

usage() { awk 'NR > 1 && /^#/ { sub(/^# ?/, ""); print; next } NR > 1 { exit }' "$0" >&2; exit 1; }

issue_create() {
  local type="$1" title="$2" body="$3" out
  [[ "$type" == feature || "$type" == bug ]] || die "Type must be feature or bug, not $type"
  [[ -f "$body" ]] || die "No body file: $body"
  cd "$ROOT"
  # ${labels[@]+...}: an empty array is an unbound variable for the bash 3.2 of macOS.
  local labels=()
  if [[ "$host" == gh ]]; then
    if [[ "$type" == bug ]]; then
      gh label create bug --force > /dev/null 2>&1 || true
      labels=(--label bug)
    fi
    out="$(gh issue create --title "$title" --body-file "$body" ${labels[@]+"${labels[@]}"})"
  else
    if [[ "$type" == bug ]]; then
      glab label create --name bug > /dev/null 2>&1 || true
      labels=(--label bug)
    fi
    out="$(glab issue create --title "$title" --description-file "$body" --yes ${labels[@]+"${labels[@]}"})"
  fi
  # Both CLIs print the URL of the new issue, which ends with its number.
  grep -oE '/issues/[0-9]+' <<< "$out" | tail -n 1 | cut -d/ -f3 | grep . \
    || die "Could not read the number of the new issue from: $out"
}

issue_get() {
  local n="$1" field="$2" filter
  cd "$ROOT"
  if [[ "$host" == gh ]]; then
    case "$field" in
      title) filter='.title' ;;
      body) filter='.body' ;;
      labels) filter='.labels[].name' ;;
      url) filter='.url' ;;
      state) filter='.state | ascii_downcase' ;;
      *) die "Unknown field: $field (title, body, labels, url, state)" ;;
    esac
    gh issue view "$n" --json title,body,labels,url,state | jq -r "$filter"
  else
    case "$field" in
      title) filter='.title' ;;
      body) filter='.description // ""' ;;
      labels) filter='.labels[]' ;;
      url) filter='.web_url' ;;
      state) filter='if .state == "opened" then "open" else .state end' ;;
      *) die "Unknown field: $field (title, body, labels, url, state)" ;;
    esac
    glab issue view "$n" -F json | jq -r "$filter"
  fi
}

issue_set_body() {
  cd "$ROOT"
  # REST, not gh issue edit: older gh versions fail on it since Projects (classic) was retired.
  if [[ "$host" == gh ]]; then gh api --method PATCH "repos/{owner}/{repo}/issues/$1" -F "body=@$2" > /dev/null
  else glab issue update "$1" --description-file "$2"
  fi
}

issue_comment() {
  cd "$ROOT"
  if [[ "$host" == gh ]]; then gh issue comment "$1" --body-file "$2"
  else glab issue note "$1" -m "$(cat "$2")"
  fi
}

issue_close() {
  local n="$1" reason="$2"
  [[ "$reason" == completed || "$reason" == not-planned ]] || die "Reason must be completed or not-planned"
  cd "$ROOT"
  if [[ "$host" == gh ]]; then gh issue close "$n" --reason "${reason/-/ }"
  else glab issue close "$n"
  fi
}

pr_list() {
  local repo="$1" branch="$2"
  cd "$ROOT/$repo"
  if [[ "$host" == gh ]]; then
    gh pr list --head "$branch" --state all --json number,state,url \
      | jq -r '.[] | "\(.state | ascii_downcase) \(.number) \(.url)"'
  else
    glab mr list -A --source-branch "$branch" -F json \
      | jq -r '.[] | "\(if .state == "opened" then "open" else .state end) \(.iid) \(.web_url)"'
  fi
}

pr_close() {
  local repo="$1" n="$2" comment
  comment="$(cat "$3")"
  cd "$ROOT/$repo"
  if [[ "$host" == gh ]]; then
    gh pr close "$n" --comment "$comment"
  else
    # glab api, not glab mr note: its flags change between glab versions.
    glab api --method POST "projects/:id/merge_requests/$n/notes" -f "body=$comment" > /dev/null
    glab mr close "$n"
  fi
}

check_auth() {
  command -v "$host" > /dev/null || die "$host is not installed"
  command -v jq > /dev/null || die "jq is not installed"
  "$host" auth status > /dev/null 2>&1 || die "$host is not logged in: run $host auth login"
}

cmd="${1:-}"; shift || true
case "$cmd" in
  issue-create) [[ $# -eq 3 ]] || usage; issue_create "$@" ;;
  issue-get) [[ $# -eq 2 ]] || usage; issue_get "$@" ;;
  issue-set-body) [[ $# -eq 2 ]] || usage; issue_set_body "$@" ;;
  issue-comment) [[ $# -eq 2 ]] || usage; issue_comment "$@" ;;
  issue-close) [[ $# -eq 2 ]] || usage; issue_close "$@" ;;
  pr-list) [[ $# -eq 2 ]] || usage; pr_list "$@" ;;
  pr-close) [[ $# -eq 3 ]] || usage; pr_close "$@" ;;
  check-auth) check_auth ;;
  *) usage ;;
esac
