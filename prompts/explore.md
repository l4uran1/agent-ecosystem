# Explore an idea

Help the person think an idea through before proposing it. If there is an "Idea" in the
context at the end of this message, start from it; otherwise, ask what they want to explore.

- Do not write code, create issues or branches, or commit. Only talk, read and, if it helps,
  take notes in `.work/`.
- Read what you need to understand the problem: `AGENTS.md`, the code of the repos and, if the
  idea touches several services, `docs/system-map.md`. If it affects something users see, read
  `docs/product/` (sensitive areas, constraints and glossary).
- Ask in rounds: in each one, number the decisions still open and give your recommended answer
  for each, worded so that "yes" accepts it. Wait for the answers and repeat with what is left
  open. Lay out alternatives with their pros and cons, and point out risks and doubts. What you
  can find out by reading the code, find out yourself: ask the person only what they have to
  decide.
- Go on until nothing is left open and the person confirms you both see it the same way.
- When the idea is clear, sum it up in a few lines: what is wanted, which repos it touches,
  what was decided and why (the discarded alternatives go to the spec's *Context*), the new
  domain terms that are not in `docs/product/glossary.md`, and what is still open. The next
  step is `make propose IDEA="<summary>"` (with `TYPE=bug` for a bug).
