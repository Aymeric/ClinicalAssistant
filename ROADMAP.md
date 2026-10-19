# Clinical Assistant Roadmap

This roadmap outlines the planned development milestones, feature expansions, and technical initiatives for Clinical Assistant. It aligns with the product principles documented in [PRODUCT.md](file:///Users/aymericgrassart/Documents/Repos/github.com/Aymeric/ClinicalAssistant/PRODUCT.md) and technical requirements in [README.md](file:///Users/aymericgrassart/Documents/Repos/github.com/Aymeric/ClinicalAssistant/README.md).

---

## Core Guiding Principles

All roadmap features must adhere to the foundational architecture of Clinical Assistant:
- **Patient Privacy & Local First**: Patient data remains encrypted on-device (AES-GCM). No mandatory cloud accounts, analytics tracking, or telemetry of health records.
- **Data Provenance & Fidelity**: Preserve original clinical values, units, timestamps, and FHIR resource payloads as received from sources.
- **Descriptive Analytics**: Trend tracking and pattern summaries are strictly descriptive; the app does not provide medical diagnoses or algorithmic clinical decision support.
- **Patient Agency**: Users control which sources to connect, what data to import or log, and what to export or share.
- **Open Standards First**: Built on HL7 FHIR (R4/R5), SMART on FHIR, LOINC, UCUM, and standard mobile health platform APIs (HealthKit, Health Connect).

---

## Milestone Overview & Release Cadence

| Version | Target Focus | Status |
| :--- | :--- | :--- |
| **v1.0** | Store readiness, provider presets, on-device AES-GCM vault, privacy governance | **In Progress (Hardening)** |
| **v1.1** | Conditions, Immunizations, Allergies, and LOINC terminology expansion | Planned (Near-Term) |
| **v1.2** | Grouped clinical lab panels, dual-metric correlation charts, medication schedules | Planned (Near-Term) |
| **v1.3** | Zero-knowledge encrypted backups, user-controlled private sync (WebDAV/iCloud/Drive) | Planned (Mid-Term) |
| **v1.4** | SMART Health Cards (SHC) & International Patient Summary (IPS) verification | Planned (Mid-Term) |
| **v2.0** | Direct BLE peripherals, continuous monitoring streams, multi-language localization | Future Considerations |

---

## Milestone 1: v1.0 Launch & Store Readiness (Current Phase)

Focus: Hardening current functionality, platform compliance, and production verification.

- [x] **Local Encrypted Record Store**: AES-GCM vault with keys stored in platform secure hardware keystore (`flutter_secure_storage`).
- [x] **Multi-Source Ingestion**:
  - [x] Apple HealthKit integration for shared measurements, vital signs, and clinical lab observations.
  - [x] Android Health Connect integration (with 10-year query windows and medical records experimental support).
  - [x] SMART-on-FHIR client for provider portal authorization and laboratory `Observation` imports.
- [x] **Manual Entry & Corrections**: Manual vitals logging (paired blood pressure, weight, glucose) and `MedicationStatement` entries.
- [x] **Analytics & Trends**: Numeric observation charts, source reference ranges, and optional 3-reading descriptive moving averages.
- [x] **Local Notifications & Sync**: Opt-in foreground sync (5-minute throttle) and threshold/directional alerts without leaking record values in system notifications.
- [x] **Export Capabilities**: Clean PDF doctor-visit summaries, FHIR JSON Bundles, and sanitized CSV exports.
- [x] **Curated Guidelines Library**: Offline directory and structured viewer for international clinical guidelines (NICE, USPSTF, WHO, etc.) with personal consultation notes.
- [x] **EHR Developer Portal Registrations & Sandbox Directory**:
  - [x] Curate developer gateway presets (SMART Health IT, Epic on FHIR Sandbox, Oracle Health / Cerner Millennium, Logica Health).
  - [x] Quick-preset selector in FHIR connection form with registration guidance and copyable OAuth redirect URI `com.cidevelop.clinicalAssistant:/oauth2redirect`.
- [x] **Release Infrastructure & Privacy**:
  - [x] Publish standalone, public-facing Privacy Policy ([PRIVACY.md](PRIVACY.md)) emphasizing local-only data retention and zero cloud telemetry.
  - [x] In-app Privacy & Data Governance view with health permissions rationale.
- [ ] **Store Review Submissions**:
  - [x] iOS: Configure HealthKit and Clinical Health Records entitlement capabilities (`Runner.entitlements`).
  - [x] Android: Health Connect permission declarations and `ACTION_SHOW_PERMISSIONS_RATIONALE` intent filters (`AndroidManifest.xml`).
  - [ ] iOS App Store submission with HealthKit human interface compliance and medical disclaimer verification.
  - [ ] Google Play Console declaration form and Data Safety form submission (declaring no data shared with third parties).
  - [ ] Complete end-to-end physical device testing matrix across iOS (16+) and Android (14+) physical hardware.

---

## Milestone 2: Clinical Data Expansion & Visit Preparation (Near-Term)

Focus: Expanding beyond lab observations to encompass broader clinical history, standardized medical terminologies, and visit workflows.

- [ ] **Expanded FHIR Resource Ingestion**:
  - [ ] **Conditions & Problem Lists (`Condition`)**:
    - Ingest active, inactive, and resolved health diagnoses from SMART-on-FHIR portals and Apple Health Clinical Records.
    - Track clinical status, verification status, onset date, and coded SNOMED CT / ICD-10 terminology.
  - [ ] **Immunizations (`Immunization`)**:
    - Ingest vaccination history with dose numbers, vaccination dates, target disease codes, and vaccine manufacturers / lot numbers.
  - [ ] **Allergies & Intolerances (`AllergyIntolerance`)**:
    - Record allergen substances (food, medication, environmental), reaction categories, critical severity badges, and manifestation notes.
  - [ ] **Procedures & Surgical History (`Procedure`)**:
    - Historical clinical procedures, surgical interventions, performed dates, and body sites.
  - [ ] **Diagnostic Reports & Clinical Documents (`DiagnosticReport`, `DocumentReference`)**:
    - Ingest diagnostic report summaries and embedded text notes (pathology summaries, radiology narrative impressions).
- [ ] **Standardized Terminology & Mapping**:
  - [ ] Offline LOINC (Logical Observation Identifiers Names and Codes) common dictionary to map obscure lab analyte codes to clear, patient-friendly test names.
  - [ ] UCUM (Unified Code for Units of Measure) standard normalization to allow clean comparison between equivalent units (e.g., `mg/dL` vs. `mmol/L` for blood glucose or cholesterol).
- [ ] **Enhanced Lab Panel Grouping**:
  - [ ] Automatically group related lab observations into standard clinical panels:
    - **Complete Blood Count (CBC)**: WBC, RBC, Hemoglobin, Hematocrit, Platelets, MCV, MCH, MCHC, RDW.
    - **Comprehensive Metabolic Panel (CMP)**: Sodium, Potassium, Chloride, CO2, BUN, Creatinine, eGFR, Glucose, Calcium, Total Protein, Albumin, Bilirubin, AST, ALT, Alkaline Phosphatase.
    - **Lipid Profile**: Total Cholesterol, HDL, LDL, Triglycerides, Non-HDL, TC/HDL Ratio.
    - **Thyroid Panel**: TSH, Free T4, Free T3.
    - **Glycemic Control**: Fasting Glucose, HbA1c, Estimated Average Glucose (eAG).
  - [ ] Longitudinal multi-analyte timeline comparisons and side-by-side table matrices across test dates.
  - [ ] Fasting vs. Postprandial state tagging for metabolic observations.
- [ ] **Medication Management Enhancements**:
  - [ ] Schedule recurring local medication reminders (with customizable schedules: daily, bid, tid, qid, PRN).
  - [ ] Log medication adherence history against prescribed regimens.
  - [ ] Discontinue / archive medications with reason annotations and date effective.
- [ ] **Doctor Visit Preparation Wizard**:
  - [ ] Step-by-step visit preparation flow: select recent out-of-range lab results, recent blood pressure/glucose trends, active medication questions, and personal agenda items.
  - [ ] Specialty-tailored PDF export templates (e.g., Cardiology, Endocrinology, Annual Wellness Examination).

---

## Milestone 3: Security, Portability & Zero-Knowledge Backup (Mid-Term)

Focus: Empowering patients with secure portability without compromising on-device isolation.

- [ ] **Zero-Knowledge Encrypted Backup & Restore**:
  - [ ] Passphrase-derived key derivation using Argon2id / PBKDF2 with SHA-256 (minimum 100,000 iterations).
  - [ ] Authenticated encrypted export archives (ChaCha20-Poly1305 or AES-GCM-256 with HMAC).
  - [ ] Support importing and restoring full archives across different devices and platforms.
- [ ] **User-Controlled Private Storage Integrations**:
  - [ ] Optional client-side encrypted sync using user-owned storage destinations without app-intermediary servers:
    - **WebDAV / Nextcloud**: Direct sync with patient's self-hosted private cloud.
    - **Apple iCloud Private Database**: Using CloudKit with client-side encrypted payloads (iOS/macOS).
    - **Google Drive AppData Folder**: Using user-authorized OAuth drive.appdata scope with local payload encryption prior to upload.
- [ ] **Local Peer-to-Peer Encrypted Transfer**:
  - [ ] Transfer encrypted vaults between personal devices over local Wi-Fi / Multipeer Connectivity (e.g., transferring records from an old phone to a new phone or tablet) without touching external networks.
- [ ] **SMART Health Cards & Verifiable Credentials**:
  - [ ] Display and parse SMART Health Cards (SHC) QR codes for immunizations and lab results.
  - [ ] Verify digital signatures against known issuer public key registries (VCI registry).
  - [ ] Generate verifiable SMART Health Card QR codes from imported provider immunization records.
- [ ] **Advanced Audit & Security Controls**:
  - [ ] Biometric app lock (Face ID / Touch ID / Android BiometricPrompt) on launch or return to foreground with custom grace period.
  - [ ] Detailed local audit log of data imports, exports, manual edits, and sync attempts.
  - [ ] Granular per-source data purge (e.g., delete records from a single provider or health platform without wiping the entire vault).

---

## Milestone 4: International Standards & Accessibility (Long-Term)

Focus: Cross-border patient mobility, accessible clinical visualizations, and inclusive design.

- [ ] **International Patient Summary (IPS) Standard**:
  - [ ] Export records compliant with the HL7 International Patient Summary (IPS) FHIR specification for international travel and cross-border clinical exchange.
  - [ ] Ingest foreign IPS patient summaries and translation of international unit representations.
- [ ] **Accessibility (a11y) & Neurodivergent-Friendly Design**:
  - [ ] Full screen-reader semantic trees (VoiceOver and TalkBack) for complex trend charts (providing audio graphs and tabular navigation of data series).
  - [ ] Dynamic Type and large typography scaling (support for up to 200% font scaling without layout clipping).
  - [ ] High-contrast color modes compliant with WCAG 2.2 AAA guidelines for laboratory reference range markers.
- [ ] **Multi-Language Localization**:
  - [ ] Full interface localization in Spanish, French, German, Italian, Portuguese, Japanese, and Simplified Chinese.
  - [ ] International date, number, and medical unit formatting standards.
- [ ] **Plain-Language Medical Glossary**:
  - [ ] Built-in offline glossary providing concise, neutral definitions for common clinical abbreviations (e.g., eGFR, AST/ALT, MCV, TSH, BUN) strictly for educational literacy without medical interpretation.

---

## Milestone 5: Peripherals, Continuous Monitoring & Research Ecosystem (Future Vision)

Focus: Direct hardware integration, high-frequency wearable data, and open research tooling.

- [ ] **Direct Bluetooth LE (BLE) Medical Devices**:
  - [ ] Pair directly with standard Bluetooth GATT health profile devices:
    - Bluetooth Blood Pressure Monitors (GATT Blood Pressure Service 0x1810).
    - Glucose Meters (GATT Glucose Service 0x1808).
    - Pulse Oximeters (GATT Pulse Oximeter Service 0x1822).
    - Weight Scales (GATT Weight Scale Service 0x181D).
  - [ ] Enables standalone hardware vitals tracking on devices without Google Play Services or Apple Health.
- [ ] **Continuous Monitoring & High-Frequency Streams**:
  - [ ] Enhanced aggregators for Continuous Glucose Monitoring (CGM) sensor streams.
  - [ ] Time-in-Range (TIR) descriptive distributions (Very Low, Low, Target, High, Very High) without clinical diagnosis.
  - [ ] Sleep architecture phase tracking (Deep, REM, Light, Awake) longitudinal distributions.
- [ ] **Synthetic Test Generator & Research Tooling**:
  - [ ] Built-in synthetic patient generator (compatible with Synthea FHIR datasets) for testing complex longitudinal cases and edge conditions offline.
  - [ ] Desktop companion app (macOS, Windows, Linux) utilizing the same Flutter codebase for patients and clinical researchers analyzing their own exported encrypted vaults locally.
- [ ] **Automated Clinical Guideline Catalog Verification**:
  - [ ] Automated CI/CD pipeline to verify guideline publisher catalog links and detect updated guideline versions.
  - [ ] Community-contributed guideline catalog extensions with strict clinical and evidence review standards.

---

## Feedback & Contributions

Suggestions, bug reports, and roadmap discussions can be submitted via GitHub Issues and Discussions. All contributions must uphold the project's strict commitment to patient privacy, local data storage, and descriptive clinical neutrality.
