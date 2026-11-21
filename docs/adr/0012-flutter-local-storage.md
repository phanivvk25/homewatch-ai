# ADR-0012: Flutter local storage: drift + SQLCipher, bounded cache
**Status:** Proposed · **Date:** 2026-11-21

## Decision
- **drift** over SQLCipher (through `sqlite3` with SQLCipher build options / `sqlcipher_flutter_libs`). The 256-bit key is random and stored in `flutter_secure_storage` (Android Keystore-backed `EncryptedSharedPreferences` replacement with AES-GCM + Keystore key; iOS Keychain `WhenUnlockedThisDeviceOnly`).
- The cache holds devices, sessions and domain aggregates for `min(agent_retention, 7 days)` by default. Raw per-query rows are **not** cached; they are fetched on demand and paginated.
- Backups: `android:allowBackup="false"`, `fullBackupContent`/`dataExtractionRules` exclude all. iOS DB marked excluded from backup.
- "Delete all data" wipes the DB, keys and secure storage, and unpairs the device.

## Consequences
+ Fast offline UI, small footprint, data minimisation on the phone.
− SQLCipher adds about 1.5 MB per ABI, which fits the 25 MB budget.
