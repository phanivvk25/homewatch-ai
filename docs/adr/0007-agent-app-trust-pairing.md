# ADR-0007: Agent–app trust: QR pairing, household CA, mTLS
**Status:** Proposed · **Date:** 2026-11-21

## Context
The app must trust only the real agent, and the agent must serve only paired household devices, on a LAN that may contain hostile devices. There is no public PKI for `192.168.x.x`.

## Decision
- On first boot the agent creates a **household CA** (P-256), a TLS leaf and an X25519 Noise static key.
- Pairing QR codes are shown **only** on an authenticated console (CLI through `docker exec`/SSH, or OpenWrt LuCI). For later invites, an already-paired owner's app shows the QR.
- QR payload (CBOR, base45): `v, agent_id, lan_addrs, port, spki_sha256, noise_pub, token_id, token_secret(128-bit), exp`.
- The app pins the SPKI, submits a CSR with an HMAC proof bound to the TLS exporter (`EXPORTER-hnt-pairing`), and receives a client cert from the household CA.
- After pairing, every API call uses **mTLS (TLS 1.3 only)**. The agent authorises using its paired-device table (role, revoked flag), not cert fields alone.
- Certs last 1 year and are re-issued automatically at 80% of their lifetime over an existing mTLS session.

## Alternatives
- *PAKE (SPAKE2/OPAQUE) with a 6-digit code:* good UX, but Dart library maturity is limited. QR + pin is simpler and equally strong given console-only display.
- *Bearer tokens over TLS with pinning:* weaker device binding. Rejected.

## Consequences
+ Strong mutual authentication and device binding, with instant revocation.
− The client key on mobile is software-held while in use (Dart TLS limitation, A7).
