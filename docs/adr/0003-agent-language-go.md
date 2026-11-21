# ADR-0003: Agent implemented in Go
**Status:** Accepted · **Date:** 2026-11-21

## Context
The agent must run on a Raspberry Pi (arm64/armv7), x86 mini-PCs and NAS boxes, and on OpenWrt routers (aarch64, arm and mipsel, often 128–256 MB RAM). It needs a DNS server, packet capture (ARP/DHCP), mDNS, TLS 1.3 + mTLS, Noise, SQLite and an HTTP API. The p95 DNS overhead must stay under 5 ms.

## Decision
**Go** (latest stable ≥1.26, toolchain pinned in `go.mod`).
- DNS: `codeberg.org/miekg/dns` (v2) / `github.com/miekg/dns`, proven in CoreDNS.
- Packets: `github.com/google/gopacket` (AF_PACKET, no libpcap) and `github.com/mdlayher/*` (arp, ndp, netlink).
- Noise: `github.com/flynn/noise`. TLS: stdlib `crypto/tls` (TLS 1.3, `MinVersion: tls.VersionTLS13`).
- SQLite + SQLCipher via CGO, cross-compiled with `zig cc` (see ADR-0006).

## Alternatives
- *Rust:* smaller binaries (~3–5 MB vs ~12–15 MB) and no GC. But development is slower, the cross-compiled crypto/DNS ecosystem is less mature for mipsel, and fewer contributors know it. GC pauses in Go (sub-ms) fit comfortably inside the 5 ms budget.
- *Python/Node:* too heavy for routers. Rejected.

## Consequences
+ Static binaries, trivial cross-compilation, strong stdlib crypto, fast iteration.
− Binary size limits the smallest routers (≥32 MB flash or extroot required, see A14). CGO is needed for SQLCipher.
