---
name: eco-explore
description: Explore an idea before proposing it, without code or issues (explore step of the workflow).
argument-hint: "[idea]"
disable-model-invocation: true
---

# Explore an idea

Arguments: $ARGUMENTS

If the line above is empty or was not substituted (Codex does not), take the arguments from the person's message and, if one is missing, ask for it.

Run the commands from the ecosystem root (its main folder, on its main branch), not from a worktree.

Run `./bootstrap.sh explore "<idea>"` (without the idea if there is none). What it prints are the instructions of the step: follow them in this same session.
