# ADR-0011: Flutter: Riverpod, go_router, Clean Architecture
**Status:** Accepted · **Date:** 2026-11-21

## Context
We need testable layers, DI, offline-first streams, and good performance on 2–3 GB RAM devices.

## Decision
- **Riverpod 3** with `riverpod_generator`. Rather than Bloc because:
  1. It provides DI and state in one compile-safe mechanism, so we need no `get_it`.
  2. Providers are overridable per test and per flavor.
  3. `AsyncValue` maps directly onto the required loading, error and data states.
  4. It has less boilerplate than Bloc for the many read-mostly screens.
- **go_router** with typed routes (`go_router_builder`) and redirect guards: `!paired → /pairing`, `!consented → /consent`, `locked → /lock`.
- **Clean Architecture, feature-first:** `presentation → domain ← data`. The domain layer is pure Dart (no Flutter imports), enforced by a custom lint (`import_lint`/`dependency_validator`). Use cases are small classes, unit-tested to ≥80%.
- freezed + json_serializable for DTOs and entities. dio for HTTP.
- Lints: `very_good_analysis` plus custom rules. CI fails on any warning.

## Consequences
+ Uniform patterns and high testability.
− Code generation adds build time, mitigated with `build_runner` caching in CI.
