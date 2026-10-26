# Clinical Assistant Roadmap

This roadmap outlines the strategic development milestones, feature expansions, clinical domain modules, and technical architecture initiatives for Clinical Assistant. It directly aligns with the product principles documented in [PRODUCT.md](PRODUCT.md) and technical requirements in [README.md](README.md).

---

## Core Guiding Principles

All roadmap features and architectural decisions must strictly adhere to the foundational tenets of Clinical Assistant:
- **Patient Privacy & Local First**: Patient data remains encrypted on-device (AES-GCM 256-bit). The app operates zero centralized servers, collects zero behavioral telemetry, and has no mandatory cloud accounts.
- **Data Provenance & Clinical Fidelity**: Preserve original clinical values, units, timestamps, reference ranges, and FHIR resource payloads exactly as received from sources.
- **Descriptive Analytics & Diagnostic Neutrality**: Trend tracking, reference range comparisons, and pattern indicators are purely descriptive. The app does not provide automated clinical diagnosis, algorithmic risk triage, or unverified medical advice.
- **Patient Agency & Data Sovereignty**: Users retain sole ownership of their records, deciding which sources to connect, what to import, what to log manually, and when to export, share, or cryptographically erase.
- **Open Standards First**: Built on HL7 FHIR (R4/R5), SMART on FHIR, LOINC, SNOMED CT, UCUM, and native mobile health APIs (Apple HealthKit, Google Health Connect).

---

## Milestone Overview & Release Cadence

| Version | Focus | Primary Deliverables | Target Horizon |
| :--- | :--- | :--- | :--- |
| **v1.0** | **Store Readiness & Hardening** | On-device AES-GCM vault, HealthKit / Health Connect ingestion, SMART-on-FHIR presets, standalone privacy policy | **Current Phase** |
| **v1.1** | **Clinical Scope & Document OCR** | `Condition`, `Immunization`, `AllergyIntolerance`, `Procedure`, offline paper lab OCR, Rx bottle barcode scanner | Near-Term |
| **v1.2** | **Lab Panels, PROMs & Drug Interactions** | Grouped clinical panels (CBC, CMP, Lipid), survey scales (PHQ-9, GAD-7), offline drug-drug & food-drug interaction check | Near-Term |
| **v1.3** | **Zero-Knowledge Portability & Backup** | Argon2id encrypted backups, private cloud sync (WebDAV, Nextcloud, iCloud, Google Drive), Shamir's ICE keys | Mid-Term |
| **v1.4** | **Specialized Clinical Domains** | AHA/ACC blood pressure staging, CGM Ambulatory Glucose Profiles (AGP), CKD/eGFR staging, mobility biomarkers | Mid-Term |
| **v1.5** | **Caregiver Modes & In-Clinic Share** | Multi-profile family vaults, pediatric schedules, ephemeral local Wi-Fi / QR clinician web dashboard | Mid-Term |
| **v2.0** | **Global Interop & Pharmacogenomics** | International Patient Summary (IPS), SMART Health Cards (SHC), Apple/Google Wallet passes, offline CPIC PGx guidance | Long-Term |
| **v2.1** | **Direct BLE Devices & Watch Apps** | Bluetooth GATT direct pairing (cuffs, glucometers, scales), Apple Watch & Wear OS standalone logging companions | Long-Term |
| **v2.2** | **Medical Imaging, Sleep & Lifeline** | Local DICOM viewer (MRI/CT/X-Ray), multi-track clinical lifeline, sleep architecture, complex titration regimens, Advance Directives (POLST) | Long-Term |
| **v2.3+** | **Private On-Device AI & Research** | On-device SLM (Gemini Nano / MediaPipe) clinical note translation, private ClinicalTrials matching, desktop app | Future Vision |

---

## Milestone 1: v1.0 Launch & Store Readiness (Current Phase)

Focus: Hardening current functionality, platform compliance, security review, and physical device verification.

- [x] **Local Encrypted Record Store**:
  - [x] AES-GCM local database encryption with keys held in platform secure hardware keystore (`flutter_secure_storage`).
  - [x] On-demand complete cryptographic wipe ("Delete all records") clearing database, keys, and saved tokens.
- [x] **Multi-Source Ingestion**:
  - [x] Apple HealthKit integration for shared measurements, vital signs, and clinical lab observations.
  - [x] Android Health Connect integration (with 10-year query windows and medical records experimental support).
  - [x] SMART-on-FHIR client for provider portal authorization and laboratory `Observation` imports.
- [x] **Manual Entry & Corrections**:
  - [x] Manual vitals logging (paired blood pressure, weight, glucose, heart rate) with timestamp editing.
  - [x] Medication logging with dosage, route, frequency, and export as FHIR `MedicationStatement` resources.
- [x] **Analytics & Trends**:
  - [x] Numeric observation charts, source reference ranges, and optional 3-reading descriptive moving averages.
- [x] **Local Notifications & Sync**:
  - [x] Opt-in foreground sync (5-minute throttle) and threshold/directional alerts without leaking record values in system notifications.
- [x] **Export Capabilities**:
  - [x] Clean PDF doctor-visit summaries, FHIR JSON Bundles, and sanitized CSV exports with formula injection mitigation.
- [x] **Curated Guidelines Library**:
  - [x] Offline directory and structured viewer for international clinical guidelines (NICE, USPSTF, WHO, etc.) with personal consultation notes.
