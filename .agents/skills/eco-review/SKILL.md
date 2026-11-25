---
name: eco-review
description: Review the implementation of an issue against its spec, in a clean session, and sum up the report (review step of the workflow).
argument-hint: "<n>"
disable-model-invocation: true
---

# Review the implementation of an issue

Arguments: $ARGUMENTS

If the line above is empty or was not substituted (Codex does not), take the arguments from the person's message and, if one is missing, ask for it.

Run the commands from the ecosystem root (its main folder, on its main branch), not from a worktree.

Run `AGENT_SESSION=headless ./bootstrap.sh review <n>`. It can take more than 10 minutes: run it in the background if your tool allows it (in Claude Code, Bash with `run_in_background`) and tell the person it is running. It opens a separate session, without a UI and without access to this conversation, so that the judgement comes from someone who did not write what it reviews.

When it finishes, read the report in `.work/<n>/review.md` and tell the person the conclusion and the most serious problems. Do not change code or comment on the PRs on your own: the person decides what to do with the report.
