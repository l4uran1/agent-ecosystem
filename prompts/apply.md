# Build the issue

Build the change of the issue at the end of this message. Its body is the spec, and its
acceptance criteria say when it is done.

## Before starting

- Read the `AGENTS.md` at the root and the one of each affected repo.
- The branches and worktrees already exist (see "Context" at the end). Work only inside them,
  never in the main checkout of a repo.
- If something in the spec is unclear or cannot be done as written, ask before implementing.

## How to build it

- Follow the TDD and verification rules of `AGENTS.md`.
- Commit each change in the repo it belongs to.
- Temporary documents (notes, plans, drafts) go in `.work/<n>/`, never in a repo.

## If the spec has to change

Tell the person and wait until they agree. Then:

1. Write the whole spec in `.work/<n>/spec.md`, following `templates/spec.md`.
2. Upload it with `scripts/host.sh issue-set-body <n> .work/<n>/spec.md`.
3. Explain the change and why in a comment: write it in `.work/<n>/change.md` and post it with
   `scripts/host.sh issue-comment <n> .work/<n>/change.md`.

## When it is done

- Push the branch and open one PR per repo with the git host CLI in `AGENTS.md`
  (`gh pr create` or `glab mr create`), from its worktree. Title: the issue title, plus
  whatever the repo's `AGENTS.md` asks for. Description: what changes, how it was tested and
  the link to the issue (`scripts/host.sh issue-get <n> url`).
- Never approve or merge a PR.
- Tell the person what was done and which PRs were opened. The next step is
  `make review I=<n>`.
