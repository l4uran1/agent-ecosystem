# What to review more carefully in each repo

One file per repo, `docs/review/<repo>.md`, with the folder name of `repos.txt`. `make review`
reads it from the main branch of the ecosystem repo, never from the branch under review, so a
change cannot rewrite the rules that judge it.

List the places where a change in that repo breaks things its tests do not show. Each row says
what has to appear in the diff and where the full rule lives, without repeating it. Failures
across services that can be seen in a diff go in `docs/reliability-checklist.md` instead.

Example (`docs/review/api.md`):

```markdown
# What to review more carefully in api

| If the diff… | Check | Rule |
|---|---|---|
| adds a table keyed by user (`user_id`…) | It is in the account deletion path | `api/AGENTS.md` › User data |
| adds a queue consumer | It is idempotent: messages arrive at least once | `docs/system-map.md` › Queues |
```

A repo without a file is reviewed with the general rules only.
