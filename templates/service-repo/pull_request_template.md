<!--
  Copy this file into each service repo:
  - GitHub: .github/pull_request_template.md
  - GitLab: .gitlab/merge_request_templates/Default.md (applied to every new MR)
-->

## What and why

<!-- One or two sentences. For a bug: the root cause. -->

## Related

- Issue: <!-- link to the issue of the ecosystem repo with the spec -->
- Other PRs of the same change: <!-- links, if it spans several repos -->

## Definition of done

- [ ] Tests added or updated (for a bug: a test that reproduces it)
- [ ] Tests, lint and build pass
- [ ] Does it change a queue, pub/sub channel, internal endpoint or shared table?
      If so, the spec says so: `make archive` updates `docs/system-map.md`
