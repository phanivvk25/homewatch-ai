# ADR-0018: OpenAPI 3.1 source of truth; derived 3.0.3 for Go codegen
**Status:** Accepted · **Date:** 2026-11-21 · **Amends:** [ADR-0016](0016-monorepo-contract-first-ci.md)

## Context
ADR-0016 chose OpenAPI 3.1 contracts, `oapi-codegen` (Go strict server) and `openapi-generator` (Dart). While writing the contracts we verified both generators:
- `oapi-codegen` v2.5.1 rejects 3.1 constructs (`type: [T, 'null']`, `oneOf` with `{type: 'null'}`). Its 3.1 support is an open upstream issue.
- `@apiture/openapi-down-convert` does not handle `oneOf: [$ref, {type: 'null'}]`.
- `openapi-generator` 7.17.0 (`dart-dio`, json_serializable) handles our 3.1 specs, but (a) Merge Patch models omit nulls and (b) it ignores `mutualTLS`.

## Decision
1. The OpenAPI **3.1** files in `/api` remain the only hand-edited contracts.
2. `tools/openapi/downconvert.py` (stdlib + PyYAML, unit-tested) derives OAS **3.0.3** at build time for Go codegen. It maps exactly the constructs we use and fails on anything else, so the contract can't silently drift from what the generator sees. Output goes to `build/` and is never committed.
3. CI validates the derived 3.0.3 documents with Redocly, then runs `oapi-codegen` and `go vet` on the output.
4. Dart: generate from 3.1 directly. Merge Patch bodies are built as maps in repositories, and mTLS is applied by `AgentTransport`.
5. Revisit when oapi-codegen ships 3.1 support (remove the converter) or if `ogen` proves a better fit for the agent.

## Consequences
+ We keep 3.1 features (JSON Schema 2020-12, `mutualTLS`, `const`) in the contract and still get typed Go servers.
− One small in-house tool to maintain (about 200 lines, with tests).
