# Workflow: new features

**OpenSpec defines what gets built and why; the rules in `AGENTS.md` define how.** Every
change has a single proposal, published in a PR before any code is written and merged once
the change is built, and every task starts with a failing test.

Conventions in this guide:

- The agent is always started from the ecosystem root.
- `/opsx:*` commands and prompts go in the agent's chat; `git`, `gh`/`glab` and
  `./bootstrap.sh` go in the terminal. Depending on the agent, `/opsx:propose` may be spelled
  `/opsx-propose` (Cursor, Copilot) or `$openspec-propose` (Codex).
- Commands are shown for GitHub (`gh`) and GitLab (`glab`). Use the one for your host.
- `<main>` is your main branch; `<id>` is the change id, e.g. `add-dark-mode`.
- Prompts are starting points: adapt them to each change.

## Contents

1. [Phase 1 · Define what gets built](#phase-1--define-what-gets-built)
2. [Phase 2 · Build it right](#phase-2--build-it-right)
3. [Phase 3 · Close](#phase-3--close)
4. [Abandoning a change](#abandoning-a-change)
5. [Summary](#summary)

## Phase 1 · Define what gets built

The phase ends with the proposal's PR open in the ecosystem repo. Nothing is implemented
without it.

### Step 1 · Explore the idea (optional)

If the feature is still fuzzy, use `/opsx:explore`. It reads the code, compares options and
helps you pin the idea down without creating any artefact.

```text
/opsx:explore <description of the feature>

Ask me whatever you need, one question at a time, until the scope is clear.
When done, summarise the conclusions in the chat so I can use them in /opsx:propose.
```

### Step 2 · Create the proposal

```text
/opsx:propose <id>

Context: <conclusions from step 1, or a description of the feature>.
Acceptance criteria: <list>.
Out of scope: <list>.
List the ecosystem repos it affects. If it touches contracts between services
(queues, channels, internal endpoints, shared tables), check docs/system-map.md
and describe them in the proposal.
In tasks.md, tag each task with its repo, e.g. "- [ ] 1.1 (api) ...", and say
which test it starts with.
Be concise: the proposal must be reviewable in 10 minutes.
```

OpenSpec writes the proposal, the spec changes, the design (if needed) and `tasks.md` in
`openspec/changes/<id>/`. Read it before anyone else and cut what is not needed: agents
tend to over-write. To fix it after reviewing: `/opsx:update <id> — <what to change>`.

If the change creates, modifies or removes a contract between services, update
`docs/system-map.md` now, alongside the proposal: this is when it is decided, and the
reviewer sees the impact before any code exists.

### Step 3 · Open the proposal's PR

The proposal lives on the branch `spec/<id>` and its PR stays open for the whole
implementation: it is merged **at the end**, once every code PR is merged, and it carries the
archive too. One ecosystem PR per change, so the main branch only gets what was built.
Opening it is what lets the change start: step 4 refuses to create the branches before that,
and anyone can check it with `./bootstrap.sh check-spec <id>`.

Reviewers can comment at any time. **The accepted risk** is that code reaches the main
branch before anyone has reviewed the spec: if the reviewer disagrees at the end with
something already merged, it is fixed with new PRs or reverted. If the change needs
agreement before it is built (it touches a sensitive area or a contract between services),
ask for the review now, before step 4, even though the PR is only merged at the end.

**The PR description is the review.** OpenSpec writes several files, and not all of them are
for people. When `/opsx:propose` finishes, the agent offers to open the PR and writes its
description from `templates/proposal-pr.md`: a five-minute summary in plain language with the
behaviour changes, scope, impact on other services, risks and the decisions the reviewer
must confirm. The agent keeps it up to date during the implementation: changes to the
proposal and the code PRs. It also tells the reviewer what to read and what to skip:

| File | For whom | Review it? |
| --- | --- | --- |
| PR description | The reviewer | **Yes, start here** |
| `proposal.md` | The reviewer | **Yes** |
| `specs/` | The reviewer, for the exact expected behaviour | **Yes**, the scenarios |
| `design.md` | The technical reviewer, when there is one | Optional |
| `tasks.md` | The agent: its work plan | No (collapsed in the diff) |
| `.openspec.yaml` | OpenSpec: metadata | No (collapsed in the diff) |

`tasks.md` and `.openspec.yaml` are marked in `.gitattributes`, so GitHub and GitLab show
them collapsed in the diff.

If the reviewer asks for changes, update the proposal and push again to `spec/<id>`; the
agent can also rewrite the PR description so it stays in sync:

```text
/opsx:update <id> — <the reviewer's comments>

Then update the description of the proposal's PR so it matches the new proposal.
```

If you prefer to open the PR by hand, ask the agent for the description first:

```text
Fill in templates/proposal-pr.md for openspec/changes/<id>/ and save it as /tmp/pr-<id>.md.
```

```bash
git switch <main> && git pull --ff-only
git switch -c spec/<id>
git add openspec/changes/<id> docs/system-map.md
git commit -m "spec: proposal <id>"
git push -u origin spec/<id>
gh pr create --base <main> --title "spec: <id>" --body-file /tmp/pr-<id>.md
# GitLab: glab mr create --target-branch <main> --title "spec: <id>" --description "$(cat /tmp/pr-<id>.md)"
```

## Phase 2 · Build it right

The phase turns the published tasks into tested code, without leaving the proposal's scope.

### Step 4 · Create the branches

Create `feature/<id>` in every affected repo. The script checks that the proposal is
published (`spec/<id>` exists on the remote) and takes the repos from the `(repo)` tags of the
`tasks.md` on that branch, so nobody has to list them by hand. It starts each branch from
the latest main branch on the remote, even if the repo is on another branch.

```bash
./bootstrap.sh branch <id>
#    repos of the change: api web
# -> api: created feature/<id> from main
# -> web: created feature/<id> from main
./bootstrap.sh status
```

Before the proposal's PR is open it creates nothing:

```text
!! <id>: not published. Push spec/<id> with openspec/changes/<id>/ and open its PR (spec: <id>) before implementing.
```

If a task added later touches a repo that was not in the proposal, add it to `tasks.md` with
its `(repo)` tag, push `spec/<id>` and run `./bootstrap.sh branch <id>` again: it creates the
branch in that repo and only switches to it in the others.

### Step 5 · Refine the plan

The plan is the published `tasks.md`. Before implementing, ask the agent to make it concrete.
If it proposes touching anything outside the proposal's scope, cut it here.

```text
Read openspec/changes/<id>/ (proposal.md, specs and tasks.md).
For each task, give the repo, the files affected and the test you will write first.
Do not implement anything yet or add anything outside the scope.
```

### Step 6 · Implement with TDD

```text
/opsx:apply <id>

Follow the TDD rules in AGENTS.md: first a failing test, check that it fails for the
right reason, then the minimal implementation and the refactor.
Commit each change in the repo the task belongs to, on branch feature/<id>.
Never mix several repos in one commit.
Tick each task in tasks.md when it is done, and commit and push the progress on the
ecosystem branch spec/<id>.
If you find that the expected behaviour must change, stop and tell me.
```

For more control, ask it to implement a single task and stop so you can review it before
the next one.

**Everything that changes in the proposal goes on `spec/<id>`,** committed and pushed,
without opening new PRs: the ticks in `tasks.md` and any change to the proposal.

```bash
git switch spec/<id> && git pull --ff-only
git add openspec/changes/<id>
git commit -m "spec: progress <id>"
git push
```

**A behaviour change is noted for the reviewer.** If the expected behaviour changes along the
way, stop the affected part and update the proposal first:
`/opsx:update <id> — <what changed and why>`. Then add a line to the "Changes during
implementation" section of the proposal's PR description, so whoever reviews it at the end
sees what changed from what was proposed. If the change touches a sensitive area or a
contract, ask for its review before continuing.

### Step 7 · Verify

```text
/opsx:verify <id>

Also run the tests, lint and build of every affected repo and check the proposal's
acceptance criteria one by one. Say which pass, which do not, and which need manual testing.
```

`/opsx:verify` is part of OpenSpec's extended profile (see `SETUP.md`). Check the result
against the acceptance criteria, not just green tests, and try the feature for real.

## Phase 3 · Close

The phase merges the code of each repo through its own PR and, once all are merged,
archives the spec in the ecosystem repo.

### Step 8 · Agent review, then human review

```text
Review the diff of branch feature/<id> in every affected repo against
openspec/changes/<id>/, including the contracts between services.
Rank the problems by severity (blocking, important, minor). Do not fix anything yet.
```

Fix what matters, then open one PR per affected repo, all with `<id>` in the title and a
link to the proposal's PR, so the reviewer sees the whole change. Add each one to the "Code
PRs" section of the proposal's PR description:

```bash
cd <repo>
git push -u origin feature/<id>
gh pr create --base <main> --title "<id>: <summary>" --body "Proposal: <link to the ecosystem PR>"
# GitLab: glab mr create --target-branch <main> --title "<id>: <summary>" --description "Proposal: <link>"
cd ..
```

### Step 9 · Archive the spec

When the last code PR of the change is merged, archive the spec on `spec/<id>`. Until then,
the proposal stays in `openspec/changes/` on that branch and everyone can see the change is
in progress. `/opsx:archive` also checks that `docs/system-map.md` still matches the
contracts the change touched (see `operations.archive` in `openspec/config.yaml`); if it
updates it, it says so, so the reviewer looks at it in the same PR.

```bash
git switch spec/<id>
git pull --ff-only && git merge origin/<main>
# tick the last tasks and run /opsx:archive <id> in the agent's chat
git add openspec/ docs/system-map.md
git commit -m "spec: archive <id>"
git push
```

### Step 10 · Review, merge and clean up

A person reviews the proposal's PR, now with the final proposal, the changes made during the
implementation and the archive, and merges it. Then clean up locally:

```bash
git -C <repo> switch <main>
git -C <repo> branch -d feature/<id>
git switch <main>
git branch -d spec/<id>
./bootstrap.sh          # brings every main branch up to date
```

## Abandoning a change

If the team drops a change, its proposal never reaches the main branch. Do not use
`/opsx:archive`: it would merge into `openspec/specs/` behaviour that was never built.

| # | Step | Command |
| --- | --- | --- |
| 1 | Close the proposal's PR without merging, with the reason in a comment | Git host |
| 2 | Close the change's open code PRs without merging; revert the ones already merged, following the proposal's rollback plan | Git host |
| 3 | Once the PRs are closed, delete `spec/<id>` and `feature/<id>`, locally and on the remote | `git push origin --delete <branch>` |

The revert PRs need no new proposal: they go back to the behaviour already in
`openspec/specs/`. Anyone who wants to keep the abandoned work saves it locally before the
branches are deleted.

## Summary

The two human reviews, the code PRs (step 8) and the proposal's PR (step 10), are what make
the workflow robust. If something gets skipped in a rush, let it be the detailed plan
review, never the proposal's PR.

| Phase | Tool | Where | Result | Human review |
| --- | --- | --- | --- | --- |
| Explore | `/opsx:explore` | Chat | Conclusions for the proposal | No |
| Proposal | `/opsx:propose` | Ecosystem repo, PR on `spec/<id>` open until the end | Proposal, specs, tasks with their tests, updated map | Before building only for sensitive areas or contracts |
| Branches | `bootstrap.sh branch <id>` | Affected repos | Same branch everywhere, only if the proposal's PR is open | No |
| Plan | `tasks.md` refined by the agent | Chat | Files and first test per task | Quick |
| Implementation | `/opsx:apply` + TDD rules | Affected repos | Tested code; progress and proposal changes on `spec/<id>` | No (noted in the proposal's PR) |
| Verification and review | `/opsx:verify` + team | Affected repos | One PR per repo, linked to the proposal | **Yes** |
| Archive | `/opsx:archive` | Ecosystem repo, on `spec/<id>` | Specs archived, system map checked | — |
| Proposal review | Team | Ecosystem repo | Proposal's PR merged: specs on the main branch | **Yes, mandatory** |
