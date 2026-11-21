# ADR-0013: Content-free push; alerts generated on the agent
**Status:** Accepted · **Date:** 2026-11-21

## Decision
- The agent evaluates alert rules (new unknown device, online outside allowed hours, category hit: adult or malicious) because only it sees the data.
- Remote mode: the agent sends `{alert_ref}` to the relay. The backend sends FCM (Android + iOS through APNs) with `{t:"alert", r:alert_ref}` and a generic, localised notification string. The app then fetches details through the E2E tunnel.
- Local-only: Android `WorkManager` periodic sync (15 min, only on unmetered Wi-Fi matching the home network) raises local notifications. iOS uses `BGAppRefreshTask` (best-effort) plus sync on open. This limitation is documented.
- Dedupe and rate-limit on the agent (for example, at most one category alert per device per category per hour).
- **Cross-border:** FCM/APNs are processed outside India. Only an opaque reference and the push token are sent. This is disclosed in the privacy policy and Data Safety form.

## Consequences
+ Google and Apple learn nothing sensitive.
− Weaker alert UX in local-only mode.
