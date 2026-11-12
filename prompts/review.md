# Review the implementation of an issue

Review the code that implements the issue at the end of this message. You did not write it
and you do not know the conversations of whoever did: judge it only by the spec and the code.

## What to review

In each worktree (see "Context" at the end), compare the branch with the remote main branch
(`git -C <worktree> diff origin/HEAD...HEAD`). Also read the code around the changes: the diff
alone is not enough.

1. **Acceptance criteria.** For each one, say whether it is met and show where: the code and
   the test that proves it. A criterion without a test that covers it is not met.
2. **Bugs.** Logic errors, edge cases, data that can be lost or exposed, and concurrency or
   performance problems with real data.
3. **Scope.** What the change does that the spec does not ask for, and what the spec asks for
   that is missing.
4. **Rules.** Those of the root `AGENTS.md` and of each repo's: TDD, tests, lint and build.
   Run the repo's tests if you can.

Do not change code, do not commit and do not comment on the PRs: the report is for the person.

## The report

Write it at the "Report" path (see "Context" at the end):

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

Tell the person the conclusion and the most serious problems. Once every PR is merged, the
next step is `make archive I=<n>`.
