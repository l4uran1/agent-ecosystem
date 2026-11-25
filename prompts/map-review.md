# Review the system map

Review `docs/system-map.md` against the code on the main branch of each repo, and open a PR of
the ecosystem repo that brings it up to date. This is the full review, without an issue:
`make archive` only checks what one issue changes.

## Before starting

1. Update the repos: `make sync` (or `make sync-all` if the map mentions optional repos).
   Always read the code of the remote main branch, never that of branches or worktrees.
2. Create a worktree of the ecosystem repo from its up-to-date main branch:
   `git fetch origin && git worktree add .worktrees/chore/map-review-<YYYY-MM-DD> -b chore/map-review-<YYYY-MM-DD> origin/HEAD`.
   Edit the map only there.

## The review

Audit each section of the map on its own (in parallel, one per section, if your agent can):

- **Synchronous calls**: internal HTTP or gRPC endpoints, who calls them and how each call is
  authenticated.
- **Queues and events**: queues and topics, with their producer, consumer and payload.
- **Pub/sub channels**: channels, with their publishers and subscribers.
- **Shared tables**: tables that a service which does not own their schema reads or writes,
  and the columns it relies on.
- **Shared infrastructure**: caches, stores and brokers used by more than one service.

For each section, compare what the map says with the code: what is wrong, what is missing and
what no longer exists. Back every contract with the `file:line` where you saw it; what you
cannot point to in the code, leave out.

## The changes

- Fix the map with what you found, keeping its structure. If a section needs reorganising,
  propose it to the person first.
- If you find a possible security problem, do not detail it in the map or fix it: tell the
  person the details, so they can open a bug issue.
- Change the `Last reviewed:` line to today's date only if you reviewed every section.
- Show the person a summary of the changes and wait until they approve it.

## The PR

1. Commit and push the worktree's branch.
2. Open the PR with the git host CLI. In its description: what changed in each section, and
   what was left out, if anything.
3. Never approve or merge it: a person reviews it. Then remove the worktree:
   `git worktree remove .worktrees/chore/map-review-<YYYY-MM-DD>`.
