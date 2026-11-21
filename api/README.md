# API contracts

The OpenAPI **3.1** files in this directory are the source of truth for both APIs. Code is generated from them, never the other way round.

| File | API | Consumers |
|---|---|---|
| [`agent.openapi.yaml`](agent.openapi.yaml) | Home Agent local API (LAN mTLS, or tunnelled E2E through the relay) | Flutter app |
| [`cloud.openapi.yaml`](cloud.openapi.yaml) | Optional cloud API: accounts, households, enrollment, relay, push, DPDP rights | Flutter app, Home Agent |

## Conventions (both APIs)
- `/v1` path versioning. Breaking changes need `/v2` and are detected by `oasdiff breaking` in CI.
- RFC 3339 UTC timestamps, UUIDs for public ids, opaque keyset cursors (`cursor` / `next_cursor`, `limit` ≤ 200).
- Errors use RFC 9457 `application/problem+json` with a stable `code` used for localised messages in the app.
- `PATCH` uses JSON Merge Patch (`application/merge-patch+json`). `null` clears a field and absent leaves it unchanged.
- `Idempotency-Key` (UUID) is accepted on creating POSTs and replayed for 24 h.
- Every string has a `maxLength`, every array a `maxItems`, and every integer has bounds and a format (OWASP API4:2023).
- Every operation documents 400, 429 (with `Retry-After`) and 500.
- Agent authorisation uses `x-required-role: viewer | member | owner`, enforced by the agent from its member table.

## Tooling
```bash
make api-tools      # npm ci (pinned Spectral, Redocly, openapi-generator)
make api-lint       # Spectral (spectral:oas + OWASP 2023 ruleset) and Redocly; fails on warnings
make api-test       # unit tests for the 3.1 -> 3.0 converter
make api-gen-go     # agent strict server stubs (oapi-codegen) via derived OAS 3.0.3
make api-gen-dart   # Dart dio clients into app/packages/hnt_{agent,cloud}_api
```

Every Spectral rule that is disabled or overridden has its reason written in [`.spectral.yaml`](.spectral.yaml).

## Generator notes ([ADR-0018](../docs/adr/0018-openapi-31-codegen.md))
- **Go:** oapi-codegen does not support 3.1, so `tools/openapi/downconvert.py` derives a 3.0.3 document into `build/openapi/` (never committed). The converter fails loudly on 3.1 constructs it cannot map.
- **Dart:** `openapi-generator` `dart-dio` (pinned 7.17.0) reads 3.1 directly. Two known gaps, both handled in the app's data layer:
  1. Generated Merge Patch models use `includeIfNull: false`, so they cannot send an explicit `null`. Repositories send patch bodies as `Map<String, Object?>` through the generated client's `Dio` instance.
  2. The `mutualTLS` scheme is ignored by the generator. Client certificates are applied by `AgentTransport` (dio `HttpClientAdapter` with a `SecurityContext`), together with SPKI pinning.
