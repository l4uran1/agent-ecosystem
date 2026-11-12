# 0001 · Shared ecosystem repo, specs on issues and agent-agnostic workflow commands

- Status: Proposed
- Date: <YYYY-MM-DD>

## Context
The services live in separate repos but are tightly coupled (queues, pub/sub channels,
internal endpoints and shared tables), and most features touch several of them. We wanted
coding agents to work with the same context and the same process across the whole team,
without duplicating documentation in every repo and without forcing everyone onto the same
agent or tool.

## Decision
A shared repo, the ecosystem repo, which is also the main development folder. It holds the
rules for agents (`AGENTS.md`), the system map, the product context and the workflow. The
service repos are cloned inside it with `bootstrap.sh` and the ecosystem repo ignores them.

Every change, even when it spans several repos, has one issue in the ecosystem repo whose
body is the spec (`templates/spec.md`). One `make` command per step (`propose`, `apply`,
`review`, `archive`...) does the mechanical part with tested scripts and starts each
person's agent with the shared instructions of that step (`prompts/`). Each person picks
their agent and their method (default, OpenSpec or Superpowers) in `local.mk`.

## Alternatives considered
- **Context and specs in every repo:** duplicated information, and features that span
  several services split into several specs.
- **OpenSpec as the only source of specs, with a spec PR in the ecosystem repo:** one more PR
  per change that stays open during the whole implementation, about fifteen steps per
  change, and everyone tied to one tool.
- **Submodules for the shared context:** added complexity without solving the split.
- **Monorepo:** would solve the same problem, but with a migration (history, CI,
  deployments, permissions) out of proportion to the benefit.

## Consequences
- The spec is reviewed on the issue and the code in each repo's PR. Specs that touch
  sensitive areas or contracts are reviewed on the issue before building.
- What the product does is kept in `docs/product/` and `docs/system-map.md`, which
  `make archive` keeps up to date through a PR a person reviews.
- The whole team must use the same folder layout (`bootstrap.sh`) and start the workflow from
  the ecosystem root.
- The workflow depends on the git host CLI (`gh` or `glab`) and on agents that take a first
  message on the command line.
