# ADR-0016: Monorepo, contract-first OpenAPI 3.1, GitHub Actions
**Status:** Proposed · **Date:** 2026-11-21

## Decision
- Layout: `/app`, `/agent`, `/backend`, `/infra`, `/docs`, `/api` (OpenAPI 3.1 specs, the source of truth), `/tools`.
- Contract-first: specs are linted with Spectral (OWASP API ruleset). The Dart client is generated (`openapi-generator dart-dio`), and Go server interfaces are generated with `oapi-codegen` (strict server). The backend is validated against the spec in contract tests (Schemathesis against agent and backend). Breaking changes are detected with `oasdiff` in CI.
- GitHub Actions, with path-filtered workflows per component:
  - lint and test with coverage gates (domain ≥80%)
  - CodeQL (Go, C#, plus Semgrep for Dart)
  - Gitleaks, OSV-Scanner / govulncheck
  - Trivy (container + IaC)
  - CycloneDX SBOM
  - cosign signing with SLSA provenance
  - Fastlane to Play internal testing / TestFlight
- Actions pinned by SHA. Least-privilege `permissions`. Releases need environment approvals.
- Conventional Commits → release-please for SemVer + CHANGELOG per component.

## Consequences
+ One source of truth for APIs and consistent supply-chain controls.
− Generated-code churn, kept out of reviews with `linguist-generated`.
