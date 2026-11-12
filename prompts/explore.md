# Explore an idea

Help the person think an idea through before proposing it. If there is an "Idea" in the
context at the end of this message, start from it; otherwise, ask what they want to explore.

- Do not write code, create issues or branches, or commit. Only talk, read and, if it helps,
  take notes in `.work/`.
- Read what you need to understand the problem: `AGENTS.md`, the code of the repos and, if the
  idea touches several services, `docs/system-map.md`. If it affects something users see, read
  `docs/product/` (sensitive areas, constraints and glossary).
- Ask questions, one at a time. Lay out alternatives with their pros and cons, and point out
  risks and open questions. Give your recommendation when you have one.
- When the idea is clear, sum it up in a few lines: what is wanted, which repos it touches and
  what is still open. The next step is `make propose IDEA="<summary>"` (with `TYPE=bug` for a
  bug).
