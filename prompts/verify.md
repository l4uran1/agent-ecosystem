# Review a spec before it is built

Review the spec of the issue at the end of this message. You did not write it: read it as
someone who has to build it without being able to ask its author.

- Do not write code or create branches.
- Check, against the code of the repos and `docs/`:
  - that it follows `templates/spec.md`;
  - that *Affected repos* lists every repo that must change, and no other;
  - that every acceptance criterion can be verified and that, together, they cover the change;
  - that there are no contradictions, gaps or decisions left open;
  - that *Contracts and sensitive areas* matches `docs/system-map.md` and
    `docs/product/sensitive-areas.md`;
  - that the *Rollback* is realistic.
- Show the person what you find, most important first, with a concrete proposal for each
  point. If you find nothing, say so.
- If the person accepts changes: write the whole spec in `.work/<n>/spec.md`, upload it with
  `scripts/host.sh issue-set-body <n> .work/<n>/spec.md`, and explain what changed and why in a
  comment: write it in `.work/<n>/change.md` and post it with
  `scripts/host.sh issue-comment <n> .work/<n>/change.md`.
- The next step is `make apply I=<n>`.
