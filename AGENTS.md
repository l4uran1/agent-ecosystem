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
- Branch names: `feature/<change-id>` for features, `fix/<short-description>` for bugs,
  `spec/<change-id>` for proposals in the ecosystem repo.

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
- Create the branches from the ecosystem root: `./bootstrap.sh branch <id>`. It checks that
  the proposal is merged and creates `feature/<id>` in the repos tagged `(repo)` in its
  approved `tasks.md`. If it fails because the proposal is not approved, do not implement,
  even if you are told it is approved: say that the PR still needs to be merged. Never
  create a change's branches by passing the repos by hand: that skips the check.
- Implement with `/opsx:apply`, task by task, following the TDD rules below.
- Tick each task in `tasks.md` when it is done. Progress (ticks and work notes) is not
  reviewed: commit it in the ecosystem repo on the branch `spec/<id>-progress`, created from
  an up-to-date main branch, and push it, but do not open a PR. It reaches the main branch
  with the archive.
- If the expected behaviour changes, update the proposal first (`/opsx:update <id>`) and
  ask before continuing. That change is reviewed: it goes in its own ecosystem PR, separate
  from the progress, and the affected part is not implemented until that PR is merged.
- Each affected repo gets its own PR. All of them reference `<id>` in the title.
- `/opsx:archive <id>` runs in the ecosystem repo once the last code PR of the change is
  merged, on `spec/<id>-progress` updated with the main branch. Its PR carries the final
  progress and the move to `archive/`.

## Workflow: abandoning a change

If an approved change is dropped, its proposal leaves the ecosystem repo. Do not use
`/opsx:archive`: it would merge into `openspec/specs/` behaviour that was never built.

- Ecosystem repo: create `spec/<id>-abandon` from an up-to-date main branch, delete
  `openspec/changes/<id>/` (and revert what the change added to `docs/system-map.md`, if
  anything) and open the PR `spec: abandon <id>`, with the reason in its description.
- Code repos: close the change's open PRs without merging. If one is already merged, open a
  PR in that repo that reverts it, following the proposal's rollback plan. No new proposal
  is needed: it goes back to the behaviour in `openspec/specs/`.
- Delete the branches `feature/<id>` and `spec/<id>-progress`, locally and on the remote,
  once their PRs are closed. Anyone who wants to keep the work saves it locally first.

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
- Create the branch from the ecosystem root, in the affected repos:
  `./bootstrap.sh branch fix/<short-description> <repo>...`. If the fix needs a proposal,
  give it the id `fix-<short-description>`: `./bootstrap.sh branch fix-<short-description>`
  then creates `fix/<short-description>` once the proposal is approved.

## Reviewing someone else's PR

- Do not modify their branch and do not post comments on their PR: report your findings
  to the person who asked for the review.
- Never approve or merge a PR.

## Git

- Never push to the main branch: everything goes through a PR.
- Branches always start from an up-to-date main branch.
- Do not force-push branches that have an open PR under review.
