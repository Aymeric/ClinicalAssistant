# Changelog

## 0.4.0 - 2026-11-01

### Added

- Health Insurance & Coverage ingestion (`Coverage`) from SMART-on-FHIR provider endpoints and Apple Health Clinical Records (`HKClinicalTypeIdentifier.coverageRecord`), featuring structured plan details, subscriber ID, group number, copays, deductibles, and an offline policy summary card ([#155](https://github.com/Aymeric/ClinicalAssistant/issues/155)).
- Multi-resource FHIR ingestion expanding coverage to `Condition`, `MedicationRequest`, `AllergyIntolerance`, `Immunization`, and `DiagnosticReport` across provider portals and Apple Health Clinical Records ([#74](https://github.com/Aymeric/ClinicalAssistant/issues/74)).
- Grouped clinical lab panels and multi-analyte entry support, preserving panel membership (`Observation.hasMember`, `DiagnosticReport.result`) and grouping same-source, same-timestamp analytes (CBC, CMP, BMP, Lipid, Thyroid) with collapsible headers and out-of-range indicators ([#130](https://github.com/Aymeric/ClinicalAssistant/issues/130)).
- Interactive Doctor Visit Preparation Wizard UI and tailored specialty PDF consultation summaries (Cardiology, Endocrinology & Diabetes, Annual Wellness) with patient discussion agendas and customizable note prompts ([#81](https://github.com/Aymeric/ClinicalAssistant/issues/81)).
- Clinical specialty group filtering across records and trends, allowing focused exploration of cardiovascular, endocrine, metabolic, renal, and wellness records.
- Critical-value safety evaluator and visual badges for high-risk biometric readings (systolic/diastolic blood pressure, glucose, resting heart rate, oxygen saturation, potassium, sodium, calcium, hemoglobin, platelets) based on established clinical guidelines ([#79](https://github.com/Aymeric/ClinicalAssistant/issues/79)).
- Customizable resting heart rate safety profiles and threshold preferences (General Adult, Athletic, Bradycardia/Tachycardia custom thresholds).
- Native Apple Watch ECG classification and Heart Rate Variability (SDNN) ingestion into encrypted vault with diagnostic neutrality disclosures.

### Changed

- Automatically normalize raw decimal fraction health percentages and blood oxygen values (e.g., `0.98` converted to `98%`).
- Include health insurance and plan details in clinical consultation summary PDFs without off-device transmission.

### Security and reliability

- Restrict vault file permissions on POSIX systems (`chmod 0600`) ([#135](https://github.com/Aymeric/ClinicalAssistant/issues/135)).
- Add extensive constant-time comparison security test suites for cryptographic authentication and PIN verification ([#137](https://github.com/Aymeric/ClinicalAssistant/issues/137)).
- Optimize trend chart painter bounds, index loops, and workout activity aggregation hot paths ([#134](https://github.com/Aymeric/ClinicalAssistant/issues/134), [#138](https://github.com/Aymeric/ClinicalAssistant/issues/138)).

### Usability and accessibility

- Add accessible Tooltips and Semantics to pinned metric cards ([#136](https://github.com/Aymeric/ClinicalAssistant/issues/136)).
- Improve accessibility for health record rows with consolidated Semantics announcements ([#139](https://github.com/Aymeric/ClinicalAssistant/issues/139)).

## 0.3.0 - 2026-10-26

### Added

- Direct local FHIR JSON and multi-file selection import with atomic validation, resource type tallies, live previews, and provenance preservation ([#118](https://github.com/Aymeric/ClinicalAssistant/issues/118)).
- Preflight conformance validation and review sheet for FHIR exports declaring HL7 FHIR Release 4 (R4 v4.0.1) compliance, including resource breakdowns and provider acceptance disclaimers ([#120](https://github.com/Aymeric/ClinicalAssistant/issues/120)).
- Fasting and measurement context filtering (`Fasting`, `Pre-meal`, `Post-meal (2 hr)`, `Bedtime`, `Random`) for like-for-like trend evaluations and descriptive statistics ([#132](https://github.com/Aymeric/ClinicalAssistant/issues/132)).
- Opt-in medication start and stop milestone timeline markers overlaid on single-series trend charts with accessible chronological summaries and non-causal disclosures ([#133](https://github.com/Aymeric/ClinicalAssistant/issues/133)).
- Per-source import activity history, date-span coverage visualization, and workout/distance aggregation for health platform imports ([#119](https://github.com/Aymeric/ClinicalAssistant/issues/119)).
- Source-scoped exports and privacy redaction controls to toggle notes and raw `sourceData` payloads in PDF, CSV, and FHIR outputs ([#131](https://github.com/Aymeric/ClinicalAssistant/issues/131)).
- Incremental health-platform synchronization using change tokens and anchor reset controls.

### Security and reliability

- Restrict downloaded clinical guidelines, saved favorites, and consultation notes file permissions to user-only (chmod 0600) on POSIX platforms ([#125](https://github.com/Aymeric/ClinicalAssistant/issues/125)).
- Strictly enforce supported cryptographic algorithms (`PBKDF2-HMAC-SHA256`, `AES-256-GCM`) during encrypted vault backup restoration ([#128](https://github.com/Aymeric/ClinicalAssistant/issues/128)).
- Enforce HTTPS transport security for all external documentation and guideline citations in GuidelineViewerPage ([#121](https://github.com/Aymeric/ClinicalAssistant/issues/121)).
- Optimize overview page performance with streaming single-pass candidate tracking and cached metric aggregations ([#122](https://github.com/Aymeric/ClinicalAssistant/issues/122), [#127](https://github.com/Aymeric/ClinicalAssistant/issues/127)).

### Usability and accessibility

- Add accessible tooltips and semantics to the moving average filter chip ([#126](https://github.com/Aymeric/ClinicalAssistant/issues/126)), measurement selector ([#129](https://github.com/Aymeric/ClinicalAssistant/issues/129)), and raw FHIR data toggle ([#123](https://github.com/Aymeric/ClinicalAssistant/issues/123)).
- Add store listing assets, screenshots, and active medication synthetic demonstration records.

## 0.2.0 - 2026-10-22

### Added

- Refresh the iOS and Android app icons, launch screens, and brand colors.

### Changed

- Confirm medication deletion before removing the medication and its adherence
  history ([PR #69](https://github.com/Aymeric/ClinicalAssistant/pull/69)); add
  clearer action labels and accessible date-range controls
  ([PR #72](https://github.com/Aymeric/ClinicalAssistant/pull/72)).
- Improve clinical guideline catalog lookup and query caching
  ([PR #71](https://github.com/Aymeric/ClinicalAssistant/pull/71)).

### Security and reliability

- Sanitize guideline consultation notes and limit their length to 5,000
  characters ([PR #68](https://github.com/Aymeric/ClinicalAssistant/pull/68)).
- Restrict exported guideline PDF file permissions to the current user
  ([PR #70](https://github.com/Aymeric/ClinicalAssistant/pull/70)).

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