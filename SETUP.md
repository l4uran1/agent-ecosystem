# Setting up the ecosystem repo for your team

One person does this once, in a branch, and the team reviews it in a PR. Everyone else only
runs `./bootstrap.sh` and installs the OpenSpec CLI.

## 1. Create your ecosystem repo

Create a repo from this template (**Use this template** on GitHub, or clone it and push it to
your git host). Keep it **private**: it will describe how your system works and where it is
fragile.

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

## 3. Initialise OpenSpec

```bash
npm install -g @fission-ai/openspec@latest
openspec --version          # write this version in README.md ("Tested with OpenSpec")
openspec init --tools claude,cursor,codex    # the agents your team uses
```

`openspec/config.yaml` already exists, so `init` keeps it. Check that it did not drop any
key it needs, and keep any key it adds.

Then enable `verify`, used in step 7 of the feature workflow. The default profile does not
include it:

```bash
openspec config profile     # choose "Workflows only" and add verify; keep delivery as is
openspec update
```

The profile is stored in your user config, not in the project. The team gets the commands
because the generated files are committed, but anyone running `openspec update` with the
default profile could remove `verify`. Only the ecosystem repo owner should run it.

## 4. Check nothing is left out

```bash
git status --ignored
```

`openspec init` writes skills and commands per agent (`.claude/`, `.cursor/`, `.agents/`,
`.github/`...). If any of them shows up as ignored, add it to the "Agent configuration" block
in `.gitignore` with `!`. Repeat until only the service repos and personal settings are
ignored.

## 5. Fill in the context

Every file below has `<placeholders>` and comments explaining what goes there. Facts only:
mark anything unknown as `TODO:` and resolve it before the pilot.

| File | What to write |
| --- | --- |
| `AGENTS.md` | Company name, main branch, git host CLI |
| `openspec/config.yaml` | The `context` block: product, repos, stack, constraints, language |
| `docs/system-map.md` | Contracts between services. Start with the ones that have broken before |
| `docs/product/sensitive-areas.md` | The few areas where a mistake hurts customers, and known risks |
| `docs/product/constraints.md` | Platforms, third-party APIs and regulation that rule out designs |
| `docs/product/glossary.md` | Domain terms the team uses |
| `docs/product/decisions/` | Date and accept decision 0001, or adapt it |

The sensitive areas live only in `docs/product/sensitive-areas.md`: `AGENTS.md` and
`openspec/config.yaml` point to it, so there is a single list to keep up to date.

Then run `./bootstrap.sh doctor`. It fails while a `<placeholder>` is left or OpenSpec is not
set up, and warns about `TODO:`s, template comments still in place, a system map not reviewed
in 90 days (`MAP_MAX_AGE_DAYS` changes the limit) and files `.gitignore` leaves out. Repeat
until it shows no errors, and resolve the warnings before the pilot.

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

## 7. Test it

Start your agent from the ecosystem root and create a throwaway proposal:

```text
/opsx:propose test-config

Add a log line when <some service> finishes <some job>.
```

Check that the proposal lists the affected repos and that every task in `tasks.md` names its
repo and the test it starts with. Then delete it: `rm -rf openspec/changes/test-config`.

## 8. Open the PR and run a pilot

Open a PR with everything above and ask two or three people to review `AGENTS.md` and the
product context: their content shapes how everyone's agents behave.

Before rolling it out to the whole team, run a pilot with 3–4 people for a few weeks on real
features and bugs. Agree beforehand:

- **Who reviews proposals, and how fast** (e.g. same day). A slow review becomes the
  bottleneck and people start coding without approval.
- **Who owns the ecosystem repo** and can merge changes to it.
- **What you will measure:** review round-trips, rework after merge, and how much time the
  proposal step adds.

Then cut what nobody used, and only then roll it out.
