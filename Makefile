SHELL := /bin/zsh

.PHONY: verify dev-up dev-down test-up test-down prod-up prod-down smoke

verify:
	./mvnw -B -ntp verify

dev-up:
	./scripts/stack-up.sh dev

dev-down:
	./scripts/stack-down.sh dev

test-up:
	./scripts/stack-up.sh test

test-down:
	./scripts/stack-down.sh test

prod-up:
	./scripts/stack-up.sh prod

prod-down:
	./scripts/stack-down.sh prod

smoke:
	./scripts/smoke-check.sh
