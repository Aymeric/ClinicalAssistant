## 2026-10-24 - Consume background timestamps upon lock check evaluation
**Vulnerability:** `VaultSecurityService` retained `_backgroundedAt` state after `shouldLockOnResume()` evaluated auto-lock timeout. If the background duration was shorter than the timeout, the timestamp persisted, causing subsequent foreground state checks to miscalculate active foreground time as background time and trigger mid-session vault lockouts.
**Learning:** Security state timestamps representing event occurrences (like backgrounding) must be consumed/cleared once evaluated to avoid state leakage across lifecycle state transitions.
**Prevention:** Explicitly set event timestamp state variables to `null` on evaluation and on state transitions such as authentication success or unlock.
