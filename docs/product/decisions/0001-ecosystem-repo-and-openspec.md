# 0001 · Shared ecosystem repo and OpenSpec as the single source of specs

- Status: Proposed
- Date: <YYYY-MM-DD>

## Context
The services live in separate repos but are tightly coupled (queues, pub/sub channels,
internal endpoints and shared tables), and most features touch several of them. We wanted
coding agents to work with the same context and the same process across the whole team,
without duplicating documentation in every repo.

## Decision
A shared repo, the ecosystem repo, which is also the main development folder. It holds the rules for
agents (`AGENTS.md`), the system map, the product context and the OpenSpec specs for the
whole system. The service repos are cloned inside it with `bootstrap.sh` and the ecosystem repo
ignores them. A change is a single OpenSpec proposal even when it spans several repos.

## Alternatives considered
- **OpenSpec and context in every repo:** duplicated information and split features that
  span several services into several proposals.
- **Submodules for the shared context:** added complexity without solving the split.
- **Monorepo:** would solve the same problem, but with a migration (history, CI,
  deployments, permissions) out of proportion to the benefit.

## Consequences
- The spec and the code are reviewed in different PRs: the proposal in the ecosystem repo and
  the code in each repo. The spec is archived when the last code PR is merged.
- The whole team must use the same folder layout (`bootstrap.sh`).
- The agent must be started from the ecosystem root to read the shared rules.
