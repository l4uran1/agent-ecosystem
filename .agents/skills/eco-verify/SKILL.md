---
name: eco-verify
description: Review the spec of an issue before it is built, in a clean session, and present the findings (verify step of the workflow).
argument-hint: "<n>"
disable-model-invocation: true
---

# Review the spec of an issue

Arguments: $ARGUMENTS

If the line above is empty or was not substituted (Codex does not), take the arguments from the person's message and, if one is missing, ask for it.

Run the commands from the ecosystem root (its main folder, on its main branch), not from a worktree.

Run `AGENT_SESSION=headless ./bootstrap.sh verify <n>`. It can take more than 10 minutes: run it in the background if your tool allows it (in Claude Code, Bash with `run_in_background`) and tell the person it is running. It opens a separate session, without a UI and without access to this conversation, so that the judgement comes from someone who did not write what it reviews.

When it finishes, what it prints at the end are the instructions for this session: follow them.
