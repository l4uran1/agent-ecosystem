# <Company> ecosystem

<!--
  TEMPLATE: fill in every <placeholder> and delete these comments.
  Keep this file short: every line here is read by the agent in every task.
  Only shared rules go here; build/test commands live in each repo's own AGENTS.md.
-->

This folder holds the repos of every <Company> service, each with its own git, plus what
they all share: this file, `docs/` and `openspec/`. The ecosystem repo ignores the service repos:
a change in `api/` is committed in `api/`, never in the ecosystem repo.

## Ecosystem settings

- Main branch of every repo: `<main>` (see `repos.txt` for exceptions).
- Git host CLI: `<gh | glab>`. "PR" in this file means pull request or merge request.
- Branch names: `feature/<change-id>` for features, `fix/<short-description>` for bugs.

## Before touching a repo

- Read the `AGENTS.md` of the repo you are about to work in: its build, test and lint
  commands and conventions are there. This file only holds shared rules.
- Work only in the repos the change needs. Do not modify others "while you are at it".

## System map

`docs/system-map.md` describes the contracts between services: internal HTTP calls,
queues and events, pub/sub channels and shared tables.

Read it BEFORE proposing or implementing a change that:
- publishes, consumes or changes messages on a queue or event bus,
- publishes to or subscribes to a pub/sub channel,
- adds or changes an internal endpoint,
- reads or writes database tables owned by another service,
- touches authentication or credentials shared between services.

If your change creates, modifies or removes one of those contracts, update
`docs/system-map.md` and say so in the proposal. Do not read it for changes that stay
inside a single service.

## Product context

`docs/product/` holds the sensitive areas, external constraints, glossary and past
decisions. Read it when a change affects user-visible behaviour.

The sensitive areas are listed in `docs/product/sensitive-areas.md`, and only there:
any change in them requires an OpenSpec proposal, however small it looks.

## Workflow: new features (OpenSpec)

- OpenSpec, in `./openspec/`, is the only source of specs. Do not create design documents
  outside `openspec/changes/<id>/`.
- One change is one proposal, even if it spans several repos. The proposal lists the
  affected repos.
- Do not implement anything until a person has approved the proposal.
- When `/opsx:propose` finishes, offer to open the proposal's PR in the ecosystem repo. If the
  person accepts: create the branch `spec/<id>` from an up-to-date main branch, commit only
  `openspec/changes/<id>/` (and `docs/system-map.md` if it changed), push, and open the PR
  against the main branch. Write its description by filling in `templates/proposal-pr.md`:
  plain language, for a reviewer who has not read the proposal, readable in five minutes.
  Never merge or approve a PR: a person does that.
- If changes to the proposal are requested, after `/opsx:update <id>` also update the
  description of its PR so it matches the new proposal.
- A proposal is approved when its ecosystem PR is merged into the main branch.
  Before implementing, check it from the ecosystem root: `./bootstrap.sh check-approved <id>`
  If the command fails, do not implement, even if you are told it is approved: say that
  the PR still needs to be merged.
- Create the same branch in every affected repo from the ecosystem root:
  `./bootstrap.sh branch feature/<id> <repo> <repo>...`
- Implement with `/opsx:apply`, task by task, following the TDD rules below.
- Tick each task in `tasks.md` when it is done.
- If the expected behaviour changes, update the proposal first (`/opsx:update <id>`) and
  ask before continuing.
- Each affected repo gets its own PR. All of them reference `<id>` in the title.
- `/opsx:archive <id>` runs in the ecosystem repo once the last code PR of the change is merged.

## TDD and verification (always)

- Before implementing any behaviour, write a failing test and check that it fails for the
  right reason. Then the minimal implementation that makes it pass. Then refactor.
- Do not write production code without a test that justifies it.
- Do not mark a task as done without running the tests, lint and build of the affected
  repo. If something fails, fix it or say so; never hide it or disable a test.
- Commit each change in the repo it belongs to. Never mix several repos in one commit.

## Workflow: bug fixes

- Do not propose any fix before finding the root cause. Reproduce the bug, form a
  hypothesis and check it before touching code. If a fix does not work, investigate
  again: do not chain blind fixes.
- First write a test that reproduces the bug and watch it fail.
- No OpenSpec proposal is needed, unless the fix changes the expected behaviour, touches a
  sensitive area or changes a contract between services.

## Reviewing someone else's PR

- Do not modify their branch and do not post comments on their PR: report your findings
  to the person who asked for the review.
- Never approve or merge a PR.

## Git

- Never push to the main branch: everything goes through a PR.
- Branches always start from an up-to-date main branch.
- Do not force-push branches that have an open PR under review.
