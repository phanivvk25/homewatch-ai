# ADR-0006: Agent storage: SQLite + SQLCipher
**Status:** Accepted · **Date:** 2026-11-21

## Context
The agent needs embedded, low-RAM, crash-safe storage with AES-256 at rest. Write load: about 30 devices × roughly 2–10k queries/day = up to 300k rows/day.

## Decision
- SQLite (WAL mode) with **SQLCipher 4** (AES-256-CBC + HMAC-SHA512 per page, PBKDF2 disabled because we use a raw 256-bit key) via `github.com/mutecomm/go-sqlcipher` or an equivalent CGO binding, cross-compiled with `zig cc`.
- Key: 256-bit random. It is sealed to **TPM 2.0** when `/dev/tpmrm0` exists. Otherwise it lives in `/data/keys/db.key` with mode 0400, owned by UID 65532. The limitation is documented (A9).
- Writes are batched by a single writer goroutine. Reads use a separate read-only connection pool.
- Queries are stored raw for the retention window. A daily `domain_daily_agg` rollup (device, eTLD+1, date, count) powers dashboards cheaply and follows the same retention.
- A retention janitor runs hourly, deleting in batches of 5k rows, with `PRAGMA incremental_vacuum`.

## Alternatives
- *Pure-Go `modernc.org/sqlite` + field-level AES-GCM:* no CGO, but it breaks indexed search on domains and leaks structure. Rejected.
- *BoltDB/Badger:* no SQL, harder querying. Rejected.

## Consequences
+ Battle-tested, indexable and encrypted.
− CGO cross-compilation complexity, handled by zig plus a CI matrix.
