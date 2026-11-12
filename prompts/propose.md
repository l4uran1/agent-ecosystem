# Propose a change

Write the spec of a change with the person and create its issue in the ecosystem repo. The
"Type" (feature or bug), the "Draft" folder and, if there is one, the "Idea" are in the context
at the end of this message. If there is no idea, ask what should change.

## Before writing

- Understand the change: read the code of the affected repos and ask about anything unclear.
- If it touches queues, pub/sub channels, internal endpoints, tables of another service or
  shared credentials, read `docs/system-map.md`.
- If it affects something users see, read `docs/product/`, especially
  `sensitive-areas.md`.
- If it is a bug, find the root cause before proposing the fix (`AGENTS.md`).
- Do not write code or create branches: that is `make apply`.

## The spec

Write it in `<Draft>/spec.md`, following `templates/spec.md`:

- *Affected repos*: one repo per line (`- api`), with its name in `repos.txt`. The workflow
  commands create the branches from this list.
- *Acceptance criteria*: each one verifiable on its own. `make review` checks them one by one.
- *Contracts and sensitive areas*: what changes according to `docs/system-map.md` and
  `docs/product/sensitive-areas.md`, or "None".

## Create the issue

1. Show the spec to the person and wait until they approve it.
2. Create the issue with `scripts/host.sh issue-create <Type> "<title>" <Draft>/spec.md`,
   with a short, clear title. The script prints the issue number.
3. Rename the draft folder to `.work/<number>/`.
4. If the spec touches contracts or sensitive areas, remind the person to ask someone on the
   team to review the issue before implementing it.
5. Give them the number and the link (`scripts/host.sh issue-get <number> url`). The next
   steps are `make verify I=<number>` (optional) and `make apply I=<number>`.

Drafts in `.work/` are never committed.
