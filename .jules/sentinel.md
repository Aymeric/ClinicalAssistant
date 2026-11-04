## 2026-09-22 - CSV Formula and DDE Injection Sanitization on Health Exports
**Vulnerability:** In `HealthExportService`, CSV formula injection protection checked for `=`, `+`, `-`, `@`, `\t`, and `\r`, but omitted pipe (`|`) character sanitization and omitted sanitization of raw serialized `sourceData` JSON cells.
**Learning:** Spreadsheets and terminal/DDE engines can interpret pipe `|` commands as injection triggers, and raw serialized JSON attributes or nested payloads in source data can trigger formula execution if not explicitly sanitized.
**Prevention:** Include pipe `|` in `_csvFormulaTrigger` and ensure all table cells, including complex payload fields such as `sourceData`, pass through `_sanitizeCsvCell`.

## 2026-09-21 - OAuth Credential Redaction in Local Import Error History
**Vulnerability:** When SMART-on-FHIR or provider sync attempts failed, exception messages could contain raw Bearer tokens, refresh tokens, access tokens, or authorization codes, which were saved unredacted in local sync history storage (`source_import_history_v1`).
**Learning:** `sanitizeImportErrorSummary` redacted full URLs (`https://...`), but failed to sanitize standalone `Authorization: Bearer <token>` headers or individual query parameter pairs (`access_token=...`, `refresh_token=...`, `client_secret=...`, `code=...`).
**Prevention:** Always apply regex sanitization for `Bearer` tokens and credential key-value parameters when processing network exception strings before logging or persisting them locally.

## 2026-09-20 - POSIX File Permissions on Local Encrypted Vault Storage
**Vulnerability:** Encrypted health records storage files (`records.enc` and `records.enc.tmp`) were written to disk with default operating system file permissions, potentially allowing group- or world-read access on multi-user systems.
**Learning:** While `HealthExportService` and `GuidelineStorageService` restricted permissions using `chmod 600`, `EncryptedRecordStore` omitted this file hardening step during atomic vault file writes.
**Prevention:** Always invoke `_restrictFilePermissions` (chmod 600 on POSIX platforms) whenever sensitive local files or temporary recovery files are created or modified on disk.
