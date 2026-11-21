# ADR-0015: Azure India regions, regional WAF, Bicep
**Status:** Proposed · **Date:** 2026-11-21

## Decision
- Primary region **Central India (Pune)**, DR region **South India (Chennai)**, both inside India.
- Azure Container Apps (backend), PostgreSQL Flexible Server (zone-redundant HA, geo-backup to South India), Key Vault Premium (HSM-backed keys, CMK for PostgreSQL), Log Analytics (Central India), private endpoints, VNet integration.
- **Application Gateway WAF v2 (OWASP CRS 3.2 / DRS) regional**, instead of Front Door. Front Door terminates TLS at global PoPs, some outside India (flagged A4). App Gateway supports WebSockets for the relay.
- IaC in **Bicep**. Rather than Terraform because the product is Azure-only, Bicep needs no state file holding secrets, and it gets day-0 support for new Azure resources. What-if runs in PR, deploys go through GitHub OIDC federation (no stored credentials).
- Cross-border processing register: FCM/APNs (push), Sentry if SaaS (crash reports; the self-hosted option goes in India), GitHub (source code only, no personal data), and the user-selected DNS resolver.

## Consequences
+ Personal data stays in India and TLS terminates in India.
− Lacks Front Door's global edge acceleration (not needed for an India-only audience).
