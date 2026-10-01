# Workflow: new features

**OpenSpec defines what gets built and why; the rules in `AGENTS.md` define how.** Every
change has a single proposal, reviewed before any code is written, and every task starts
with a failing test.

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
4. [Summary](#summary)

## Phase 1 · Define what gets built

The phase ends with a proposal approved by someone on the team. Nothing is implemented
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
In tasks.md, say which repo each task is done in and which test it starts with.
Be concise: the proposal must be reviewable in 10 minutes.
```

OpenSpec writes the proposal, the spec changes, the design (if needed) and `tasks.md` in
`openspec/changes/<id>/`. Read it before anyone else and cut what is not needed: agents
tend to over-write. To fix it after reviewing: `/opsx:update <id> — <what to change>`.

If the change creates, modifies or removes a contract between services, update
`docs/system-map.md` now, alongside the proposal: this is when it is decided, and the
reviewer sees the impact before any code exists.

### Step 3 · Team review (mandatory checkpoint)

Someone who knows that part of the product reviews and merges the proposal's PR. Reviewing
two pages of spec is much cheaper than reviewing a thousand lines of wrong code. The agent
will not implement until the proposal is on the main branch.

**The PR description is the review.** OpenSpec writes several files, and not all of them are
for people. When `/opsx:propose` finishes, the agent offers to open the PR and writes its
description from `templates/proposal-pr.md`: a five-minute summary in plain language with the
behaviour changes, scope, impact on other services, risks and the decisions the reviewer
must confirm. It also tells the reviewer what to read and what to skip:

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

If the reviewer asks for changes, update the proposal and push again; the agent can also
rewrite the PR description so it stays in sync:

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

The phase turns the approved tasks into tested code, without leaving the proposal's scope.

### Step 4 · Create the branches

Create the same branch in every affected repo. The script starts it from the latest main
branch on the remote, even if the repo is on another branch.

```bash
./bootstrap.sh branch feature/<id> <repo> <repo>...
./bootstrap.sh status
```

### Step 5 · Refine the plan

The plan is the approved `tasks.md`. Before implementing, ask the agent to make it concrete.
If it proposes touching anything outside the approved scope, cut it here.

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
Tick each task in tasks.md when it is done.
If you find that the expected behaviour must change, stop and tell me.
```

For more control, ask it to implement a single task and stop so you can review it before
the next one. If the expected behaviour changes along the way, update the proposal first:
`/opsx:update <id> — <what changed and why>`.

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
link to the proposal's PR, so the reviewer sees the whole change:

```bash
cd <repo>
git push -u origin feature/<id>
gh pr create --base <main> --title "<id>: <summary>" --body "Proposal: <link to the ecosystem PR>"
# GitLab: glab mr create --target-branch <main> --title "<id>: <summary>" --description "Proposal: <link>"
cd ..
```

### Step 9 · Archive the spec

When the last code PR of the change is merged, archive the spec in the ecosystem repo with a
small PR. Until then, the proposal stays in `openspec/changes/` and everyone can see the
change is in progress.

```bash
git switch <main> && git pull --ff-only
git switch -c spec/archive-<id>
# run /opsx:archive <id> in the agent's chat
git add openspec/
git commit -m "spec: archive <id>"
git push -u origin spec/archive-<id>
gh pr create --base <main> --title "spec: archive <id>"
```

### Step 10 · Merge and clean up

Merge each PR from your git host once CI is green. Then clean up locally:

```bash
git -C <repo> switch <main>
git -C <repo> branch -d feature/<id>
./bootstrap.sh          # brings every main branch up to date
```

## Summary

The two human reviews (steps 3 and 8) are what make the workflow robust. If something gets
skipped in a rush, let it be the detailed plan review, never the proposal.

| Phase | Tool | Where | Result | Human review |
| --- | --- | --- | --- | --- |
| Explore | `/opsx:explore` | Chat | Conclusions for the proposal | No |
| Proposal | `/opsx:propose` | Ecosystem repo | Proposal, specs, tasks with their tests, updated map | **Yes, mandatory** |
| Branches | `bootstrap.sh branch` | Affected repos | Same branch everywhere | No |
| Plan | `tasks.md` refined by the agent | Chat | Files and first test per task | Quick |
| Implementation | `/opsx:apply` + TDD rules | Affected repos | Tested code | No |
| Verification and review | `/opsx:verify` + team | Affected repos | One PR per repo, linked to the proposal | **Yes** |
| Archive | `/opsx:archive` | Ecosystem repo | Specs updated on the main branch | Small ecosystem PR |
