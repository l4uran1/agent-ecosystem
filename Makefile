# Shortcuts for the ecosystem repo, run from the root. If your team does not use make,
# delete this file: bootstrap.sh does the same.
# The logic stays in bootstrap.sh and in each repo's own Makefile: this file only gives it
# short names, so everything runs from the ecosystem root.
#
#   make help              list of commands
#   make <repo>/<target>   runs "make <target>" in that repo, e.g. make api/test

# Repo whose Makefile starts the development environment of the whole system (e.g. the one
# with the docker compose file), and the targets delegated to it, so they run from the root.
# Leave ENV_REPO empty if no repo does that: there are no environment targets then.
ENV_REPO :=
ENV_TARGETS := up stop restart ps logs

# Personal settings, never committed: AGENT, AGENT_REVIEWER and METHOD (see scripts/agent.sh
# and "review" in bootstrap.sh), and GIT_HOST if it is not detected (see scripts/host.sh).
# What is not set there comes from the environment.
-include local.mk
# strip: with "AGENT = claude  # or codex", make drops the comment but keeps the spaces.
AGENT := $(strip $(AGENT))
AGENT_REVIEWER := $(strip $(AGENT_REVIEWER))
METHOD := $(strip $(METHOD))
GIT_HOST := $(strip $(GIT_HOST))
export AGENT AGENT_REVIEWER METHOD GIT_HOST

REPO_DIRS := $(shell grep -vE '^[[:space:]]*(\#|$$)' repos.txt | awk '{print $$1}')

.PHONY: help sync sync-all status branch explore propose verify apply review archive reject doctor tests FORCE

help: ## list of commands
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'
	@printf "\033[36m%-20s\033[0m %s\n" "<repo>/<target>" "runs make <target> in that repo (e.g. api/test)"
	@if [ -n "$(ENV_REPO)" ]; then printf "\033[36m%-20s\033[0m %s\n" "$(ENV_TARGETS)" "run in $(ENV_REPO) (development environment)"; fi

## Repos and branches (bootstrap.sh)

sync: ## clone missing repos and update every main branch
	@./bootstrap.sh

sync-all: ## same as sync, including optional repos
	@./bootstrap.sh --all

status: ## branch and state of every repo and of its worktrees
	@./bootstrap.sh status

branch: ## I=<n> (branch and worktrees of an issue), or NAME=<branch> REPOS="<repo> ..."
	@if [ -n "$(I)" ]; then \
		./bootstrap.sh branch "$(I)"; \
	elif [ -n "$(NAME)" ] && [ -n "$(REPOS)" ]; then \
		./bootstrap.sh branch "$(NAME)" $(REPOS); \
	else \
		echo 'Usage: make branch I=<n>  or  make branch NAME=<branch> REPOS="<repo> ..."'; \
		exit 1; \
	fi

## The workflow: each step starts your agent (AGENT and METHOD in local.mk)

explore: ## [IDEA="..."]: explore an idea with your agent, without code or issues
	@./bootstrap.sh explore "$(IDEA)"

propose: ## IDEA="..." [TYPE=bug]: write the spec with your agent and create its issue
	@./bootstrap.sh propose "$(or $(TYPE),feature)" "$(IDEA)"

verify: ## I=<n>: review the spec of the issue with your agent, in a new session
	@if [ -z "$(I)" ]; then echo 'Usage: make verify I=<n>'; exit 1; fi
	@./bootstrap.sh verify "$(I)"

apply: ## I=<n>: branches and worktrees of the issue, then your agent implements it
	@if [ -z "$(I)" ]; then echo 'Usage: make apply I=<n>'; exit 1; fi
	@./bootstrap.sh apply "$(I)"

review: ## I=<n>: review the implementation with your agent, in a new session
	@if [ -z "$(I)" ]; then echo 'Usage: make review I=<n>'; exit 1; fi
	@./bootstrap.sh review "$(I)"

archive: ## I=<n>: with its PRs merged, final summary, close the issue and clean up
	@if [ -z "$(I)" ]; then echo 'Usage: make archive I=<n>'; exit 1; fi
	@./bootstrap.sh archive "$(I)"

reject: ## I=<n> REASON="...": drop the issue (close its PRs, publish the reason, clean up)
	@if [ -z "$(I)" ] || [ -z "$(REASON)" ]; then echo 'Usage: make reject I=<n> REASON="..."'; exit 1; fi
	@./bootstrap.sh reject "$(I)" "$(REASON)"

## Checks

doctor: ## check the ecosystem repo is filled in and set up
	@./bootstrap.sh doctor

tests: ## tests of bootstrap.sh, scripts/ and this Makefile, and shellcheck if installed
	@./bootstrap.sh tests

## Development environment: delegated to ENV_REPO

ifneq ($(ENV_REPO),)
.PHONY: $(ENV_TARGETS)
$(ENV_TARGETS):
	@$(MAKE) --no-print-directory -C $(ENV_REPO) $@
endif

## <repo>/<target>: one rule per repo in repos.txt. FORCE makes it run even if a file or
## folder with that name exists (e.g. api/build).

define repo_rule
$(1)/%: FORCE
	@$$(MAKE) --no-print-directory -C $(1) $$*
endef
$(foreach repo,$(REPO_DIRS),$(eval $(call repo_rule,$(repo))))

FORCE:
