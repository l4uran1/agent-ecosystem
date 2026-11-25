---
name: eco-reject
description: Drop an issue: close its PRs with the reason, close the issue and clean up (workflow).
argument-hint: "<n> <reason>"
disable-model-invocation: true
---

# Drop an issue

Arguments: $ARGUMENTS

If the line above is empty or was not substituted (Codex does not), take the arguments from the person's message and, if one is missing, ask for it.

Run the commands from the ecosystem root (its main folder, on its main branch), not from a worktree.

Run `./bootstrap.sh reject <n> "<reason>"` and tell the person what it did. If a PR is already merged it does nothing: explain to the person that it must be reverted first with another PR, following the spec's *Rollback*.
