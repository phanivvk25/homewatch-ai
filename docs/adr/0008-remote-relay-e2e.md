# ADR-0008: Remote access: outbound relay with Noise IK end-to-end tunnel
**Status:** Accepted · **Date:** 2026-11-21

## Context
Remote access must work behind CGNAT (common on Jio and Airtel), use no port forwarding, and keep the relay blind to DNS and device data.

## Decision
- The agent keeps one **outbound WSS** connection to the relay (TLS 1.3, relay credential from enrollment, 30 s heartbeat, exponential backoff with jitter).
- The app opens a WSS stream to the relay with its OIDC access token. The relay checks membership and splices frames to the agent's connection (multiplexed by `stream_id`).
- Inside the stream: **`Noise_IK_25519_ChaChaPoly_BLAKE2s`**, with the app as initiator. The static keys were exchanged at LAN pairing, so the relay cannot MITM. The plaintext carried inside is HTTP/1.1 requests to the **same local API handlers**.
- Go uses `flynn/noise`. Dart implements Noise IK on top of the `cryptography` package and is verified against the Noise test vectors (cacophony / snow vectors) in CI.
- Optional length padding to 256-byte buckets.

## Alternatives
- *TLS-in-tunnel (reuse mTLS end-to-end through a TCP splice):* Dart's `SecureSocket` requires a real `Socket`, so it would need a loopback bridge. That is fragile on iOS background. Rejected for the MVP, but revisitable.
- *HPKE per-message:* no forward secrecy for the session. Rejected.
- *WireGuard / Tailscale:* requires VPN entitlements and a system VPN profile, which is heavy for users. Rejected.

## Consequences
+ True E2E. The relay holds no secrets that decrypt household data.
− Two secure transports (LAN mTLS, remote Noise) to maintain. Both are isolated behind the `AgentTransport` interface and covered by the same contract tests.
