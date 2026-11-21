# Top-level developer entry points. CI calls the same targets.
.PHONY: api-tools api-lint api-test api-gen-go api-gen-dart agent-schema-test

api-tools:
	cd tools/openapi && npm ci --no-audit --no-fund

api-lint: ## Lint OpenAPI contracts (Spectral + OWASP ruleset, Redocly). Fails on warnings.
	tools/openapi/node_modules/.bin/spectral lint -r api/.spectral.yaml api/agent.openapi.yaml api/cloud.openapi.yaml --fail-severity=warn
	tools/openapi/node_modules/.bin/redocly lint

api-test: ## Unit-test the 3.1 -> 3.0 converter
	python3 -m unittest discover -s tools/openapi

api-gen-go:
	tools/openapi/generate.sh go

api-gen-dart:
	tools/openapi/generate.sh dart

agent-schema-test: ## Apply agent migrations to an in-memory SQLite and check constraints
	python3 -m unittest discover -s tools/db
