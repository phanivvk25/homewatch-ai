# ADR-0005: Device identity and MAC randomisation
**Status:** Accepted · **Date:** 2026-11-21

## Context
Android 10+ and iOS 14+ use per-SSID random MACs, and some rotate them periodically (iOS 18 "rotating", Android "non-persistent"). Keying devices purely by MAC creates duplicates.

## Decision
- `Device` has a surrogate `device_id` (UUIDv7). Identifiers live in `device_identifier(type, value_hash, value_enc)` with types `mac`, `dhcp_client_id`, `hostname`, `dhcp_fp` (hash of option 55 + 60 + vendor) and `mdns_name`.
- Matching runs in this order:
  1. Exact MAC.
  2. Same `dhcp_client_id`.
  3. Locally-administered MAC **and** same hostname **and** same `dhcp_fp`.
  4. Otherwise a new device with `possibly_randomized=true` when the LA bit is set.
- Users can **merge** devices (undoable for 7 days through `merge_log`) and **split** a merge.
- Vendor comes from the IEEE OUI (embedded, refreshed with category bundles). LA MACs show "Private address" instead of a vendor.
- Device type comes from rules over the DHCP fingerprint, vendor, mDNS service types (`_googlecast`, `_airplay`, `_ipp`) and SSDP `SERVER` headers.
- MACs are shown masked in the UI (`••:••:••:3A:4F:C2`), with reveal requiring app unlock.

## Consequences
+ Far fewer duplicates without user effort. Merging fixes the rest.
− Heuristic merges can be wrong. Mitigated by auto-merging only on strong (3-signal) matches and offering undo.
