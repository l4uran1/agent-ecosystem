# Workflow: bug fixes

**Root cause first, fix second.** No fix is proposed before finding why it fails, and every
fix starts with a test that reproduces the bug. Fixing the symptom usually hides the problem
and creates another one.

Same conventions as the [feature workflow](feature.md): the agent starts from the ecosystem
root, `/opsx:*` and prompts go in the chat, `git`, `gh`/`glab` and `./bootstrap.sh` in the
terminal.

## Contents

1. [When does a bug need an OpenSpec proposal?](#when-does-a-bug-need-an-openspec-proposal)
2. [Phase 1 · Investigate](#phase-1--investigate)
3. [Phase 2 · Fix](#phase-2--fix)
4. [Phase 3 · Close](#phase-3--close)
5. [When the bug needs a proposal](#when-the-bug-needs-a-proposal)
6. [Summary](#summary)

## When does a bug need an OpenSpec proposal?

Most do not: fixing a bug means making the system do what it was already supposed to do.
A proposal is needed only if:

- **The fix changes the expected behaviour.** While investigating you find that nobody had
  decided what should happen in that case, or that what was decided was wrong. That is no
  longer a bug, it is a product decision.
- **It touches a sensitive area** (see `docs/product/sensitive-areas.md`).
- **It changes a contract between services:** a queue, a channel, an internal endpoint or a
  shared table.

## Phase 1 · Investigate

The phase ends with the root cause identified and a decision: direct fix or a proposal.
No code changes yet.

### Step 1 · Reproduce the bug

Gather what is expected, what happens, who it affects, since when, and the logs or errors
available. If you cannot reproduce it, stop: a fix without a reproduction is a guess.

### Step 2 · Find the root cause

Use `/opsx:explore` to investigate without creating any artefact.

```text
/opsx:explore

Bug: <what was expected and what happens>.
How to reproduce: <steps>.
Evidence: <logs, errors, affected users, since when>.

Find the root cause following the bug-fix rules in AGENTS.md.
Form hypotheses and check them in the code one by one; do not propose any fix yet.
If the bug crosses services, check docs/system-map.md.
When done, tell me:
- the root cause and the evidence that confirms it,
- which repos and files are involved,
- whether it touches a sensitive area or a contract between services,
- whether the fix would change the expected behaviour.
```

If the first hypothesis is not confirmed, investigate again. Do not chain trial fixes until
one works: that usually hides the symptom and leaves the cause.

### Step 3 · Decide the path

- **None of the three cases above:** direct fix. Go to phase 2.
- **Any of them:** go to [When the bug needs a proposal](#when-the-bug-needs-a-proposal).

When in doubt, ask someone who knows that part of the product. A five-minute conversation
saves redoing the fix.

## Phase 2 · Fix

The phase turns the root cause into a minimal fix, covered by a test that failed before and
passes now.

### Step 4 · Create the branch

A bug usually affects a single repo; if the cause crosses services, create the same branch
in all of them.

```bash
./bootstrap.sh branch fix/<short-description> <repo>
```

### Step 5 · Write the test that reproduces the bug

```text
Write a test that reproduces the bug, in the repo where the root cause is.
Run it and check that it fails, and that it fails because of the cause we identified,
not for another reason. Do not touch production code yet.
```

That test is the best documentation of the fix and stops the bug from coming back. If it can
only be reproduced end to end, use an end-to-end test; if that is not possible either,
document in the PR how to reproduce it by hand.

### Step 6 · Fix and verify

The fix must be the smallest one that addresses the root cause, with no refactors or
improvements on the side: every extra change is more to review and more that can break.

```text
Implement the minimal fix that addresses the root cause, with no changes outside its scope.
Check that the bug's test now passes, and run the repo's tests, lint and build.
If the fix does not work, do not try another one blindly: investigate the cause again.
Commit on branch fix/<short-description>.
```

Also try the real case that reported the bug.

## Phase 3 · Close

The phase gets the fix to the main branch with a review that can check the root cause, not
just the diff.

### Step 7 · Agent review and PR

```text
Review the diff of branch fix/<short-description>: check that it addresses the root cause,
that it has no changes outside its scope and that the bug's test covers it.
Rank the problems by severity (blocking, important, minor). Do not fix anything yet.
```

Open the PR with the root cause explained: the reviewer needs to understand why it failed to
judge whether the fix is right.

```bash
cd <repo>
git push -u origin fix/<short-description>
gh pr create --base <main> --title "fix: <summary>" \
  --body "Root cause: <explanation>. How to reproduce: <steps>. Test: <name>."
# GitLab: glab mr create --target-branch <main> --title "fix: <summary>" --description "..."
cd ..
```

### Step 8 · Merge and clean up

Merge from your git host once CI is green, then:

```bash
git -C <repo> switch <main>
git -C <repo> branch -d fix/<short-description>
./bootstrap.sh
```

If the bug revealed a risk nobody had documented (a fragile contract, a hidden dependency
between services), add it to `docs/product/sensitive-areas.md` or `docs/system-map.md` with a
PR to the ecosystem repo. That is how the next agent avoids the same mistake.

## When the bug needs a proposal

The fix goes through OpenSpec before any code is written. The investigation from phase 1 is
not lost: it is the basis of the proposal. Use the `fix-` prefix for the id.

```text
/opsx:propose fix-<short-description>

This is a bug fix.
Bug: <what was expected and what happens>.
Root cause: <conclusions from step 2>.
Why it needs a proposal: <changes expected behaviour / sensitive area / contract>.
Describe the correct behaviour that must remain and, if it changes what existed,
who is affected. The first task must be the test that reproduces the bug.
Be concise: the proposal must be reviewable in 10 minutes.
```

Then follow the [feature workflow](feature.md) from step 3: proposal review and merge,
branches, `/opsx:apply`, `/opsx:verify`, one PR per repo and archive. The branch keeps the
`fix/<short-description>` name.

**If the bug is in production and urgent,** do not wait for the proposal to contain the
damage. First apply the smallest mitigation that stops it (turn the feature off, revert the
change that introduced it), with its own PR and test, and leave the real fix for the
proposal workflow.

## Summary

What makes this workflow robust is the order: root cause, failing test, minimal fix. If
something gets skipped in a rush, never let it be the investigation.

| Phase | Tool | Where | Result | Human review |
| --- | --- | --- | --- | --- |
| Reproduce | Bug report and logs | Test environment | Bug reproduced | No |
| Root cause | `/opsx:explore` | Chat | Confirmed cause and chosen path | Only if in doubt |
| Branch | `bootstrap.sh branch` | Affected repos | `fix/<short-description>` | No |
| Bug test | Agent | Repo with the cause | Test failing because of the root cause | No |
| Fix and verify | Agent | Affected repos | Minimal fix; tests, lint and build green | No |
| Review and merge | Agent + team | Git host | PR with the root cause explained | **Yes** |
| Detour (if needed) | `/opsx:propose` | Ecosystem repo | `fix-` proposal approved before implementing | **Yes, mandatory** |
