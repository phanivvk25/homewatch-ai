# ADR-0010: Identity: self-hosted OIDC (OpenIddict), PKCE, OTP; account optional in local mode
**Status:** Accepted · **Date:** 2026-11-21

## Context
Requirements: OAuth 2.0/OIDC with PKCE, access tokens ≤15 min, rotating refresh tokens, device binding, mobile OTP + email. Data localization favours India-hosted identity. Azure AD B2C is closed to new customers, and Entra External ID doesn't guarantee India data residency. TRAI requires DLT registration for commercial SMS.

## Decision
- An **OpenIddict** authorization server inside the backend, deployed in Central India. It allows the Authorization Code + PKCE (S256) flow only. No implicit or password grants.
- Login: phone OTP (6 digits, 5 min, 5 attempts, through a DLT-registered Indian gateway) **and** email verification (OTP through Azure Communication Services with India data location, or an Indian SMTP provider).
- Access token 10 min. Refresh token rotating, 30-day sliding window, reuse detection that revokes the whole token family, sender-constrained with **DPoP** (P-256 key in Keystore/Keychain, hardware-backed where possible; this key *is* non-exportable, unlike the mTLS key).
- The app uses `flutter_appauth` with the system browser (ASWebAuthenticationSession / Custom Tabs).
- **Account is optional in local-only mode** (flagged A2). Onboarding offers "Continue without account (local only)" and "Create account (enables remote access & push)". Data minimisation under DPDP §6 favours this, and nothing is lost functionally.
- Age gate: account holder must declare 18+.

## Consequences
+ Data stays in India. Standards-based. Fewer accounts holding PII.
− We operate an IdP and must patch it promptly. SMS DLT onboarding has lead time (2–4 weeks).
