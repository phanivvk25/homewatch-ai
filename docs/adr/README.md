# Architecture Decision Records

Format: [Michael Nygard](https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions). Statuses: Proposed → Accepted / Rejected / Superseded.

| # | Title | Status |
|---|---|---|
| [0001](0001-record-architecture-decisions.md) | Record architecture decisions | Accepted |
| [0002](0002-three-tier-local-first.md) | Three-tier, local-first architecture | Accepted |
| [0003](0003-agent-language-go.md) | Agent implemented in Go | Accepted |
| [0004](0004-dns-capture-strategy.md) | DNS capture strategy: resolver mode, optional DHCP mode, DoH/DoT upstream | Accepted |
| [0005](0005-device-identity.md) | Device identity and MAC randomisation | Accepted |
| [0006](0006-agent-storage-sqlcipher.md) | Agent storage: SQLite + SQLCipher | Accepted |
| [0007](0007-agent-app-trust-pairing.md) | Agent–app trust: QR pairing, household CA, mTLS | Accepted |
| [0008](0008-remote-relay-e2e.md) | Remote access: outbound relay with Noise IK end-to-end tunnel | Accepted |
| [0009](0009-backend-dotnet10.md) | Backend on ASP.NET Core / .NET 10 LTS (deviation from .NET 9) | Accepted |
| [0010](0010-identity-oidc-otp.md) | Identity: self-hosted OIDC (OpenIddict), PKCE, OTP; account optional in local mode | Accepted |
| [0011](0011-flutter-state-routing-architecture.md) | Flutter: Riverpod, go_router, Clean Architecture | Accepted |
| [0012](0012-flutter-local-storage.md) | Flutter local storage: drift + SQLCipher, bounded cache | Accepted |
| [0013](0013-push-notifications.md) | Content-free push; alerts generated on the agent | Accepted |
| [0014](0014-categorisation-psl.md) | Domain grouping (PSL) and offline signed category bundles | Accepted |
| [0015](0015-cloud-hosting-localization.md) | Azure India regions, regional WAF, Bicep | Accepted |
| [0016](0016-monorepo-contract-first-ci.md) | Monorepo, contract-first OpenAPI 3.1, GitHub Actions | Accepted (amended by 0018) |
| [0017](0017-agent-release-update-signing.md) | Agent release signing and update policy | Accepted |
| [0018](0018-openapi-31-codegen.md) | OpenAPI 3.1 source of truth; derived 3.0.3 for Go codegen | Accepted |
