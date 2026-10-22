# Changelog

## 0.1.0 - 2026-10-21

Initial release of Clinical Assistant.

### Added

- Import patient-approved measurements and clinical records from Apple Health,
  Android Health Connect, and SMART-on-FHIR provider portals.
- Manually record and correct measurements, track medications, and review
  descriptive health trends with source reference ranges.
- Export visit summaries as PDF and records as FHIR JSON Bundles or CSV.
- Browse selected clinical guidelines offline and save private consultation
  notes.
- Keep the local record vault encrypted and on-device, with optional encrypted
  backups.

### Security and reliability

- Harden encrypted backup nonce and restore validation ([PR #29](https://github.com/Aymeric/ClinicalAssistant/pull/29), [PR #47](https://github.com/Aymeric/ClinicalAssistant/pull/47)) and add progressive PIN rate limiting ([PR #50](https://github.com/Aymeric/ClinicalAssistant/pull/50)).
- Require HTTPS for guideline sources ([PR #53](https://github.com/Aymeric/ClinicalAssistant/pull/53), [PR #62](https://github.com/Aymeric/ClinicalAssistant/pull/62)) and sanitize exported CSV cells against formula injection ([PR #65](https://github.com/Aymeric/ClinicalAssistant/pull/65)).
- Improve trend parsing and reference-range caching ([PR #61](https://github.com/Aymeric/ClinicalAssistant/pull/61), [PR #64](https://github.com/Aymeric/ClinicalAssistant/pull/64)).

### Usability and release

- Improve accessibility and feedback across vault access, record details, manual entry, and overview quick actions ([PR #39](https://github.com/Aymeric/ClinicalAssistant/pull/39), [PR #45](https://github.com/Aymeric/ClinicalAssistant/pull/45), [PR #48](https://github.com/Aymeric/ClinicalAssistant/pull/48), [PR #51](https://github.com/Aymeric/ClinicalAssistant/pull/51)).
- Add the missing iOS HealthKit update-purpose string and improve iOS archive signing, export-options generation, and TestFlight IPA selection.