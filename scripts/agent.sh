#!/usr/bin/env bash
# Starts each person's agent with the instructions of one step of the workflow.
#
# Usage: scripts/agent.sh <step> [issue] [context...]
#   <step>      explore, propose, verify, apply, review or archive (prompts/<step>.md)
#   [issue]     number of an issue of the ecosystem repo: its title, url and body (the spec)
#               are added to the instructions. If the first argument is not a number, every
#               argument is context
#   [context]   lines added at the end, e.g. "Branch: feature/42-export-orders"
#
# Settings, in local.mk (the Makefile includes it; scripts/local-mk.sh reads it without make) or
# in the environment:
#   AGENT    the command that starts your agent with a first message: claude, codex, agent (the
#            Cursor CLI; also cursor-agent)...
#   METHOD   openspec, superpowers or default (the default)
#
# From a terminal, it starts a new session of the agent. From the shell of an agent (no terminal,
# or CLAUDECODE, CODEX_THREAD_ID or CURSOR_AGENT set, because Codex and Cursor may give it a PTY)
# it prints the instructions, for that same session to follow. AGENT_SESSION=new or current
# forces one or the other. AGENT_SESSION=headless starts a new session without a UI that nobody
# attends (claude -p, codex exec or agent -p), without asking for permissions, and prints its
# last answer: that is how verify and review get a clean session from inside an agent.
#
# The first message joins prompts/<step>.md (what to achieve, the same for everyone) and the
# method's instructions: prompts/method/<METHOD>/<step>.md or, if it does not exist,
# prompts/method/<METHOD>/default.md. The agent starts at the ecosystem root, so it reads
# AGENTS.md.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/local-mk.sh
source "$ROOT/scripts/local-mk.sh"
load_local_mk
METHOD="${METHOD:-default}"
AGENT_SESSION="${AGENT_SESSION:-$([[ -t 0 && -z "${CLAUDECODE:-}${CODEX_THREAD_ID:-}${CURSOR_AGENT:-}" ]] && echo new || echo current)}"

die() { echo "!! $*" >&2; exit 1; }

step="${1:?Usage: scripts/agent.sh <step> [issue] [context...]}"; shift
[[ -f "$ROOT/prompts/$step.md" ]] || die "No instructions for the step \"$step\" (prompts/$step.md)"

case "$METHOD" in
  openspec|superpowers|default) ;;
  *) die "METHOD=$METHOD is not valid: use openspec, superpowers or default" ;;
esac

prompt="$(cat "$ROOT/prompts/$step.md")"
for method_file in "$ROOT/prompts/method/$METHOD/$step.md" "$ROOT/prompts/method/$METHOD/default.md"; do
  if [[ -f "$method_file" ]]; then prompt+=$'\n\n'"$(cat "$method_file")"; break; fi
done

if [[ $# -gt 0 && "$1" =~ ^[0-9]+$ ]]; then
  issue="$1"; shift
  # Read before starting: if the issue does not exist, the agent is not started.
  title="$("$ROOT/scripts/host.sh" issue-get "$issue" title)"
  url="$("$ROOT/scripts/host.sh" issue-get "$issue" url)"
  body="$("$ROOT/scripts/host.sh" issue-get "$issue" body)"
  prompt+=$'\n\n'"## Issue"$'\n\n'"Issue #$issue: $title ($url)"$'\n\n'"$body"
fi
if [[ $# -gt 0 ]]; then
  prompt+=$'\n\n'"## Context"$'\n\n'
  prompt+="$(printf '%s\n' "$@")"
fi

if [[ "$AGENT_SESSION" == current ]]; then
  printf '%s\n\n%s\n' "Instructions of the step \"$step\": follow them in this session." "$prompt"
  exit 0
fi

[[ -n "${AGENT:-}" ]] || die "AGENT is not set. Create local.mk at the ecosystem root with:
     AGENT = claude        # or codex, agent (Cursor), or another agent that takes a first message
     METHOD = default      # or openspec, superpowers"
command -v "$AGENT" > /dev/null || die "AGENT=$AGENT is not installed"
cd "$ROOT"
if [[ "$AGENT_SESSION" == headless ]]; then
  # env -u: the session started here is a new one, not headless itself.
  case "$AGENT" in
    claude) exec env -u AGENT_SESSION claude -p --permission-mode bypassPermissions "$prompt" ;;
    codex) exec env -u AGENT_SESSION codex exec --dangerously-bypass-approvals-and-sandbox "$prompt" ;;
    # --trust: without it, the Cursor CLI asks whether to trust the folder, and nobody answers.
    agent|cursor-agent) exec env -u AGENT_SESSION "$AGENT" -p --force --trust "$prompt" ;;
    *) die "AGENT=$AGENT cannot run without a UI: use claude, codex or agent" ;;
  esac
fi
exec "$AGENT" "$prompt"
