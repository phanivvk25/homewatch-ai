# ADR-0017: Agent release signing and update policy
**Status:** Accepted · **Date:** 2026-11-21

## Context
The requirement is auto-update with signature verification. A container cannot safely replace itself without access to the Docker socket, which equals root on the host. Read-only rootfs and image immutability also argue against in-container self-patching.

## Decision
- **Signing:**
  - Container images: cosign keyless (Sigstore, GitHub OIDC identity), with SLSA provenance + SBOM attestations.
  - Binaries, ipk, update manifests and category bundles: **minisign Ed25519**, with the key in Key Vault HSM, offline backup and a public key embedded in the agent.
- **Update manifest:** `{version, min_version, artifacts[{arch, url, sha256}], expires}`, signed. The agent rejects expired manifests and downgrades (rollback protection).
- **OpenWrt / bare binary:** auto-update ON (daily check, maintenance window 03:00 IST). Download → verify signature and hash → atomic swap → health check → automatic rollback on failure.
- **Docker (flagged A8):** default is **notify** (in-app "Update available" with a one-line `docker compose pull && up -d` command, digest-pinned). An opt-in `hnt-updater` sidecar compose profile (has the docker socket, verifies the cosign signature and identity before recreating) is provided for users who accept that trade-off.

## Consequences
+ Verified updates everywhere, without silently granting root-equivalent rights.
− Docker users must opt in to fully automatic updates.
