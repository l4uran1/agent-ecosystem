<!--
  Description of a proposal PR in the ecosystem repo.
  The agent fills it in when it opens the PR. It is written for the reviewer:
  plain language, no implementation detail, readable in five minutes.
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

## Decisions for the reviewer

<!-- Open questions or trade-offs the reviewer should confirm. Leave "none" if there are none. -->

-

## How to review this PR

**Read:** this description and `proposal.md`. For the exact expected behaviour, the scenarios
in `specs/`.
**Optional:** `design.md`, if you want to check the technical approach.
**Skip:** `tasks.md` and `.openspec.yaml`. They are the agent's work plan and metadata, and
are collapsed in the diff.

Approve only if you can answer yes to all of these:

- [ ] The problem is real and worth solving now.
- [ ] The behaviour changes are what we want, including the edge cases.
- [ ] The scope is right: nothing missing, nothing extra.
- [ ] The impact on other services and sensitive areas is understood and acceptable.

To ask for changes, comment here. The author updates the proposal with
`/opsx:update <id>` and pushes again.
