# Verifying a change by running it

One file per repo, `docs/verify/<repo>.md`, with the folder name of `repos.txt`. `make apply`
and `make review` follow it to run the code of a branch and check that it does what the spec
says: passing tests is not enough.

Write down what an agent cannot guess from the repo's `AGENTS.md`:

- How to run a worktree's code instead of the main checkout's (e.g. a container that mounts the
  main checkout and has to mount the worktree instead).
- What to do when the branch changes the database schema or the data, without losing the
  development data.
- How to go through what the user or the calling service does: a request, the screen in the
  browser, a message on a queue. Which test users or fixtures to use.
- Which evidence to keep for the PR description: command output, a response, log lines, a
  screenshot.
- How to put the environment back as it was when done.

A repo without a file is verified following its `AGENTS.md`.
