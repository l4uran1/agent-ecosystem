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
# Settings, in local.mk (the Makefile includes it) or in the environment:
#   AGENT    the command that starts your agent with a first message: claude, codex...
#   METHOD   openspec, superpowers or default (the default)
#
# The first message joins prompts/<step>.md (what to achieve, the same for everyone) and the
# method's instructions: prompts/method/<METHOD>/<step>.md or, if it does not exist,
# prompts/method/<METHOD>/default.md. The agent starts at the ecosystem root, so it reads
# AGENTS.md.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
METHOD="${METHOD:-default}"

die() { echo "!! $*" >&2; exit 1; }

step="${1:?Usage: scripts/agent.sh <step> [issue] [context...]}"; shift
[[ -f "$ROOT/prompts/$step.md" ]] || die "No instructions for the step \"$step\" (prompts/$step.md)"

[[ -n "${AGENT:-}" ]] || die "AGENT is not set. Create local.mk at the ecosystem root with:
     AGENT = claude        # or codex, or another agent that takes a first message
     METHOD = default      # or openspec, superpowers"
command -v "$AGENT" > /dev/null || die "AGENT=$AGENT is not installed"
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

cd "$ROOT"
exec "$AGENT" "$prompt"
