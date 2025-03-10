NAME          := go-ebsnvme
FILES         := $(shell git ls-files */*.go)
COVERAGE_FILE := coverage.out
REPOSITORY    := datadog/$(NAME)
.DEFAULT_GOAL := help

.PHONY: fmt
fmt: ## Format source code
	go run mvdan.cc/gofumpt@v0.5.0 -w $(shell git ls-files **/*.go)
	go run github.com/daixiang0/gci@v0.11.2 write -s standard -s default -s "prefix(github.com/mvisonneau)" .

.PHONY: lint
lint: ## Run all lint related tests upon the codebase
	go run github.com/golangci/golangci-lint/cmd/golangci-lint@v1.54.2 run -v --fast

.PHONY: test
test: ## Run the tests against the codebase
	@rm -rf $(COVERAGE_FILE)
	go test -v -count=1 -race ./... -coverprofile=$(COVERAGE_FILE)
	@go tool cover -func $(COVERAGE_FILE) | awk '/^total/ {print "coverage: " $$3}'

.PHONY: coverage
coverage: ## Prints coverage report
	go tool cover -func $(COVERAGE_FILE)

.PHONY: install
install: ## Build and install locally the binary (dev purpose)
	go install ./cmd/$(NAME)

.PHONY: build
build: ## Build the binaries using local GOOS
	go build ./cmd/$(NAME)

.PHONY: release
release: ## Build & release the binaries (stable)
	git tag -d edge
	goreleaser release --clean

.PHONY: prerelease
prerelease: ## Build & prerelease the binaries (edge)
	@\
		REPOSITORY=$(REPOSITORY) \
		NAME=$(NAME) \
		GITHUB_TOKEN=$(GITHUB_TOKEN) \
		.github/prerelease.sh

.PHONY: clean
clean: ## Remove binary if it exists
	rm -f $(NAME)

.PHONY: coverage-html
coverage-html: ## Generates coverage report and displays it in the browser
	go tool cover -html=coverage.out

.PHONY: is-git-dirty
is-git-dirty: ## Tests if git is in a dirty state
	@git status --porcelain
	@test $(shell git status --porcelain | grep -c .) -eq 0

.PHONY: man-pages
man-pages: ## Generates man pages
	rm -rf helpers/manpages
	mkdir -p helpers/manpages
	go run ./scripts/generate_man.go | gzip -c -9 >helpers/manpages/$(NAME).1.gz

.PHONY: autocomplete-scripts
autocomplete-scripts: ## Download CLI autocompletion scripts
	rm -rf helpers/autocomplete
	mkdir -p helpers/autocomplete
	curl -sL https://raw.githubusercontent.com/urfave/cli/v2.5.0/autocomplete/bash_autocomplete > helpers/autocomplete/bash
	curl -sL https://raw.githubusercontent.com/urfave/cli/v2.5.0/autocomplete/zsh_autocomplete > helpers/autocomplete/zsh

.PHONY: all
all: lint test build coverage ## Test, builds and ship package for all supported platforms

.PHONY: help
help: ## Displays this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'