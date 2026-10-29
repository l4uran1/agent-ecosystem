# Optional shortcuts for the ecosystem repo. To use them, copy this file to the root:
#   cp templates/Makefile Makefile
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

REPO_DIRS := $(shell grep -vE '^[[:space:]]*(\#|$$)' repos.txt | awk '{print $$1}')

.PHONY: help sync sync-all status branch check-spec doctor tests FORCE

help: ## list of commands
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'
	@printf "\033[36m%-20s\033[0m %s\n" "<repo>/<target>" "runs make <target> in that repo (e.g. api/test)"
	@if [ -n "$(ENV_REPO)" ]; then printf "\033[36m%-20s\033[0m %s\n" "$(ENV_TARGETS)" "run in $(ENV_REPO) (development environment)"; fi

## Repos and branches (bootstrap.sh)

sync: ## clone missing repos and update every main branch
	@./bootstrap.sh

sync-all: ## same as sync, including optional repos
	@./bootstrap.sh --all

status: ## branch and state of every repo
	@./bootstrap.sh status

branch: ## ID=<change-id>, or NAME=<branch> REPOS="<repo> ..."
	@if [ -n "$(ID)" ]; then \
		./bootstrap.sh branch "$(ID)"; \
	elif [ -n "$(NAME)" ] && [ -n "$(REPOS)" ]; then \
		./bootstrap.sh branch "$(NAME)" $(REPOS); \
	else \
		echo 'Usage: make branch ID=<change-id>  or  make branch NAME=<branch> REPOS="<repo> ..."'; \
		exit 1; \
	fi

check-spec: ## ID=<change-id>: is its proposal published, merged or archived?
	@if [ -z "$(ID)" ]; then echo 'Usage: make check-spec ID=<change-id>'; exit 1; fi
	@./bootstrap.sh check-spec "$(ID)"

doctor: ## check the ecosystem repo is filled in and set up
	@./bootstrap.sh doctor

tests: ## tests of bootstrap.sh and this Makefile, and shellcheck if installed
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
