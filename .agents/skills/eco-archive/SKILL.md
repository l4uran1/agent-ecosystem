---
name: eco-archive
description: Close an issue whose PRs are merged: final summary, issue closed and cleanup (archive step of the workflow).
argument-hint: "<n>"
disable-model-invocation: true
---

# Close an issue

Arguments: $ARGUMENTS

If the line above is empty or was not substituted (Codex does not), take the arguments from the person's message and, if one is missing, ask for it.

Run the commands from the ecosystem root (its main folder, on its main branch), not from a worktree.

Run `./bootstrap.sh archive <n>`. What it prints are the instructions of the step: follow them in this same session.
