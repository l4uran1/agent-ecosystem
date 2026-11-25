---
name: eco-apply
description: Build an issue: branches and worktrees, TDD and one PR per repo (apply step of the workflow).
argument-hint: "<n>"
disable-model-invocation: true
---

# Build an issue

Arguments: $ARGUMENTS

If the line above is empty or was not substituted (Codex does not), take the arguments from the person's message and, if one is missing, ask for it.

Run the commands from the ecosystem root (its main folder, on its main branch), not from a worktree.

Run `./bootstrap.sh apply <n>`. What it prints are the instructions of the step: follow them in this same session.
