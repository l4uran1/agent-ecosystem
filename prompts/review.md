# Review the implementation of an issue

Review the code that implements the issue at the end of this message. You did not write it
and you do not know the conversations of whoever did: judge it only by the spec and the code.

## What to review

In each worktree (see "Context" at the end), compare the branch with the remote main branch
(`git -C <worktree> diff origin/HEAD...HEAD`). Also read the code around the changes: the diff
alone is not enough.

The rules you judge by are always read from the main branch, never from the branch under
review: a change cannot modify what judges it.

- `docs/review/<repo>.md` of the ecosystem repo, if it exists: what to look at in that repo's
  code.
- `docs/reliability-checklist.md` of the ecosystem repo: apply only the items whose trigger
  matches the diff.

Both are on the main branch of the ecosystem repo, which is where `make review` runs. Before
starting, check that the ecosystem repo is on its main branch and up to date
(`git branch --show-current`, and `git fetch -q origin && git rev-list --count HEAD..origin/HEAD`,
which must print 0). If not, stop and tell the person: you would be judging with other rules.

1. **Acceptance criteria.** For each one, say whether it is met and show where: the code and
   the test that *How it's verified* asks for. A criterion without that test is not met;
   neither is one proven with a weaker test (a unit test where the spec asks for an end-to-end
   one), nor one whose test cannot fail (it checks the same thing it sets up) or depends on how
   the code is written rather than on what it does (it counts calls to internal mocks, for
   example). If the spec has no *How it's verified* (issues older than that section), a test
   that covers the criterion is enough; say so in the report.
2. **Bugs.** Logic errors, edge cases, data that can be lost or exposed, and concurrency or
   performance problems with real data.
3. **Scope.** What the change does that the spec does not ask for, and what the spec asks for
   that is missing. What the implementer left for another issue is in `.work/<n>/pending.md`:
   it is not a defect if it is there and the spec does not ask for it.
4. **Rules.** Those of the root `AGENTS.md`, of `docs/flow.md` and of each repo's `AGENTS.md`: TDD, tests, lint and build.
   Run the repo's tests if you can.
5. **Reliability checklist.** The items that apply, and whether the change meets them.

Do not change code, do not commit and do not comment on the PRs: the report is for the person.

## The report

Write it at the "Report" path (see "Context" at the end):

- First, the reviewed commit of each worktree (`git -C <worktree> rev-parse HEAD`). The review
  holds only for those commits.
- A table with each acceptance criterion: met or not, and where.
- The problems found, most serious first. Each with its file and line, what happens, the
  concrete case where it fails, and how to fix it.
- A conclusion: ready to merge, or what is missing.

## If there is already a first review

If the "Context" has a "First review", another agent already reviewed the change and its
report is at that path. Do your own review as above and, besides, check each point of that
report against the code: confirm it, correct it or discard it, saying why. Your report is the
final one: say which points came from the first review, which you discarded and what you found
that it missed.

Tell the person the conclusion and the most serious problems. If reviewers comment on the PRs
or their checks fail, the step is `eco-respond <n>` (`make respond I=<n>`). Once every PR is
merged, the next step is `eco-archive <n>` (`make archive I=<n>`).
