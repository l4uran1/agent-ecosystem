# Setting up the ecosystem repo for your team

One person does this once, in a branch, and the team reviews it in a PR. Everyone else only
runs `make sync` and writes their own `local.mk`.

## 1. Create your ecosystem repo

Create a repo from this template (**Use this template** on GitHub, or clone it and push it to
your git host). Keep it **private**: it will describe how your system works and where it is
fragile. Its issues are where the specs of your changes will live, so keep issues enabled.

Clone it where your team keeps the service repos, or let `bootstrap.sh` clone them inside.
If you already have a folder with every service cloned, that folder can become the ecosystem repo:
copy these files into it and run `git init`. The `.gitignore` ignores the service repos.

## 2. List your repos

Replace the examples in `repos.txt` with your repos. If you already have them cloned, this
prints their remotes in the right format:

```bash
for d in */; do
  [ -d "$d/.git" ] && printf '%-18s %s core\n' "${d%/}" "$(git -C "$d" remote get-url origin)"
done
```

Use the canonical URL (`git@github.com:...` or `git@gitlab.com:...`), not your personal SSH
alias. Set `DEFAULT_BRANCH` in `bootstrap.sh` to your main branch (`main` by default) and add
a fourth column in `repos.txt` for any repo that uses a different one.

Run `./bootstrap.sh` and `git status`: only the ecosystem files should appear, never a service
repo folder.

## 3. Connect the git host and the agents

The workflow commands use `gh` (GitHub) or `glab` (GitLab) for issues and PRs, and `jq`.
`scripts/host.sh` picks `glab` when the ecosystem repo's remote URL contains "gitlab", and
`gh` otherwise; set `GIT_HOST=gh` or `GIT_HOST=glab` in `local.mk` if your host is not
detected.

```bash
gh auth login        # or: glab auth login
```

Each person writes their own `local.mk` (git ignores it):

```make
AGENT = claude            # or codex: the command that starts the agent with a first message
METHOD = default          # or openspec, superpowers
AGENT_REVIEWER =          # optional: a second agent that reviews first in make review
```

`scripts/agent.sh` starts the agent as `$AGENT "<instructions>"`. `claude` and `codex` take
the first message that way; for another agent, check that it does.

**Optional methods.** Nobody has to use them, and the workflow is the same with any of them:

- **OpenSpec** (`METHOD = openspec`): install the CLI and run
  `openspec init --tools claude,codex` (the agents your team uses). Only `/opsx:explore` is
  used; the spec still goes on the issue. Commit what `openspec init` generates for the
  agents (step 4); `openspec/changes/` stays ignored.
- **Superpowers** (`METHOD = superpowers`): install it as a plugin of the agent. Its
  documents go in `.work/<n>/`; `docs/superpowers/` is ignored in case it writes there anyway.

## 4. Check nothing is left out

```bash
git status --ignored
```

Agents and tools write configuration at the root (`.claude/`, `.cursor/`, `.agents/`...).
If any of it shows up as ignored and the team needs it, add it to the "Agent configuration"
block in `.gitignore` with `!`. Repeat until only the service repos, personal settings and
temporary files (`.work/`, `.worktrees/`, `local.mk`) are ignored.

## 5. Fill in the context

Every file below has `<placeholders>` and comments explaining what goes there. Facts only:
mark anything unknown as `TODO:` and resolve it before the pilot.

| File | What to write |
| --- | --- |
| `AGENTS.md` | Company name, main branch, git host CLI |
| `docs/system-map.md` | Contracts between services. Start with the ones that have broken before |
| `docs/product/sensitive-areas.md` | The few areas where a mistake hurts customers, and known risks |
| `docs/product/constraints.md` | Platforms, third-party APIs and regulation that rule out designs |
| `docs/product/glossary.md` | Domain terms the team uses |
| `docs/product/decisions/` | Date and accept decision 0001, or adapt it |
| `templates/spec.md` | Keep the sections (`make apply` reads *Affected repos*); adapt the hints |

The sensitive areas live only in `docs/product/sensitive-areas.md`: `AGENTS.md` and the
prompts point to it, so there is a single list to keep up to date.

Then run `make doctor`. It fails while a `<placeholder>` is left, and warns about `TODO:`s,
template comments still in place, a system map not reviewed in 90 days
(`MAP_MAX_AGE_DAYS` changes the limit), files `.gitignore` leaves out, a git host CLI that is
not logged in, and an ecosystem repo that is not on its main branch, up to date. Repeat until
it shows no errors, and resolve the warnings before the pilot.

## 6. Set up the service repos

For each service repo:

- Copy `templates/service-repo/AGENTS.md` to its root and fill in its commands. If it already
  has an `AGENTS.md` or `CLAUDE.md`, check it does not contradict the shared rules.
- If the team uses Claude Code, also copy `templates/service-repo/CLAUDE.md`: Claude Code
  does not read `AGENTS.md` on its own, and this one-line file imports it, so the repo's
  commands load as soon as the agent works in that folder.
- Copy `templates/service-repo/pull_request_template.md` to `.github/pull_request_template.md`
  (GitHub) or `.gitlab/merge_request_templates/Default.md` (GitLab). GitLab Premium can
  define it once at group level instead.

### The Makefile

The root `Makefile` holds the workflow commands (`make propose`, `make apply`...), short
names for `bootstrap.sh` (`make sync`, `make doctor`...) and `make <repo>/<target>`, which
runs any target of any repo's Makefile from the root, e.g. `make api/test`.

```bash
make help
```

If your team does not use `make`, `bootstrap.sh` does the same: `./bootstrap.sh apply 42`.
Without make, `local.mk` is not read: export `AGENT` and `METHOD` in your shell instead.

If one repo starts the development environment of the whole system (for example, its docker
compose file starts every service), set `ENV_REPO` to that repo in the Makefile. `make up`,
`make logs`... then run there from the root. `ENV_TARGETS` lists which targets are delegated.

## 7. Test it

Run a throwaway change end to end:

```bash
make propose IDEA="Add a log line when <some service> finishes <some job>"
```

Check that the agent writes the spec with the template, lists the affected repos and asks
for your approval before creating the issue. Then `make apply I=<n>` and check the
worktrees are created and the agent starts with the spec. Finish with
`make reject I=<n> REASON="Setup test"`: it closes the issue and its PRs and removes
everything.

## 8. Open the PR and run a pilot

Open a PR with everything above and ask two or three people to review `AGENTS.md`, the
prompts and the product context: their content shapes how everyone's agents behave.

Before rolling it out to the whole team, run a pilot with 3–4 people for a few weeks on real
features and bugs, ideally with different agents and methods. Agree beforehand:

- **Who reviews specs that touch sensitive areas or contracts, and how fast.** They are
  reviewed on the issue before `make apply`; a slow review there becomes the bottleneck and
  people start coding without agreement.
- **Who owns the ecosystem repo** and can merge changes to it, including the docs PRs that
  `make archive` opens.
- **What you will measure:** review round-trips, rework after merge, and how often
  `make review` finds something a person would have missed.

Then cut what nobody used, and only then roll it out.
