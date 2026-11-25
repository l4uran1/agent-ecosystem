# Deal with the open PRs of an issue

The PRs of the issue at the end of this message are open, and something keeps them from being
merged: failing checks, conflicts with the main branch, or reviewers' comments. Your job is to
leave them ready for a person to merge. The PRs and their worktrees are in "Context", at the
end.

Follow the rules of `AGENTS.md`, as in `make apply`: TDD, tests, lint and build, and each
commit in the repo it belongs to. Before writing code, read the repo's skills and coding
standard as "Before starting" in `prompts/apply.md` says.

## What is wrong with each PR

From the worktree of its repo (the git host CLI finds the project from the folder), with the
CLI that `AGENTS.md` names:

| | GitHub (`gh`) | GitLab (`glab`) |
|---|---|---|
| Checks and conflicts | `gh pr view <n> --json statusCheckRollup,mergeable,mergeStateStatus` | `glab mr view <n> -F json`: `head_pipeline.status`, `has_conflicts`, `detailed_merge_status` |
| Failing job and its log | `gh pr checks <n>`, then `gh run view <run id> --log-failed` | `glab ci status --branch <branch>`, then `glab ci trace <job>` |
| Unresolved threads | `gh api graphql -F owner='{owner}' -F repo='{repo}' -F n=<n> -f query='query($owner:String!,$repo:String!,$n:Int!){repository(owner:$owner,name:$repo){pullRequest(number:$n){reviewThreads(first:100){nodes{id isResolved path line comments(first:50){nodes{author{login} body}}}}}}}'`, the ones with `isResolved` false | `glab api "projects/:id/merge_requests/<n>/discussions?per_page=100"`, the ones whose `.notes[0].resolvable` is true and `.notes[0].resolved` is not |
| Comments outside threads | `gh pr view <n> --comments` | the discussions above that are not resolvable |

Read each thread whole, not only its first comment. Deal first with what keeps the PR from
being merged: reviewers wait until it is green.

## Failing checks, conflicts or an out-of-date branch

- **Failing checks:** find the failing job and read its log. Look for the root cause as with a
  bug: do not rerun the job until you know why it failed. If the test is flaky, apply the rule
  for flaky tests in `AGENTS.md`. If the failure has nothing to do with this change (it also
  fails on the main branch), tell the person instead of fixing it here.
- **Conflicts or an out-of-date branch:** bring in the remote main branch with `git merge`, not
  a rebase. The PR is under review, and its branch is not force-pushed.

## Reviewers' comments

Sort each unresolved thread and show the list to the person before touching code or replying:

- **Agreed change:** the reviewer is right, and it is fixed in this PR.
- **Question:** a reply is enough.
- **Disagreement:** you think it should not change. Give the reason with the code or the spec,
  not with opinions.
- **Out of scope:** reasonable, but not part of this issue. It goes to `.work/<n>/pending.md`,
  as in `make apply`.

The person decides. If a change they accept contradicts the spec, follow "If the spec has to
change" in `prompts/apply.md` before building it.

Build the accepted changes with a test that fails first. Then commit and `git push`, without
forcing.

## The replies

Write in `.work/<n>/replies.md` one reply per thread: what was done and in which commit, or why
it does not change. Show them to the person and, only with their approval, post each one in
its thread:

| GitHub (`gh`) | GitLab (`glab`) |
|---|---|
| `gh api graphql -f query='mutation($id:ID!,$body:String!){addPullRequestReviewThreadReply(input:{pullRequestReviewThreadId:$id,body:$body}){comment{url}}}' -f id=<thread id> -F body=@<file>` | `glab api --method POST "projects/:id/merge_requests/<n>/discussions/<thread id>/notes" --raw-field "body=<reply>"` |

- Do not resolve the threads: whoever opened them resolves them, once the reply convinces them.
- Never approve or merge a PR.

## When it is done

Tell the person the state of each PR, what you changed and which threads are still open.

If you added commits after `make review`, say so: the review no longer covers them and they
can run it again (`eco-review <n>`, which opens a separate session). If more comments arrive,
run `eco-respond <n>` again. Once every PR is merged, the next step is `eco-archive <n>`.
