<!--
  Description of a proposal PR in the ecosystem repo.
  The agent fills it in when it opens the PR and keeps it up to date during the
  implementation. It is written for the reviewer: plain language, no implementation
  detail, readable in five minutes.
-->

## Summary

<!-- Two or three sentences: the problem, and what changes for users once this is built. -->

## Behaviour changes

<!-- One line per change, in plain language: "When <situation>, <what happens now>".
     Mark anything that changes existing behaviour (not just adds new behaviour) with ⚠️. -->

-

## Scope

- **In:** <!-- what this change covers -->
- **Out:** <!-- what it deliberately does not cover -->

## Impact

| Repo | What changes |
| --- | --- |
| | |

- **Contracts between services:** <!-- queues, channels, internal endpoints, shared tables that change; or "none" -->
- **Sensitive areas:** <!-- which ones and the risk for users; or "none" -->
- **Rollback:** <!-- how to undo it if it goes wrong -->

## Changes during implementation

<!-- What changed from the original proposal while it was being built, and why.
     One line per change. "None" if there are none. -->

-

## Code PRs

<!-- One per repo, with its state. This PR is merged once all of them are merged. -->

-

## Decisions for the reviewer

<!-- Open questions or trade-offs the reviewer should confirm. Leave "none" if there are none. -->

-

## How to review this PR

This PR is opened before the change is built and merged **at the end**, once every code PR
is merged. You can comment at any time; changes are applied on this same branch. At the end
it also carries the archive: the proposal moves to `archive/` and its specs to
`openspec/specs/`.

**Read:** this description and `proposal.md`. For the exact expected behaviour, the scenarios
in `specs/`.
**Optional:** `design.md`, if you want to check the technical approach.
**Skip:** `tasks.md` and `.openspec.yaml`. They are the agent's work plan and metadata, and
are collapsed in the diff.

Approve only if you can answer yes to all of these:

- [ ] The problem is real and worth solving now.
- [ ] The behaviour changes are what we want, including the edge cases and the ones that
      came up during implementation.
- [ ] The scope is right: nothing missing, nothing extra.
- [ ] The impact on other services and sensitive areas is understood and acceptable.
- [ ] Every code PR is merged and the archive is included.

To ask for changes, comment here. The author updates the proposal with
`/opsx:update <id>` and pushes again.
