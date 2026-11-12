# Close an issue that has been built

Every PR of the issue at the end of this message is merged. Your job is to write the final
summary and to check that the shared documentation is still right. When you finish, the script
publishes the summary on the issue, closes it and removes branches, worktrees and temporary
files: do not do it yourself.

## The final summary

Write it at the "Summary" path (see "Context" at the end), in Markdown. It is what stays on the
issue for whoever reads it in a year:

- **What was built**, in plain language.
- **Differences from the spec**, and why. Read the issue comments and the PRs. If there are
  none, say so.
- **Merged PRs**, with their links (`scripts/host.sh pr-list <repo> <branch>` in each repo).
- **Review:** the conclusion of `.work/<n>/review.md`, if it exists.
- **Documentation:** what changed in `docs/` (see below), or "No changes".

Show it to the person and wait until they approve it before finishing. Without that file, the
script does not close the issue.

## The shared documentation

Compare what changed (the code already merged on the main branch of each repo) with
`docs/system-map.md`, `docs/product/sensitive-areas.md`, `docs/product/constraints.md` and
`docs/product/glossary.md`. If something is out of date:

1. Create a worktree of the ecosystem repo from its up-to-date main branch:
   `git fetch origin && git worktree add .worktrees/docs/<n> -b docs/<n> origin/HEAD`.
2. Make the changes there, commit and push.
3. Open the PR with the git host CLI. In its description: what changed and the link to the
   issue. Then remove the worktree: `git worktree remove .worktrees/docs/<n>`.
4. Never approve or merge it: a person reviews it.

If nothing needs to change, say so in the summary.
