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
- **Review:** the conclusion of `.work/<n>/review.md`, if it exists. Compare the commits it
  says it reviewed with the last commit of each merged PR (with the git host CLI): if the PR
  has later commits, say so in the summary and tell the person. If there was no review, say so
  too.
- **Documentation:** what changed in `docs/` (see below), or "No changes".
- **Pending:** the points of `.work/<n>/pending.md` marked as a separate issue, with its number
  if it already exists, or with the idea to pass to `make propose` to create it. The script
  deletes `.work/` on closing: what is not here is lost. If there are none, leave the section
  out.

Show it to the person and wait until they approve it before finishing. Without that file, the
script does not close the issue. If you got these instructions as the output of
`./bootstrap.sh archive` in your own session, once the person approves the summary run
`./bootstrap.sh archive <n>` again: with the summary written, it publishes it and closes the
issue.

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

Add to the glossary the new terms that the spec's *Context* names, with the meaning they have
in what was merged. If nothing needs to change, say so in the summary.

## What the agent struggled with

Look for where the agent got it wrong or got stuck (a command that did not exist, a rule it did
not know, a failure only the review saw): in `.work/<n>/` (above all `review.md`), in the PR
comments and, if the issue was built in this session, in the conversation. For each case,
propose to the person how to avoid it next time: if the mistake is mechanical, a check that
catches it (a test, a lint rule, `./bootstrap.sh doctor`); if it is one of judgement, a line in
`docs/review/<repo>.md` or in the `AGENTS.md` it belongs to. What they accept goes in a PR of
the repo that file lives in: the documentation PR above for the ecosystem's files. If there is
nothing, say nothing.

## If the issue is a bug

Check its labels with `scripts/host.sh issue-get <n> labels`. If it is a bug, ask yourself
whether it could have been seen in the diff that introduced it: a concrete pattern in a
concrete file. If so, propose to the person a new item for `docs/reliability-checklist.md`,
in that file's format. If they accept it, it goes in the same documentation PR as above. If it
could not be seen in a diff (it depended on data or on production), propose nothing and say so
in the summary.
