# Sentinel's Journal

## 2026-03-30 - KDF Parameter Validation in Vault Backup Restoration
**Vulnerability:** Untrusted encrypted backup JSON contained KDF parameters (`iterations` and `salt`) that were accepted without validation during restoration.
**Learning:** Accepting unvalidated KDF iteration counts from backup files can lead to CPU-exhaustion Denial of Service (DoS) if iteration count is arbitrarily high, or key derivation downgrade if artificially low.
**Prevention:** Always enforce minimum security bounds and upper safety limits on KDF iteration counts (e.g. 100,000 to 1,000,000) and salt length (e.g. >= 16 bytes) before invoking key derivation functions.
