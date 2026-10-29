# agent-ecosystem

**Your repos are an ecosystem. Give your AI coding agents the whole picture.**

A template for teams whose services live in **several tightly coupled repos** and who want
their AI coding agents to work with **shared context and a shared spec-driven process**.

Specs are handled with [OpenSpec](https://github.com/Fission-AI/OpenSpec), tested with version
1.13.2. Works with any agent OpenSpec supports (Claude Code, Cursor, Codex, GitHub Copilot
and others), and with GitHub or GitLab.

## The problem

Coding agents are good inside one repo. Most real systems are not one repo: a backend
publishes to a queue another service consumes, a worker reads tables it does not own, a
front end depends on an internal endpoint. An agent working in one repo cannot see any of
that, so it proposes changes that are reasonable in isolation and break something else.
And each developer ends up feeding the agent context their own way.

## The approach

The folder where your team already clones every service becomes a git repo of its own,
the **ecosystem repo**, that holds what the services share:

- **Rules for agents** (`AGENTS.md`): how the team works, once, for every agent.
- **A system map** (`docs/system-map.md`): the contracts between services — the thing an
  agent in a single repo can never see.
- **Product context** (`docs/product/`): sensitive areas, external constraints, glossary
  and decisions — what cannot be read in the code.
- **OpenSpec** (`openspec/`): one proposal per change, even when it spans several repos,
  published in a PR before any code is written and merged once the change is built.
- **`bootstrap.sh`**: gives everyone the same folder layout and keeps every repo's main
  branch up to date without ever touching your work.

The service repos stay exactly as they are. The ecosystem repo ignores them.

```
your-ecosystem/                 ← this template
├── AGENTS.md                   ← shared rules for every agent
├── CLAUDE.md                   ← imports AGENTS.md for Claude Code
├── bootstrap.sh                ← clones and updates the service repos
├── repos.txt                   ← list of service repos
├── docs/
│   ├── system-map.md           ← contracts between services
│   ├── product/                ← sensitive areas, constraints, glossary, decisions
│   └── workflows/              ← step-by-step guides: features and bug fixes
├── openspec/                   ← specs and changes for the whole system
├── templates/                  ← proposal PR description; per-repo AGENTS.md, CLAUDE.md, PR template; optional Makefile
├── tests/                      ← tests for bootstrap.sh and the optional Makefile
├── api/                        ← service repos: own git, ignored by the ecosystem repo
├── web/
└── worker/
```

## Workflows

- **[New features](docs/workflows/feature.md):** proposal PR → branches in every affected
  repo → implementation with TDD → verification → one PR per repo → archive → the proposal
  PR is reviewed and merged. A dropped change is
  [abandoned](docs/workflows/feature.md#abandoning-a-change), not archived.
- **[Bug fixes](docs/workflows/bugfix.md):** root cause first, a test that reproduces the
  bug, a minimal fix. A proposal only when the fix changes behaviour, touches a sensitive
  area or changes a contract between services.

### At a glance

The full rules are in `AGENTS.md`. `/opsx:*` commands run in the agent's chat, from the
ecosystem root; everything else runs in the terminal. Commands are shown for GitHub; on
GitLab use `glab mr create --target-branch <main>`.

**New feature**

| # | Step | Command |
| --- | --- | --- |
| 1 | (Optional) Explore the idea before proposing | `/opsx:explore` |
| 2 | Create the proposal (proposal, design, specs and tasks) | `/opsx:propose <description>` |
| 3 | Open the proposal's PR, without merging it: the agent offers it when step 2 ends | `gh pr create --base <main> --title "spec: <id>"` |
| 4 | Create `feature/<id>` in the affected repos. Creates nothing until the proposal's PR is open | `./bootstrap.sh branch <id>` |
| 5 | Implement task by task, with TDD. Progress in `tasks.md` is pushed to `spec/<id>` | `/opsx:apply <id>` |
| 6 | If the expected behaviour changes: update the proposal on `spec/<id>` and note it in its PR description | `/opsx:update <id>` |
| 7 | Open one PR per repo, with `<id>` in the title and a link to the proposal's PR | `gh pr create --base <main>` |
| 8 | (Optional) Check the implementation meets the proposal | `/opsx:verify <id>` |
| 9 | Once every code PR is merged: archive on `spec/<id>` | `/opsx:archive <id>` |
| 10 | Review and merge the proposal's PR: a person does it | Git host |

**Bug fix** (no proposal, unless it changes expected behaviour, touches a sensitive area or changes a contract)

| # | Step | Command |
| --- | --- | --- |
| 1 | Create the branch in the affected repos | `./bootstrap.sh branch fix/<short-description> <repo>...` |
| 2 | Reproduce, find the root cause and write the failing test | — |
| 3 | Fix and open one PR per repo | `gh pr create --base <main>` |

**Abandoning a change**

| # | Step | Command |
| --- | --- | --- |
| 1 | Close the proposal's PR without merging, with the reason in a comment | Git host |
| 2 | Close the open code PRs and revert the ones already merged | Git host |
| 3 | Delete `spec/<id>` and `feature/<id>` | `git push origin --delete <branch>` |

### Example: export orders to CSV

A feature that touches `api` (an export endpoint) and `web` (a button).

```bash
# In the agent: the proposal, with id export-orders-csv
/opsx:propose Let users export their order list to CSV from the web app
# The agent offers to open the PR "spec: export-orders-csv". It stays open until the end.

# In the terminal: create the branches. Without the proposal's PR, it refuses:
./bootstrap.sh branch export-orders-csv
# !! export-orders-csv: not published. Push spec/export-orders-csv with openspec/changes/export-orders-csv/ and open its PR (spec: export-orders-csv) before implementing.

# With the PR open:
./bootstrap.sh branch export-orders-csv
#    repos of the change: api web
# -> api: created feature/export-orders-csv from main
# -> web: created feature/export-orders-csv from main

# In the agent: implement. Ticked tasks, and every change to the proposal made with
# /opsx:update, are pushed to spec/export-orders-csv
/opsx:apply export-orders-csv

# One PR per repo, with the id in the title:
#   api: "export-orders-csv: CSV export endpoint"
#   web: "export-orders-csv: Export to CSV button"

# Once both code PRs are merged, in the agent:
/opsx:archive export-orders-csv
# The agent pushes the archive to spec/export-orders-csv and says the proposal's PR is
# ready. A person reviews and merges it: the spec then lives in openspec/specs/.
```

## Getting started

**Adopting the template for your team:** click **Use this template** on GitHub (or clone it
and push it to your git host), then follow [SETUP.md](SETUP.md).

**Joining a team that already uses it:**

```bash
git clone <your-ecosystem-url> ecosystem
cd ecosystem
./bootstrap.sh
npm install -g @fission-ai/openspec@<X.Y.Z>
```

Then start your agent from the ecosystem root, never from inside a service repo.
Quick check: ask it "what does AGENTS.md say about when to read the system map?". If it
answers with the ecosystem rules, everything is wired up.

## Daily use

| Command | What it does |
| --- | --- |
| `./bootstrap.sh` | Clones missing repos and brings every repo's main branch up to date, whatever branch you are on |
| `./bootstrap.sh --all` | Same, including optional repos |
| `./bootstrap.sh status` | Branch and state of every repo |
| `./bootstrap.sh branch <branch> <repo>...` | Creates the branch from the main branch (or switches to it) in several repos |
| `./bootstrap.sh branch <id>` | Same, with `feature/<id>` in the repos tagged in the `tasks.md` of `spec/<id>`. Only if the proposal's PR is open |
| `./bootstrap.sh check-spec <id>` | Says, without creating anything, whether the proposal `<id>` is published (PR open), merged or archived |
| `./bootstrap.sh doctor` | Checks the ecosystem repo is filled in and set up: placeholders, TODOs, OpenSpec, system map age, files left out |
| `./bootstrap.sh tests` | Runs the tests of `bootstrap.sh` and the optional Makefile, and shellcheck if installed |

Prefer `make`? Copy `templates/Makefile` to the root (see [SETUP.md](SETUP.md)): it adds
`make sync`, `make branch ID=<id>`, `make doctor`... and `make <repo>/<target>` to run any
repo's Makefile target from the root.

The script never deletes anything, never switches your branch and never touches your files:

- **On the main branch, clean:** pulls.
- **On another branch:** updates your local main branch in the background, without moving you.
- **On the main branch with uncommitted changes:** only fetches; pull once you commit.

### If you use an SSH alias or HTTPS

`repos.txt` always uses the canonical URL. If you reach the git host through another host
name (an alias in `~/.ssh/config`, a second account, or HTTPS), do not edit `repos.txt`;
tell git to rewrite the URL, once:

```bash
# SSH alias (e.g. Host github-work in ~/.ssh/config)
git config --global url."git@github-work:".insteadOf "git@github.com:"

# HTTPS instead of SSH
git config --global url."https://github.com/".insteadOf "git@github.com:"
```

## Design choices

- **An ecosystem repo, not a monorepo.** Same shared context, no migration of history, CI or
  deployments.
- **The shared knowledge is plain markdown.** It outlives any tool: if you replace OpenSpec
  one day, the system map and product context stay.
- **Minimal by default.** No orchestration layer, no extra CLI, no skill packs. Add more
  only when an agent actually fails in a way rules cannot fix.
- **One ecosystem PR per change, merged at the end.** The proposal's PR is opened before any
  code and merged once the change is built, with the archive, so the main branch only gets
  what was built. The accepted risk: code can be merged before the spec is reviewed. Changes
  that need agreement first (sensitive areas, contracts) get their review before starting.
- **Humans approve, agents never merge.** The agent can open PRs, but it never approves or
  merges anything.

## Requirements

- Bash (macOS, Linux, or WSL / Git Bash on Windows) and git 2.23+.
- Node.js 20.19+ for the OpenSpec CLI.
- `gh` or `glab` if you want agents to open PRs for you.

## License

[MIT](LICENSE)
