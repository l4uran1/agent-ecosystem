---
name: eco-propose
description: Write the spec of a change with the person and create its issue (propose step of the workflow).
argument-hint: "<feature|bug> [idea]"
disable-model-invocation: true
---

# Propose a change

Arguments: $ARGUMENTS

If the line above is empty or was not substituted (Codex does not), take the arguments from the person's message and, if one is missing, ask for it.

Run the commands from the ecosystem root (its main folder, on its main branch), not from a worktree.

Run `./bootstrap.sh propose <feature|bug> "<idea>"`. What it prints are the instructions of the step: follow them in this same session.
