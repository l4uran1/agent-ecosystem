# Product context

What an agent (or a new person) needs to know about the product and **cannot work out by
reading the code**. Every file is short on purpose: if it can be read in the code, it does
not belong here.

| File | What it holds | When to read it |
| --- | --- | --- |
| `sensitive-areas.md` | Parts of the product where a mistake directly hurts customers, and known risks | Before proposing or touching any change in those areas |
| `constraints.md` | External limits: platforms, third-party APIs, regulation | Changes that touch those platforms, APIs or data |
| `glossary.md` | Domain terms and what they mean here | When a term in a task or in the code is unclear |
| `decisions/` | Architecture and process decisions, with their reasons | Before proposing something that contradicts how things are done today |

## How it is maintained

- Changed through PRs to the ecosystem repo, like everything else.
- Confirmed facts only. Anything unknown is marked `TODO:` with the question, and resolved
  quickly: an agent should never make decisions based on a gap.
- If a code change alters something described here, update the file in the same
  ecosystem PR as its proposal.
- Keep this folder private. Known risks describe exactly where your system is fragile.
