# The team's workflow

Workflow rules for the agent. The ones that hold with any workflow are in `AGENTS.md`; the
steps, explained for people, in `README.md`.

Every change, feature or bug, has an issue in the ecosystem repo whose body is the spec,
written with `templates/spec.md`. The steps are `explore`, `propose`, `verify`, `apply`,
`review`, `respond` and `archive`, plus `reject` to drop a change. Each one is a skill,
`eco-<step>` (`.agents/skills/`), that runs `./bootstrap.sh <step>` with the instructions of
`prompts/<step>.md`; from a terminal, `make <step>` does the same.

- If the person asks for a step without naming the skill, read and follow
  `.agents/skills/eco-<step>/SKILL.md`. Run from an agent, the script does not open another
  agent: it prints the instructions of the step, and you follow them here. `eco-verify` and
  `eco-review` are the exception: they open a separate session without a UI, because they need
  a clean one. Do not run `./bootstrap.sh verify` or `review` yourself without them: they
  refuse.
- The spec on the issue is the only source of what gets built. Do not write design documents
  in the repos or in the ecosystem repo.
- The contracts between services and the sensitive areas that `AGENTS.md` asks about go in the
  *Contracts and sensitive areas* section of the spec; someone else's review, on the issue.
  `make archive` checks at the end whether `docs/system-map.md` must change.
- Temporary documents (drafts, plans, reports) go in `.work/<n>/`, which git ignores.
  `make archive` and `make reject` delete it.
- If the spec has to change during the implementation, say so before going on. Then update
  the issue body (`scripts/host.sh issue-set-body`) and explain the change in a comment
  (`scripts/host.sh issue-comment`).
- OpenSpec and Superpowers are optional methods (`METHOD` in `local.mk`): they help to think,
  write and build, but the result goes on the issue. Do not use `/opsx:propose` or
  `/opsx:archive`.

## Bugs

The issue is labelled `bug` (`eco-propose`, saying it is a bug; `make propose TYPE=bug`) and
its branch is `fix/<n>-<slug>`. If the issue already exists without the template, complete its
body with it before `make apply`.

## Dropping a change

- Use `eco-reject` with the number and the reason (`make reject I=<n> REASON="<reason>"`): it
  closes the open PRs with the reason, posts it on the issue, closes the issue as not planned
  and removes worktrees, branches and `.work/<n>/`. Anyone who wants to keep the work saves it
  first.
- If a PR is already merged, it does nothing: first open a PR in that repo that reverts it,
  following the spec's *Rollback*.
