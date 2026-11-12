# <Company> ecosystem

<!--
  TEMPLATE: fill in every <placeholder> and delete these comments.
  Keep this file short: every line here is read by the agent in every task.
  Only shared rules go here; build/test commands live in each repo's own AGENTS.md.
-->

This folder holds the repos of every <Company> service, each with its own git, plus what
they all share: this file, `docs/`, `prompts/` and the workflow scripts. The ecosystem repo
ignores the service repos: a change in `api/` is committed in `api/`, never in the ecosystem
repo.

## Ecosystem settings

- Main branch of every repo: `<main>` (see `repos.txt` for exceptions).
- Git host CLI: `<gh | glab>`. "PR" in this file means pull request or merge request.
- Branch names: `feature/<n>-<slug>` for features and `fix/<n>-<slug>` for bugs, where `<n>`
  is the number of the change's issue in the ecosystem repo. The workflow commands create
  them.

## Before touching a repo

- Read the `AGENTS.md` of the repo you are about to work in: its build, test and lint
  commands and conventions are there. This file only holds shared rules.
- Work only in the repos the change needs. Do not modify others "while you are at it".
- Modify a repo only from a worktree of its branch, never from its main checkout:
  `make apply` and `make review` create it in `<repo>/.worktrees/<branch>`. If `<repo>` is a
  symbolic link, do not write through it: they replace it with the worktree at that same
  path. If someone else already pushed the branch, the worktree starts from it.
- The ecosystem repo follows the same rule: its folder always stays on the main branch, up to
  date, because the workflow commands are its own files and another branch would run another
  version of them. Change the ecosystem repo itself (`AGENTS.md`, `docs/`, `prompts/`,
  scripts) in a worktree of it, e.g. `git worktree add .worktrees/<branch> -b <branch> origin/HEAD`.
  `./bootstrap.sh doctor` and the workflow commands warn when it is not on the main branch,
  up to date.

## System map

`docs/system-map.md` describes the contracts between services: internal HTTP calls,
queues and events, pub/sub channels and shared tables.

Read it BEFORE proposing or implementing a change that:
- publishes, consumes or changes messages on a queue or event bus,
- publishes to or subscribes to a pub/sub channel,
- adds or changes an internal endpoint,
- reads or writes database tables owned by another service,
- touches authentication or credentials shared between services.

If your change creates, modifies or removes one of those contracts, say so in the
*Contracts and sensitive areas* section of the spec. `make archive` checks at the end
whether `docs/system-map.md` must change. Do not read it for changes that stay inside a
single service.

## Product context

`docs/product/` holds the sensitive areas, external constraints, glossary and past
decisions. Read it when a change affects user-visible behaviour.

The sensitive areas are listed in `docs/product/sensitive-areas.md`, and only there. A
change that touches one, however small it looks, needs someone else on the team to review
its spec on the issue before it is built.

## Workflow

Every change, feature or bug, has an issue in the ecosystem repo whose body is the spec,
written with `templates/spec.md`. The steps are in `README.md`: `make explore`, `propose`,
`verify`, `apply`, `review`, `archive` and `reject`. Each one starts the person's agent with
the instructions of `prompts/<step>.md`.

- The spec on the issue is the only source of what gets built. Do not write design documents
  in the repos or in the ecosystem repo.
- Temporary documents (drafts, plans, reports) go in `.work/<n>/`, which git ignores.
  `make archive` and `make reject` delete it.
- If the spec has to change during the implementation, say so before going on. Then update
  the issue body (`scripts/host.sh issue-set-body`) and explain the change in a comment
  (`scripts/host.sh issue-comment`).
- Each affected repo gets its own PR, with the issue title in its title and the link to the
  issue in its description.
- OpenSpec and Superpowers are optional methods (`METHOD` in `local.mk`): they help to think,
  write and build, but the result goes on the issue. Do not use `/opsx:propose` or
  `/opsx:archive`.

## Abandoning a change

- Run `make reject I=<n> REASON="<reason>"`: it closes the open PRs with the reason, posts it
  on the issue, closes the issue as not planned and removes worktrees, branches and
  `.work/<n>/`. Anyone who wants to keep the work saves it first.
- If a PR is already merged, `make reject` does nothing: first open a PR in that repo that
  reverts it, following the spec's *Rollback*.

## TDD and verification (always)

- Before implementing any behaviour, write a failing test and check that it fails for the
  right reason. Then the minimal implementation that makes it pass. Then refactor.
- Do not write production code without a test that justifies it.
- Do not mark a task as done without running the tests, lint and build of the affected
  repo. If something fails, fix it or say so; never hide it or disable a test.
- Commit each change in the repo it belongs to. Never mix several repos in one commit.

## Bugs

- Do not propose any fix before finding the root cause. Reproduce the bug, form a
  hypothesis and check it before touching code. If a fix does not work, investigate
  again: do not chain blind fixes.
- First write a test that reproduces the bug and watch it fail.
- Its issue is labelled `bug` (`make propose TYPE=bug`) and its branch is `fix/<n>-<slug>`.
  If the issue already exists without the template, complete its body with it before
  `make apply`.

## Reviewing someone else's PR

- Do not modify their branch and do not post comments on their PR: report your findings
  to the person who asked for the review.
- Never approve or merge a PR.

## Git

- Never push to the main branch: everything goes through a PR.
- Branches always start from an up-to-date main branch.
- Do not force-push branches that have an open PR under review.
