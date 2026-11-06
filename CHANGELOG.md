# Changelog

## 0.6.0 - 2026-11-06

### Added

- **Medication Adherence Tracking & Proportion of Days Covered (PDC)**:
  - Support 'taken' and 'skipped' adherence statuses with quick-log actions directly on reminder notifications and medication cards ([#161](https://github.com/CIInc/ClinicalAssistant/issues/161)).
  - Proportion of Days Covered (PDC) engine evaluated across 30-, 60-, and 90-day rolling observation windows against the clinical benchmark (>=80% threshold) ([#161](https://github.com/CIInc/ClinicalAssistant/issues/161)).
  - Interactive monthly adherence calendar and detailed PDC breakdown sheet for each active medication ([#161](https://github.com/CIInc/ClinicalAssistant/issues/161)).
  - Integrated 30-day PDC adherence metrics into Doctor Visit Preparation smart suggestions, wizard step 3, and PDF consultation export summaries ([#161](https://github.com/CIInc/ClinicalAssistant/issues/161)).
- **Dual-Unit Lab Normalization (US Conventional vs. International SI Units)**:
  - High-precision bidirectional UCUM unit conversion for core clinical analytes: Blood Glucose (`mg/dL` ↔ `mmol/L`), Total/HDL/LDL Cholesterol & Triglycerides (`mg/dL` ↔ `mmol/L`), Serum Creatinine (`mg/dL` ↔ `µmol/L`), Total Bilirubin (`mg/dL` ↔ `µmol/L`), Calcium (`mg/dL` ↔ `mmol/L`), BUN (`mg/dL` ↔ `mmol/L`), Albumin & Total Protein (`g/dL` ↔ `g/L`), and Serum Electrolytes (`mEq/L` ↔ `mmol/L`) ([#160](https://github.com/CIInc/ClinicalAssistant/issues/160)).
  - Persistent user preference for Preferred Lab Unit System (`US Conventional` vs. `International SI`) configurable via Connections settings and saved securely in `SyncValueStore` ([#160](https://github.com/CIInc/ClinicalAssistant/issues/160)).
  - Unification of disjointed multi-unit records into a single continuous longitudinal trend chart normalized to the user's preferred unit system, preserving raw underlying source payloads and provenance ([#160](https://github.com/CIInc/ClinicalAssistant/issues/160)).
  - Dual-unit tooltips, calculated secondary equivalents, and converted reference ranges on chart scrubbing banners, reading headings, and record details sheets ([#160](https://github.com/CIInc/ClinicalAssistant/issues/160)).

### Changed

- Enhanced Google Play release pipeline to default release distribution to all non-production tracks (`internal,alpha,beta`) simultaneously for comprehensive pre-release validation.

### Performance and reliability

- Optimized cardiac rhythm metric aggregation (`Bolt`): replaced repeated `RegExp` pattern instantiations with fast-path numeric parsing and a hoisted pattern, and replaced intermediate allocations with single-pass metric accumulation ([#171](https://github.com/CIInc/ClinicalAssistant/issues/171)).
- Safely guarded notification platform initialization in headless and test environments to prevent unhandled late initialization errors.

## 0.5.0 - 2026-11-01

### Added

- **Cardiovascular Health Module**:
  - ACC/AHA 2017 blood pressure clinical staging (Normal, Elevated, Stage 1, Stage 2, Hypertensive Crisis) with non-diagnostic observational context chips ([#82](https://github.com/Aymeric/ClinicalAssistant/issues/82)).
  - Blood pressure measurement context tracking: posture (sitting, standing, supine), arm (left vs. right), cuff type, and resting minutes persisted in vault entries ([#82](https://github.com/Aymeric/ClinicalAssistant/issues/82)).
  - Diurnal blood pressure surge comparison (morning vs. evening averages) on combined blood pressure trend views ([#82](https://github.com/Aymeric/ClinicalAssistant/issues/82)).
  - Longitudinal Heart Rhythm & Rate analysis card comparing resting heart rate, walking average, and workout peak rates with Heart Rate Variability (HRV / SDNN) metrics ([#82](https://github.com/Aymeric/ClinicalAssistant/issues/82)).
  - Irregular rhythm notification history log and walking heart rate ingestion from Apple Health and Health Connect ([#82](https://github.com/Aymeric/ClinicalAssistant/issues/82)).
- **Medication Management & Interaction Safety**:
  - Recurring local medication reminders with customizable interval and daily time schedules ([#77](https://github.com/Aymeric/ClinicalAssistant/issues/77)).
  - Offline drug-drug and food-drug interaction safety checker with severity alerts and clinical interaction mechanisms ([#77](https://github.com/Aymeric/ClinicalAssistant/issues/77)).
  - Support for medication discontinuation tracking with structured reasons and effective cessation dates ([#77](https://github.com/Aymeric/ClinicalAssistant/issues/77)).
- **Patient-Reported Outcome Measures (PROMs)**:
  - Standardized validated health questionnaires (PHQ-9 depression screening, GAD-7 anxiety screening, CAT COPD assessment, and HAQ-DI functional disability) with automated severity scoring, question drilldowns, and longitudinal trend charting ([#76](https://github.com/Aymeric/ClinicalAssistant/issues/76)).
- **Structured Symptoms Log & Timeline Overlays**:
  - Dedicated symptom logging with severity scale (Mild, Moderate, Severe), body system categorization, and contextual notes ([#156](https://github.com/Aymeric/ClinicalAssistant/issues/156)).
  - Interactive symptom timeline overlays on numeric trend charts for visual correlation against lab and vital measurements ([#156](https://github.com/Aymeric/ClinicalAssistant/issues/156)).
- **Terminology Mapping & Cross-Provider Deduplication**:
  - Bundled offline LOINC dictionary with descriptive UCUM unit conversion and canonical terminology mappings ([#78](https://github.com/Aymeric/ClinicalAssistant/issues/78)).
  - Intelligent cross-provider record reconciliation and duplicate detection for identical observations from multiple sources ([#78](https://github.com/Aymeric/ClinicalAssistant/issues/78)).
- **FHIR Surgical & Clinical Procedure Ingestion**:
  - Ingestion of past surgical procedures and interventions (`Procedure`) from SMART-on-FHIR endpoints and FHIR JSON files into the encrypted vault, complete with SNOMED CT / CPT coding and consultation summary inclusions ([#74](https://github.com/Aymeric/ClinicalAssistant/issues/74)).

### Changed

- Expanded manual record entry dropdown menus with full width and ellipsis handling to prevent layout clipping on compact mobile screens.
- Enforced a 30-second network timeout on external SMART-on-FHIR portal requests to prevent unresponsive endpoints from hanging sync ([#159](https://github.com/Aymeric/ClinicalAssistant/issues/159)).

### Security and reliability

- Enforced AES-GCM MAC tag validation and fail-fast backup verification during vault restoration ([#153](https://github.com/Aymeric/ClinicalAssistant/issues/153)).
- Restricted file permissions on exported consultation PDF directories (`chmod 0700`) and recovered vault files on POSIX systems ([#144](https://github.com/Aymeric/ClinicalAssistant/issues/144), [#149](https://github.com/Aymeric/ClinicalAssistant/issues/149)).
- Redacted Bearer tokens and authorization credentials from import failure summaries ([#146](https://github.com/Aymeric/ClinicalAssistant/issues/146)).
- Early bounds validation in PIN verification preventing CPU exhaustion ([#141](https://github.com/Aymeric/ClinicalAssistant/issues/141)).
- Optimized lab result summarization with single-pass latest record tracking and pre-filtered signal keys ([#124](https://github.com/Aymeric/ClinicalAssistant/issues/124), [#143](https://github.com/Aymeric/ClinicalAssistant/issues/143)).

### Usability and accessibility

- Added accessible tooltips and radio semantics to Doctor Visit specialty tiles, medication log count chips, guideline viewer controls, and export date presets ([#148](https://github.com/Aymeric/ClinicalAssistant/issues/148), [#151](https://github.com/Aymeric/ClinicalAssistant/issues/151), [#154](https://github.com/Aymeric/ClinicalAssistant/issues/154), [#158](https://github.com/Aymeric/ClinicalAssistant/issues/158)).

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