# Build the issue

Build the change of the issue at the end of this message. Its body is the spec, and its
acceptance criteria say when it is done.

## Before starting

- Read the `AGENTS.md` at the root and the one of each affected repo.
- This session starts at the ecosystem root, so it does not see the repos' own agent skills or
  rules: look for them in the worktree of each affected repo (the paths are in "Context"), not
  in its main checkout, which may be on another branch, and read the ones that fit what you are
  going to touch. Before writing code, also read the coding standard that the repo's
  `AGENTS.md` links to, if any: lint and pre-commit hooks do not check everything.
- The branches and worktrees already exist (see "Context" at the end). Work only inside them,
  never in the main checkout of a repo.
- If something in the spec is unclear or cannot be done as written, ask before implementing.
- The spec in this message is the current one: it overrides whatever was said earlier in this
  session (`make verify` may have changed it). If it differs from what you remember, say what
  changed before starting.

## How to build it

- Follow the TDD and verification rules of `AGENTS.md`.
- Write the tests that *How it's verified* asks for, of the kind it says.
- Commit each change in the repo it belongs to.
- Temporary documents (notes, plans, drafts) go in `.work/<n>/`, never in a repo.

## If the spec has to change

Tell the person and wait until they agree. Then:

1. Write the whole spec in `.work/<n>/spec.md`, following `templates/spec.md`.
2. Upload it with `scripts/host.sh issue-set-body <n> .work/<n>/spec.md`.
3. Explain the change and why in a comment: write it in `.work/<n>/change.md` and post it with
   `scripts/host.sh issue-comment <n> .work/<n>/change.md`.

## What is left out

What you find that does not belong to this issue (an edge case you do not cover, a risk you do
not mitigate, an improvement for another issue), do not do it, but write it down in
`.work/<n>/pending.md`: one line per point, with what it is, why it matters and where it is.
That way it is not lost in the conversation.

A product decision the change depends on is not written down: ask it right then, because
without it the code guesses.

## Before opening the PRs

Run the change for real, not only its tests: start whatever it needs and go through what the
user, or the service that calls it, does.

- If `docs/verify/<repo>.md` exists in the ecosystem repo, follow it.
- Otherwise, follow the repo's `AGENTS.md` to start it and check the change by hand (a call to
  the endpoint, the screen in the browser, the message on the queue).
- If it cannot run locally, say so in the PR and explain why.
 Keep the evidence (the
output, a trace, a screenshot) for the PR description.

Go through `.work/<n>/pending.md` with the person, if it exists, and ask once for each point
what to do with it:

- **In this issue:** it widens the spec, so follow "If the spec has to change".
- **Separate issue:** it stays in `pending.md`, marked as such, to be created later with
  `make propose`.
- **Discarded:** it stays marked as such, with the reason.

## When it is done

- Push the branch and open one PR per repo with the git host CLI in `AGENTS.md`
  (`gh pr create` or `glab mr create`), from its worktree. Title: the issue title, plus
  whatever the repo's `AGENTS.md` asks for. Description: what changes; how it was verified
  (each test of *How it's verified* and the evidence of running it); the risk of merging it
  (whether reverting the PR undoes it or not, because of a migration or a contract, and what it
  affects); what is left for a separate issue, if anything; and the link to the issue
  (`scripts/host.sh issue-get <n> url`).
- Never approve or merge a PR.
- Tell the person what was done and which PRs were opened. The next step is
  `make review I=<n>`. Once it finishes, if the person wants, fix here what it found: the
  report is in `.work/<n>/review.md`. The review holds for the commits it reviewed: if you add
  more afterwards, tell the person so they can run it again.
- If the checks fail, there are conflicts or reviewers comment on the PRs, the step is
  `make respond I=<n>`, in this session or another one.
