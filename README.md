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
  reviewed in a PR before any code is written.
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
├── templates/                  ← proposal PR description; AGENTS.md, CLAUDE.md and PR template per service repo
├── tests/                      ← tests for bootstrap.sh: tests/bootstrap.test.sh
├── api/                        ← service repos: own git, ignored by the ecosystem repo
├── web/
└── worker/
```

## Workflows

- **[New features](docs/workflows/feature.md):** proposal → review → branches in every
  affected repo → implementation with TDD → verification → one PR per repo → archive.
- **[Bug fixes](docs/workflows/bugfix.md):** root cause first, a test that reproduces the
  bug, a minimal fix. A proposal only when the fix changes behaviour, touches a sensitive
  area or changes a contract between services.

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
| `./bootstrap.sh check-approved <id>` | Succeeds only if the proposal `<id>` is merged into the ecosystem main branch |
| `./bootstrap.sh doctor` | Checks the ecosystem repo is filled in and set up: placeholders, TODOs, OpenSpec, system map age, files left out |
| `./bootstrap.sh tests` | Runs the tests of `bootstrap.sh`, and shellcheck if installed |

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
- **Humans approve, agents never merge.** The agent can open the proposal's PR, but it only
  implements once that PR is merged, and it never approves or merges anything.

## Requirements

- Bash (macOS, Linux, or WSL / Git Bash on Windows) and git 2.23+.
- Node.js 20.19+ for the OpenSpec CLI.
- `gh` or `glab` if you want agents to open PRs for you.

## License

[MIT](LICENSE)
