## 2026-09-20 - POSIX File Permissions on Local Encrypted Vault Storage
**Vulnerability:** Encrypted health records storage files (`records.enc` and `records.enc.tmp`) were written to disk with default operating system file permissions, potentially allowing group- or world-read access on multi-user systems.
**Learning:** While `HealthExportService` and `GuidelineStorageService` restricted permissions using `chmod 600`, `EncryptedRecordStore` omitted this file hardening step during atomic vault file writes.
**Prevention:** Always invoke `_restrictFilePermissions` (chmod 600 on POSIX platforms) whenever sensitive local files or temporary recovery files are created or modified on disk.
