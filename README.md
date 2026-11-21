# Home Network Tracker (homewatch-ai)

A privacy-first home network visibility tool for Indian households. You can see which devices are on your Wi-Fi, when each one connected, and which websites (domains) each one looked up.

> **Status:** Architecture proposed and awaiting approval. No code yet.

## Repository layout
| Path | Contents |
|---|---|
| `app/` | Flutter mobile app (Android 8+, iOS 15+) |
| `agent/` | Home Agent (Go), shipped as Docker (arm64/amd64/armv7) and an OpenWrt package |
| `backend/` | Optional cloud relay and account API (ASP.NET Core, .NET 10 LTS, Azure India) |
| `infra/` | Bicep IaC |
| `api/` | OpenAPI 3.1 contracts (agent local API, cloud API) |
| `docs/` | Architecture, ADRs, security, privacy, runbooks |

## Start here
- [Architecture](docs/architecture/architecture.md)
- [Threat model (STRIDE)](docs/security/threat-model.md)
- [Architecture Decision Records](docs/adr/README.md)
- [Known limitations](docs/architecture/architecture.md#9-known-limitations)