- [x] **EHR Developer Portal Registrations & Sandbox Directory**:
  - [x] Curate developer gateway presets (SMART Health IT, Epic on FHIR Sandbox, Oracle Health / Cerner Millennium, Logica Health).
  - [x] Quick-preset selector in FHIR connection form with registration guidance and copyable OAuth redirect URI `com.aymericgrassart.clinicalassistant:/oauth2redirect`.
- [x] **Release Infrastructure & Privacy**:
  - [x] Standalone, public-facing Privacy Policy ([PRIVACY.md](PRIVACY.md)) emphasizing local-only data retention and zero cloud telemetry.
  - [x] In-app Privacy & Data Governance view with health permissions rationale.
- [ ] **Store Review Submissions** ([#73](https://github.com/Aymeric/ClinicalAssistant/issues/73)):
  - [x] iOS: Configure HealthKit and Clinical Health Records entitlement capabilities (`Runner.entitlements`).
  - [x] Android: Health Connect permission declarations and `ACTION_SHOW_PERMISSIONS_RATIONALE` intent filters (`AndroidManifest.xml`).
  - [ ] iOS App Store submission with HealthKit human interface compliance and medical disclaimer verification.
  - [ ] Google Play Console declaration form and Data Safety form submission (declaring no data shared with third parties).
  - [ ] Complete end-to-end physical device testing matrix across iOS (16+) and Android (14+) physical hardware.

---

## Milestone 2: Clinical Scope, OCR, PROMs & Medication Safety (Near-Term)

Focus: Expanding beyond lab observations to encompass broader clinical history, paper document ingestion, standardized survey instruments, cross-provider reconciliation, and medication safety checks.

- [ ] **Expanded FHIR Resource Ingestion** ([#74](https://github.com/Aymeric/ClinicalAssistant/issues/74)):
  - [ ] **Conditions & Diagnoses (`Condition`)**:
    - Ingest active, inactive, and resolved problem lists from SMART-on-FHIR portals and Apple Health Clinical Records.
    - Track clinical status, verification status, onset date, and coded SNOMED CT / ICD-10-CM terminology.
  - [ ] **Immunizations (`Immunization`)**:
    - Ingest vaccination history with dose numbers, vaccination dates, target disease codes, and vaccine manufacturers / lot numbers.
    - Track vaccine status (completed, not-done) and route of administration.
  - [ ] **Allergies & Intolerances (`AllergyIntolerance`)**:
    - Record allergen substances (food, medication, environmental), reaction categories, critical severity badges, and manifestation notes.
    - Highlight high-risk anaphylaxis manifestations prominently.
  - [ ] **Procedures & Interventions (`Procedure`)**:
    - Historical clinical procedures, surgical interventions, performed dates, and body sites.
  - [ ] **Diagnostic Reports & Clinical Documents (`DiagnosticReport`, `DocumentReference`)**:
    - Ingest diagnostic report summaries and embedded text notes (pathology summaries, radiology narrative impressions).
- [ ] **Direct FHIR JSON File Import** ([#118](https://github.com/Aymeric/ClinicalAssistant/issues/118)):
  - Select a local FHIR JSON file and preview the supported resource count before importing, reusing the existing parser and record-merge path.
  - Preserve original resource data and provenance; process files locally, validate before saving, and report malformed or unsupported input without a partial import.
- [x] **Per-Source Import History and Coverage** ([#119](https://github.com/Aymeric/ClinicalAssistant/issues/119)):
  - Show local import and sync outcomes, last checked time, returned record counts, and observed date coverage for each source.
  - Distinguish successful empty results from failures, and make clear that observed date spans do not guarantee complete source history.
- [ ] **FHIR Export Preflight** ([#120](https://github.com/Aymeric/ClinicalAssistant/issues/120)):
  - Validate exported Bundles against a declared supported FHIR release/profile and summarize included resources and warnings before sharing.
  - Keep validation local, preserve source records, and avoid implying universal provider acceptance.
- [ ] **Grouped Clinical Lab Panels & Multi-Analyte Entry** ([#130](https://github.com/Aymeric/ClinicalAssistant/issues/130)):
  - Preserve FHIR panel membership (`Observation.hasMember`, `DiagnosticReport.result`, or standard LOINC panel codes) and group same-source, same-timestamp panel analytes (such as CBC, CMP, BMP, Lipid, and Thyroid panels) in the records list and PDF summaries.
  - Provide collapsible panel headers showing panel name, date, source, analyte count, and out-of-range summary while expanding to individual analyte rows and source reference ranges.
  - Support multi-analyte panel entry in a single manual form while saving each analyte as a distinct record so individual analyte trend series continue to work unchanged.
- [x] **Source-Scoped Exports & Privacy Redaction Controls** ([#131](https://github.com/Aymeric/ClinicalAssistant/issues/131)):
  - Expose source selection and measurement search filtering on the Export screen so patients can scope exports to chosen sources and measurements.
  - Provide explicit privacy toggles to include or omit personal record notes and raw `sourceData` JSON payloads in CSV, PDF, text, and FHIR exports without altering stored vault data.
  - Default-exclude or prominently warn when synthetic demonstration records are present so demo data is not inadvertently shared in clinical exports.
- [ ] **Fasting & Measurement Context Filtering in Lab and Vital Trends** ([#132](https://github.com/Aymeric/ClinicalAssistant/issues/132)):
  - Preserve structured measurement and meal-state context tags (such as `Fasting`, `Pre-meal`, `Post-meal (2 hr)`, `Bedtime`, `Random`, or `Unspecified`) from manual entry and supported source metadata without modifying original record values.
  - Filter trend series by context in `HealthTrendsPage` so descriptive summary statistics (`average`, `minimum`, `maximum`, and `3-reading average`) and range-relative evaluations compare like-for-like readings.
- [ ] **Medication Start/Stop Markers on Single-Series Trend Charts** ([#133](https://github.com/Aymeric/ClinicalAssistant/issues/133)):
  - Add an opt-in `Medication dates` toggle on `TrendChartPanel` to overlay vertical date markers for recorded medication start and end dates within the active chart time window.
  - Present chronological medication markers with accessible text summaries and strictly descriptive copy that does not imply treatment efficacy or clinical causation.
- [ ] **On-Device OCR & Physical Document Ingestion** ([#75](https://github.com/Aymeric/ClinicalAssistant/issues/75)):
  - [ ] **Paper Lab Report Scanner (Apple Vision / Google ML Kit)**:
    - Capture or import photo/PDF scans of printed lab reports (Quest, Labcorp, regional hospital printouts) and extract structured tabular values strictly on-device.
    - **Human-in-the-Loop Verification**: Side-by-side verification interface highlighting bounding boxes on the original scan against parsed fields before saving to the vault.
  - [ ] **Prescription Bottle Barcode & Label Scanner**:
    - Scan National Drug Code (NDC) barcodes or prescription bottle label text to auto-populate medication name, strength, formulation, and instructions using an offline, bundled RxNorm / FDA NDC lookup index.
- [ ] **Patient-Reported Outcome Measures (PROMs) & Questionnaires** ([#76](https://github.com/Aymeric/ClinicalAssistant/issues/76)):
  - [ ] Standardized clinical survey instruments:
    - **PHQ-9**: Patient Health Questionnaire for depression screening.
    - **GAD-7**: Generalized Anxiety Disorder assessment.
    - **CAT & mMRC**: COPD Assessment Test and Dyspnea scales.
    - **SF-12 / HAQ**: Functional health status and quality-of-life questionnaires.
  - [ ] Ingest and export responses as standard FHIR `Questionnaire` and `QuestionnaireResponse` resources.
  - [ ] Longitudinal survey score tracking plotted directly alongside medications and biometric trends.
- [ ] **Medication Management & Interaction Safety** ([#77](https://github.com/Aymeric/ClinicalAssistant/issues/77)):
  - [ ] **Offline Drug-Drug & Food-Drug Interaction Checker**:
    - Bundled offline open pharmacology interaction dataset (open FDA / RxNorm / open DrugBank data).
    - Automatically flags known interactions between active logged medications (e.g., NSAIDs + ACE inhibitors; Potassium + Spironolactone).
    - Highlights common dietary interactions (e.g., Grapefruit juice with Statins; high-Vitamin K foods with Warfarin).
    - Descriptive safety prompts instructing patients to discuss warnings with their pharmacist or physician.
  - [ ] Schedule recurring local medication reminders (with customizable schedules: daily, bid, tid, qid, PRN).
  - [ ] Log medication adherence history against prescribed regimens.
  - [ ] Discontinue / archive medications with reason annotations and date effective.
- [ ] **Standardized Terminology, Mapping & Deduplication** ([#78](https://github.com/Aymeric/ClinicalAssistant/issues/78)):
  - [ ] **Cross-Provider Record Reconciliation**:
    - Intelligently detects duplicate tests across multiple provider portals (e.g., same lipid panel reported by both hospital portal and lab service on the same date).
    - Groups equivalent readings into a unified longitudinal timeline while retaining all original source document links and provenance.
  - [ ] Offline LOINC (Logical Observation Identifiers Names and Codes) dictionary to map obscure lab analyte codes to clear, patient-friendly test names.
  - [ ] UCUM (Unified Code for Units of Measure) standard normalization to allow clean comparison between equivalent units (e.g., `mg/dL` vs. `mmol/L` for blood glucose or cholesterol).
- [ ] **Clinical Safety & Critical Value Red-Flag Alerts** ([#79](https://github.com/Aymeric/ClinicalAssistant/issues/79)):
  - [ ] High-visibility emergency caution banners when newly entered or imported vitals cross consensus critical red-flag thresholds:
    - *Hypertensive Crisis*: Systolic $\ge 180$ mmHg and/or Diastolic $\ge 120$ mmHg.
    - *Severe Hypoglycemia*: Blood glucose $< 54$ mg/dL ($< 3.0$ mmol/L).
    - *Severe Hypoxemia*: $SpO_2 < 88\%$.
  - [ ] Prompts immediate emergency care or physician contact without automated clinical triage assertions.
- [ ] **Multi-Modal Hands-Free Input** ([#80](https://github.com/Aymeric/ClinicalAssistant/issues/80)):
  - [ ] **Offline Voice Logging**:
    - On-device speech recognition (Apple Speech framework / Android On-Device Speech Recognizer) for voice logging vitals: *"Blood pressure 128 over 82, pulse 70"* parsed into structured paired records.
- [ ] **Doctor Visit Preparation Wizard** ([#81](https://github.com/Aymeric/ClinicalAssistant/issues/81)):
  - [ ] Step-by-step visit preparation flow: select recent out-of-range lab results, recent blood pressure/glucose trends, active medication questions, and personal agenda items.
  - [ ] Specialty-tailored PDF export templates (e.g., Cardiology, Endocrinology, Annual Wellness Examination).

---

## Milestone 3: Specialized Clinical Domain Modules & Digital Biomarkers (Mid-Term)

Focus: Purpose-built longitudinal visualizations for high-impact chronic conditions, mobility biomarkers, and environmental trigger correlation.

- [ ] **Cardiovascular Health Module** ([#82](https://github.com/Aymeric/ClinicalAssistant/issues/82)):
  - [ ] **Blood Pressure Staging Visualization**:
    - Descriptive classification matching AHA/ACC 2017 clinical guidelines (Normal, Elevated, Stage 1, Stage 2, Hypertensive Crisis) as visual context only.
    - Contextual metadata tracking: measurement posture (sitting, standing, supine), arm (left vs. right), cuff type, and resting period.
    - Morning vs. Evening blood pressure surge comparison charts.
  - [ ] **Heart Rhythm & Rate Longitudinal Analysis**:
    - Resting heart rate vs. walking average vs. workout peaks.
    - Heart Rate Variability (HRV / SDNN / rMSSD) longitudinal trends.
    - Irregular rhythm notification history log imported from Apple Health / Health Connect.
- [ ] **Metabolic & Endocrine (Glycemic & Weight Management)** ([#83](https://github.com/Aymeric/ClinicalAssistant/issues/83)):
  - [ ] **Continuous Glucose Monitoring (CGM) & AGP Analysis**:
    - Ambulatory Glucose Profile (AGP) metrics conforming to international consensus guidelines:
      - Glucose Management Indicator (GMI).
      - Glycemic Variability: Coefficient of Variation (%CV, target $\le 36\%$) and Standard Deviation (SD).
      - Time-in-Range (TIR: 70–180 mg/dL / 3.9–10.0 mmol/L).
      - Time-Below-Range (TBR Level 1: 54–69 mg/dL; TBR Level 2: $<54$ mg/dL).
      - Time-Above-Range (TAR Level 1: 181–250 mg/dL; TAR Level 2: $>250$ mg/dL).
  - [ ] **Body Composition Trends**:
    - Longitudinal charting of Weight, BMI, Body Fat %, Lean Body Mass, and Waist Circumference.
    - Correlation overlays: Weight vs. Blood Pressure, Steps vs. Resting Heart Rate.
- [ ] **Renal, Hepatic & Hematology Modules** ([#84](https://github.com/Aymeric/ClinicalAssistant/issues/84)):
  - [ ] **Kidney Health Tracking**:
    - eGFR trend tracking using the race-free CKD-EPI 2021 equation.
    - Serum Creatinine and Urine Albumin-to-Creatinine Ratio (uACR) longitudinal staging.
  - [ ] **Liver Function Assessment**:
    - AST/ALT ratio calculations, Alkaline Phosphatase, and Total Bilirubin.
    - FIB-4 (Fibrosis-4) index calculation for non-invasive liver health exploration.
  - [ ] **Anemia & Iron Studies**:
    - Longitudinal iron panel tracking: Serum Iron, Total Iron Binding Capacity (TIBC), Transferrin Saturation %, and Ferritin.
- [ ] **Digital Biomarkers & Mobility** ([#85](https://github.com/Aymeric/ClinicalAssistant/issues/85)):
  - [ ] **Gait & Stability Metrics**:
    - Walking speed, step asymmetry percentage, and double-support time from HealthKit / Health Connect to display mobility stability trends over time (valuable for surgical recovery, elder care, and physical therapy).
- [ ] **Environmental Trigger Overlays** ([#86](https://github.com/Aymeric/ClinicalAssistant/issues/86)):
  - [ ] Ephemeral download of regional Air Quality Index (AQI), pollen counts, and barometric pressure trends to allow patients to correlate environmental triggers with asthma flare-ups, migraines, or blood pressure swings without persisting location data.
- [ ] **Pulmonary & Respiratory Health** ([#87](https://github.com/Aymeric/ClinicalAssistant/issues/87)):
  - [ ] Oxygen Saturation ($SpO_2$) daytime spot-checks vs. nocturnal nadir tracking.
  - [ ] Peak Expiratory Flow (PEF) and $FEV_1$ tracking for asthma and COPD patients.
- [ ] **Women's Health & Cycle Tracking** ([#88](https://github.com/Aymeric/ClinicalAssistant/issues/88)):
  - [ ] Menstrual cycle length and period duration variability tracking.
  - [ ] Basal Body Temperature (BBT) biphasic temperature shift charting.
  - [ ] Ovulation test kit (LH surge) results and cervical mucus observations.

---

## Milestone 4: Security, Portability & In-Clinic Clinician Share (Mid-Term)

Focus: Empowering patients with secure portability, zero-knowledge sync, emergency trustee recovery, and peer-to-peer clinician consultation.

- [ ] **Zero-Knowledge Encrypted Backup & Restore** ([#89](https://github.com/Aymeric/ClinicalAssistant/issues/89)):
  - [ ] Passphrase-derived key derivation using Argon2id / PBKDF2 with SHA-256 (minimum 100,000 iterations).
  - [ ] Authenticated encrypted export archives (ChaCha20-Poly1305 or AES-GCM-256 with HMAC).
  - [ ] Support importing and restoring full archives across different devices and platforms.
- [ ] **User-Controlled Private Storage Integrations** ([#90](https://github.com/Aymeric/ClinicalAssistant/issues/90)):
  - [ ] Optional client-side encrypted sync using user-owned storage destinations without app-intermediary servers:
    - **WebDAV / Nextcloud**: Direct sync with patient's self-hosted private cloud.
    - **Apple iCloud Private Database**: Using CloudKit with client-side encrypted payloads (iOS/macOS).
    - **Google Drive AppData Folder**: Using user-authorized OAuth `drive.appdata` scope with local payload encryption prior to upload.
- [ ] **Ephemeral In-Clinic Clinician Share (Local Web Server / QR Handshake)** ([#91](https://github.com/Aymeric/ClinicalAssistant/issues/91)):
  - [ ] On-demand "Present to Clinician" button that spins up an ephemeral, local HTTP web server on the patient's device with a one-time 6-digit PIN and dynamic QR code.
  - [ ] Doctor scans the QR code from their clinic tablet/computer browser on the same local network or ad-hoc Wi-Fi hotspot to view an interactive, clean summary dashboard.
  - [ ] Zero cloud transmission; data streams strictly peer-to-peer and terminates permanently the moment the patient taps "End Session".
- [ ] **Emergency Trustee Access (Shamir's Secret Sharing)** ([#92](https://github.com/Aymeric/ClinicalAssistant/issues/92)):
  - [ ] Cryptographically splits the vault backup recovery key into a $k$-of-$n$ Shamir's Secret Sharing scheme (e.g., 2-of-3 split between trusted family members or medical power of attorney).
  - [ ] Grants designated trustees emergency access in incapacitating medical events without creating cloud backdoors.
- [ ] **SMART Health Cards & Wallet Passes** ([#93](https://github.com/Aymeric/ClinicalAssistant/issues/93)):
  - [ ] Display and parse SMART Health Cards (SHC) QR codes for immunizations and lab results.
  - [ ] Verify digital signatures against known issuer public key registries (VCI registry).
  - [ ] Generate Apple Wallet (`.pkpass`) and Google Wallet health passes for offline presentation of verified credentials.
- [ ] **Advanced Audit & Security Controls** ([#94](https://github.com/Aymeric/ClinicalAssistant/issues/94)):
  - [ ] Biometric app lock (Face ID / Touch ID / Android BiometricPrompt) on launch or return to foreground with custom grace period.
  - [ ] Detailed local audit log of data imports, exports, manual edits, and sync attempts.
  - [ ] Granular per-source data purge (e.g., delete records from a single provider or health platform without wiping the entire vault).

---

## Milestone 5: Caregiver Modes, Family Profiles & Emergency Medical ID (Mid-Term)

Focus: Supporting multi-generational health record management while maintaining strict privacy boundaries.

- [ ] **Multi-Profile Family Vault Architecture** ([#95](https://github.com/Aymeric/ClinicalAssistant/issues/95)):
  - [ ] Support distinct isolated local vaults for dependents (e.g., aging parents, pediatric children, spouse).
  - [ ] Independent encryption keys and pin/passcodes per profile.
  - [ ] Quick switching between profiles with visual theme distinctions to prevent accidental data entry in the wrong profile.
- [ ] **Pediatric Health & Immunization Schedules** ([#96](https://github.com/Aymeric/ClinicalAssistant/issues/96)):
  - [ ] Growth percentiles charting (WHO Child Growth Standards and CDC Growth Charts: Height, Weight, Head Circumference).
  - [ ] CDC / WHO pediatric immunization milestone schedule tracker.
- [ ] **Emergency Medical ID & Lock Screen Card** ([#97](https://github.com/Aymeric/ClinicalAssistant/issues/97)):
  - [ ] Dedicated Emergency Medical ID profile view:
    - Blood type, critical medical conditions, severe allergies, active medications, emergency contacts, organ donor status.
  - [ ] Formatted wallet-sized printable PDF card for physical emergency carry.
  - [ ] Direct export of Emergency Medical ID summary to Apple Health Medical ID.

---

## Milestone 6: International Patient Summary, C-CDA & Pharmacogenomics (Long-Term)

Focus: Cross-border patient mobility, legacy document ingestion, and evidence-based pharmacogenomics.

- [ ] **HL7 International Patient Summary (IPS) Compliance** ([#98](https://github.com/Aymeric/ClinicalAssistant/issues/98)):
  - [ ] Export records compliant with the HL7 International Patient Summary (IPS) FHIR specification for international travel and cross-border clinical exchange.
  - [ ] Ingest foreign IPS patient summaries and translate international medical terminology (e.g., mapping Canadian, UK, or EU coding systems to local displays).
- [ ] **HL7 CDA / C-CDA 2.1 Document Ingestion** ([#99](https://github.com/Aymeric/ClinicalAssistant/issues/99)):
  - [ ] Ingest Continuity of Care Documents (CCD) and clinical summaries in XML-based C-CDA 2.1 format from legacy hospital patient portals.
  - [ ] Extract structured sections: Medications, Allergies, Problems, Results, and Immunizations.
- [ ] **Pharmacogenomics (PGx) & Drug-Gene Compatibility Guidance** ([#100](https://github.com/Aymeric/ClinicalAssistant/issues/100)):
  - [ ] Ingest raw genomic callsets (VCF files or 23andMe / AncestryDNA TSV exports) into the encrypted local vault.
  - [ ] Offline CPIC (Clinical Pharmacogenetics Implementation Consortium) guideline matching:
    - Cross-references patient's logged medications against validated gene-drug interactions (e.g., CYP2C19 & Clopidogrel; CYP2D6 & Codeine; SLCO1B1 & Simvastatin).
    - Surfaces neutral, evidence-based educational considerations for patients to discuss with their prescribing physician.
- [ ] **Direct Regional Public Health Integrations** ([#101](https://github.com/Aymeric/ClinicalAssistant/issues/101)):
  - [ ] **CMS Blue Button 2.0 (USA)**: Ingest historical Medicare Part A, B, and D claims and health encounters for US Medicare beneficiaries.
  - [ ] **VA Lighthouse API (USA)**: Secure SMART-on-FHIR connector for US Department of Veterans Affairs health records.
  - [ ] **My Health Record (Australia)**: Alignment with Australian Digital Health Agency (ADHA) FHIR gateway specifications.
  - [ ] **NHS App Open APIs (UK)**: Alignment with NHS England patient access guidelines.

---

## Milestone 7: Direct Medical Peripherals (BLE) & Smart Watch Apps (Long-Term)

Focus: Standalone hardware interop independent of platform health stores and glanceable wrist companions.

- [ ] **Direct Bluetooth LE (BLE) Medical Devices** ([#102](https://github.com/Aymeric/ClinicalAssistant/issues/102)):
  - [ ] Pair directly with standard Bluetooth SIG GATT health profile devices:
    - **Blood Pressure Monitors**: GATT Blood Pressure Service (`0x1810`) and Blood Pressure Measurement characteristic (`0x2A35`).
    - **Glucose Meters**: GATT Glucose Service (`0x1808`) and Glucose Measurement characteristic (`0x2A18`).
    - **Pulse Oximeters**: GATT Pulse Oximeter Service (`0x1822`) and Continuous Measurement characteristic (`0x2A5F`).
    - **Weight Scales**: GATT Weight Scale Service (`0x181D`) and Weight Measurement characteristic (`0x2A98`).
  - [ ] Direct pairing provides hardware access on devices lacking Apple Health or Google Play / Health Connect services (e.g., de-Googled Android, custom distributions).
- [ ] **Apple Watch & Wear OS Native Companion Apps** ([#103](https://github.com/Aymeric/ClinicalAssistant/issues/103)):
  - [ ] Lightweight standalone wrist companions for 1-tap medication adherence and quick vitals logging.
  - [ ] Complications & Tiles displaying next scheduled dose and today's adherence ring.
  - [ ] Secure direct peer-to-peer watch-to-phone sync via `WatchConnectivity` (iOS) and `Wearable Data Layer` (Android).
- [ ] **High-Frequency Wearable Data Stream Optimizations** ([#104](https://github.com/Aymeric/ClinicalAssistant/issues/104)):
  - [ ] In-memory downsampling (LTTB - Largest Triangle Three Buckets algorithm) for rendering 100,000+ data points smoothly at 60/120 FPS on mobile hardware.
  - [ ] Background caching of time-series aggregates without storing raw multi-sample telemetry.

---

## Milestone 8: Medical Imaging, Sleep Architecture, Clinical Lifeline & Regimens (Long-Term)

Focus: Expanding to multi-modal medical imaging, circadian sleep architecture, disease trajectory visualization, complex medication titration, and legal health directives.

- [ ] **Medical Imaging & Offline DICOM Viewer** ([#105](https://github.com/Aymeric/ClinicalAssistant/issues/105)):
  - [ ] Ingest DICOM Part 10 files (`.dcm` files and ZIP archives) from hospital CD exports or patient portal downloads into the local encrypted vault.
  - [ ] On-device parsing of imaging series metadata (Modality: CT, MRI, X-Ray, Ultrasound; Series / Instance UID, Slice Thickness, Orientation).
  - [ ] Interactive high-performance slice viewer:
    - Multi-frame slice scrubbing, pan, and continuous zoom.
    - Window Level (WL) and Window Width (WW) contrast adjustments with standard radiological presets (Bone, Soft Tissue, Lung, Mediastinum).
    - Calibrated planar distance measurement tools (in millimeters).
  - [ ] Link imaging series directly to corresponding `DiagnosticReport` narrative impressions.
- [ ] **Unified Multi-Track Clinical Lifeline Canvas** ([#106](https://github.com/Aymeric/ClinicalAssistant/issues/106)):
  - [ ] Pan-and-zoom chronological visual lifeline integrating multiple clinical dimensions simultaneously:
    - **Track 1**: Active, recurring, and resolved diagnoses (`Condition`).
    - **Track 2**: Clinical procedures, surgeries, and hospitalizations (`Procedure`).
    - **Track 3**: Medication courses, titrations, and discontinuations (`MedicationStatement`).
    - **Track 4**: Key laboratory biomarker trajectories (`Observation`).
    - **Track 5**: Patient-reported symptom flare-ups and PROM scores (`QuestionnaireResponse`).
  - [ ] Instantly identify temporal correlations (e.g., observing whether initiating a new antihypertensive corresponded with drops in blood pressure and changes in serum creatinine).
- [ ] **Sleep Architecture & Circadian Analysis** ([#107](https://github.com/Aymeric/ClinicalAssistant/issues/107)):
  - [ ] Ingest detailed polysomnography and wearable sleep stages (Deep, REM, Core/Light, Awake periods, Sleep Latency, Sleep Efficiency) from Apple HealthKit and Health Connect.
  - [ ] Circadian midpoint regularity and bedtime consistency tracking.
  - [ ] Correlation overlays: Sleep duration and efficiency plotted against next-morning blood pressure surges and resting heart rate variability (HRV).
- [ ] **Complex Medication Titration & Tapering Schedules** ([#108](https://github.com/Aymeric/ClinicalAssistant/issues/108)):
  - [ ] Support non-static, dynamic medication regimens:
    - Step-down tapering schedules (e.g., Oral Corticosteroid / Prednisone tapers).
    - Multi-week escalation titration schedules (e.g., GLP-1 receptor agonists, Beta-blockers, Neuropathic agents).
    - Cross-tapering schedules between medications.
  - [ ] Dynamic calendar reminders and flexible dose adherence logging tailored to escalating/tapering regimens.
- [ ] **Advance Directives, Living Will & Emergency Orders (POLST / MOLST)** ([#109](https://github.com/Aymeric/ClinicalAssistant/issues/109)):
  - [ ] Secure encrypted storage and classification for legal healthcare directives:
    - Advance Healthcare Directives and Living Wills.
    - Medical Power of Attorney (MPOA) designation and emergency contact verification.
    - Physician Orders for Life-Sustaining Treatment (POLST) / Medical Orders for Life-Sustaining Treatment (MOLST) / Out-of-Hospital DNR orders.
  - [ ] Fast-access emergency presentation view accessible directly from the Emergency Medical ID screen for emergency personnel.
- [ ] **Laboratory Assay Methodology Harmonization** ([#110](https://github.com/Aymeric/ClinicalAssistant/issues/110)):
  - [ ] Ingest and track laboratory testing methodology metadata (e.g., HbA1c HPLC vs. enzymatic immunoassay; high-sensitivity Cardiac Troponin hs-cTn vs. conventional Troponin; immunoassay vs. LC-MS/MS for hormone levels).
  - [ ] Visual harmonization warnings when comparing serial lab results from different laboratory chains or methodology shifts that account for variance in numeric values or reference intervals.
- [ ] **Touchless Optical Vitals Spot-Check (rPPG)** ([#111](https://github.com/Aymeric/ClinicalAssistant/issues/111)):
  - [ ] On-device camera-based optical photoplethysmography (finger placed over smartphone camera lens and LED flash) to calculate resting heart rate and estimate respiratory rate without requiring external BLE hardware.
  - [ ] Purely local real-time frame buffer processing with zero video recording or storage.

---

## Milestone 9: Private On-Device AI, Research Tooling & Companion Apps (Future Vision)

Focus: Private edge AI, inclusive design, academic research tooling, and desktop ecosystems.

- [ ] **Private On-Device Small Language Model (SLM / Private AI)** ([#112](https://github.com/Aymeric/ClinicalAssistant/issues/112)):
  - [ ] Integration of a 100% on-device local model runtime (e.g., Gemini Nano via AICore on Android, Apple Foundation Models via CoreML on iOS, or onnxruntime/llama.cpp):
    - **Plain-Language Jargon Translation**: Translate complex physician shorthand and acronyms in clinical notes (`DocumentReference`) into understandable explanations.
    - **Visit Discussion Question Generator**: Suggest personalized questions to ask the physician based on the delta between out-of-range lab results and active medications.
    - **Semantic Natural Language Vault Search**: Query the vault in natural language (e.g., *"When did my doctor change my cholesterol medication?"*) strictly offline.
- [ ] **Private Client-Side Clinical Trial Matching** ([#113](https://github.com/Aymeric/ClinicalAssistant/issues/113)):
  - [ ] Periodically download an offline, compressed snapshot of active studies from ClinicalTrials.gov.
  - [ ] Locally match study inclusion/exclusion criteria against patient's age, diagnoses, and lab history without transmitting any patient data off-device.
- [ ] **Accessibility (a11y) & WCAG 2.2 AAA Compliance** ([#114](https://github.com/Aymeric/ClinicalAssistant/issues/114)):
  - [ ] Full screen-reader semantic trees (VoiceOver and TalkBack) for complex trend charts (providing interactive sonification / audio graphs and accessible tabular navigation).
  - [ ] Dynamic Type and high-scaling typography (support for up to 200% font scaling without layout clipping or text overlap).
  - [ ] Color-blind accessible palettes (Deuteranopia, Protanopia, Tritanopia verified) for out-of-range lab markers.
- [ ] **Multi-Language Localization** ([#115](https://github.com/Aymeric/ClinicalAssistant/issues/115)):
  - [ ] Full interface localization in Spanish, French, German, Italian, Portuguese, Japanese, and Simplified Chinese.
  - [ ] Region-aware date, number, and medical unit formatting standards.
- [ ] **Synthetic Dataset Generator & Research Tooling** ([#116](https://github.com/Aymeric/ClinicalAssistant/issues/116)):
  - [ ] Built-in synthetic patient generator (compatible with Synthea FHIR datasets) for testing complex longitudinal cases and edge conditions offline.
  - [ ] Export patient-authorized, fully de-identified datasets in OMOP Common Data Model (CDM v5.4) format for participation in decentralized academic research studies.
- [ ] **Cross-Platform Desktop Companion (macOS, Windows, Linux)** ([#117](https://github.com/Aymeric/ClinicalAssistant/issues/117)):
  - [ ] Desktop companion app built on the same Flutter codebase for patients and researchers analyzing exported encrypted vaults locally on desktop workstations.

---

## Architectural & Technical Specifications

```
+-----------------------------------------------------------------------------------------+
|                                    APPLICATION LAYER                                    |
|   +------------------+  +------------------+  +-------------------+  +----------------+ |
|   | Overview/Trends  |  | Records & Panels |  | Medication Tracker|  | Guidelines Lib | |
|   | AGP / Staging    |  | Survey PROMs     |  | Drug Interactions |  | Family Profiles| |
|   | Lifeline Canvas  |  | DICOM Viewer     |  | Titration Regimens|  | POLST/Directiv | |
|   +------------------+  +------------------+  +-------------------+  +----------------+ |
+-----------------------------------------------------------------------------------------+
|                                    CONTROLLER LAYER                                     |
|   +----------------------------------------------------------------------------------+  |
|   |                              HealthDataController                                |  |
|   |   (Aggregations, Trend Indicators, In-Range Checks, Filter & Search Pipelines)   |  |
|   +----------------------------------------------------------------------------------+  |
+-----------------------------------------------------------------------------------------+
|                                   INGESTION & SYNC                                      |
|   +------------------+  +-------------------+  +------------------+  +----------------+ |
|   | Apple HealthKit  |  | Health Connect    |  | SMART on FHIR    |  | Direct BLE     | |
|   | Clinical Records |  | Medical Records   |  | R4 / R5 Client   |  | GATT Services  | |
|   +------------------+  +-------------------+  +------------------+  +----------------+ |
|   | On-Device OCR    |  | Rx Barcode Scan   |  | Local Wi-Fi P2P  |  | Watch Sync     | |
|   | Voice / rPPG     |  | Cross-Deduplicate |  | Ephemeral Server |  | WebDAV/iCloud  | |
|   +------------------+  +-------------------+  +------------------+  +----------------+ |
+-----------------------------------------------------------------------------------------+
|                                     DATA SECURITY                                       |
|   +----------------------------------------------------------------------------------+  |
|   |                     EncryptedRecordStore (AES-GCM-256)                           |  |
|   |  Platform Keystore/Keychain Key Management · Shamir's ICE Split · Zero-Knowledge  |  |
|   +----------------------------------------------------------------------------------+  |
+-----------------------------------------------------------------------------------------+
```

### 1. Database & Persistence Performance
- **Database Engine**: Local SQLite database encrypted via AES-GCM-256.
- **Write-Ahead Logging (WAL)**: Enabled by default to provide high-concurrency read operations while large batch imports are persisting.
- **Paging & Virtualization**: Paged cursors (`LIMIT`/`OFFSET` or indexed keyset pagination) to ensure constant memory footprint when exploring longitudinal records exceeding 50,000 observations.
- **Deduplication Engine**: Deterministic composite hashing (`source + sourceRecordId + recordedAt + code`) ensuring idempotent re-imports across foreground sync passes.

### 2. Cryptographic Key Management
- **Key Generation**: 256-bit cryptographically secure pseudorandom numbers generated via platform hardware RNG (`Random.secure()`).
- **Hardware Storage**:
  - iOS: Stored in Apple Keychain with `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`.
  - Android: Stored in Android Keystore with `EncryptedSharedPreferences` backed by hardware TEE (Trusted Execution Environment) or StrongBox Keymaster.
- **Master Backup Derivation**: Passphrase-derived key generation using Argon2id ($t=3$, $m=65536$, $p=4$) or PBKDF2-HMAC-SHA256 (minimum 100,000 iterations).

---

## Regulatory & Clinical Safety Classification

Clinical Assistant is intentionally architected to operate as personal health record management and aggregation software, not as a medical device or diagnostic clinical decision support tool:

- **US FDA Compliance**:
  - Conforms to FDA Policy for Device Software Functions and Mobile Medical Applications ([FDA-2019-D-0394](https://www.fda.gov/regulatory-information/search-fda-guidance-documents/policy-device-software-functions-and-mobile-medical-applications)): classified under non-device health software functions that organize, display, or analyze medical information for patient self-management without providing real-time triage or automated diagnosis.
  - Falls within the 21st Century Cures Act Section 3060 exemptions for patient health record access and display.
- **EU MDR (Medical Device Regulation 2017/745) Classification**:
  - Meets non-medical device criteria under Rule 11 of MDR Chapter VIII: acts as an administrative patient repository and data viewer; does not calculate diagnostic risk scores or dictate patient therapy.
- **Zero Third-Party Telemetry**:
  - Complies with HIPAA guidelines regarding personal health application data handling and EU GDPR Article 9 special category data protections by retaining 100% of user data on-device.

---

## Feedback & Contributions

Suggestions, bug reports, and roadmap discussions can be submitted via GitHub Issues and Discussions. All contributions must uphold the project's strict commitment to patient privacy, local data storage, and descriptive clinical neutrality.
