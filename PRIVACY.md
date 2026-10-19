# Clinical Assistant Privacy Policy

**Effective Date:** October 18, 2026  
**Last Updated:** October 18, 2026

Clinical Assistant is a patient-controlled health record aggregation and export tool built on the fundamental principle of **local-only data privacy**. This Privacy Policy explains how your information is accessed, processed, and safeguarded when you use the app.

---

## 1. Zero Cloud Architecture & Zero Data Harvesting

- **No Remote Servers:** Clinical Assistant does not operate application servers, cloud databases, or remote user accounts.
- **No Third-Party Analytics or Trackers:** The application contains zero advertising SDKs, behavioral tracking scripts, third-party analytics (e.g., Firebase Analytics, Google Analytics), or telemetry tools.
- **Local-Only Storage:** All health records, laboratory observations, medication entries, and personal consultation notes stay entirely on your physical device.

---

## 2. Information Accessed and Processed

Clinical Assistant only accesses health information that you explicitly authorize through your operating system or healthcare provider:

### A. Apple HealthKit (iOS)
- **Data Categories:** Read access to shared health metrics including blood pressure, heart rate, blood glucose, oxygen saturation, body temperature, respiratory rate, body measurements, sleep analysis, nutrition, hydration, and steps.
- **Clinical Health Records:** Read access to FHIR laboratory `Observation` resources shared by your healthcare providers with Apple Health.
- **Policy Compliance:** In compliance with Apple developer guidelines, health data gathered from HealthKit is never used for marketing, advertising, or sold to data brokers.

### B. Google Health Connect (Android)
- **Data Categories:** Read access to vital signs (blood pressure, heart rate, resting heart rate, blood glucose, oxygen saturation, temperature, respiratory rate), activity metrics (steps, calories burned, floors climbed, exercise sessions), sleep records, hydration, and nutrition.
- **Medical Records (Experimental):** Read access to laboratory results (`READ_MEDICAL_DATA_LABORATORY_RESULTS`) where supported by Health Connect on compatible Android versions.
- **Policy Compliance:** Clinical Assistant complies with the Google Health Connect Permissions policy, including the Limited Use requirements:
  - Health data is used exclusively to provide user-facing health aggregation and export features.
  - Health data is never transferred to third parties or used for creditworthiness, lending, or advertising.

### C. SMART-on-FHIR Provider Portals
- **Authorization:** If you choose to connect directly to an external healthcare provider via SMART-on-FHIR, you authorize access directly on your provider's secure authentication gateway.
- **Token Handling:** OAuth 2.0 access tokens are held exclusively in transient device memory. If you explicitly opt in to automatic portal sync, a provider-issued refresh token and patient identifier are saved in your device's hardware-backed secure storage. Disabling sync or deleting records permanently removes them.
- **Imported Data:** FHIR laboratory `Observation` resources, panel groupings, and original FHIR JSON payloads.

### D. Manual Entries & Guidelines Notes
- Measurements, paired blood pressure readings, and medication details (`MedicationStatement`) entered manually by you.
- Private consultation notes recorded within the offline clinical guidelines library.

---

## 3. Cryptography & On-Device Security

- **Vault Encryption:** All imported and manually recorded data is stored in a local SQLite database encrypted with **AES-GCM (256-bit)**.
- **Key Management:** Vault encryption keys are generated randomly on your device and stored in platform hardware-backed keychains:
  - iOS: Apple Keychain Services (`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`).
  - Android: Android Keystore (`EncryptedSharedPreferences`).
- **Passcode Protection:** You can optionally configure an in-app PIN/passcode with auto-lock timers to protect access to the app on shared devices.
- **Backup Exclusion:** The local vault directory is explicitly excluded from unencrypted cloud backups (Android `noBackupFilesDir`; iOS `NSURLIsExcludedFromBackupKey`).

---

## 4. Notifications & Background Sync

- **Local Alerts Only:** All notifications for new results or measurement thresholds are evaluated locally on-device. No notification payloads are routed through remote push notification servers.
- **Privacy in Alerts:** System notification banners contain only item counts and neutral rule summaries (e.g., "1 new lab result imported"); sensitive clinical values and test names are never displayed on your lock screen.
- **Foreground-Only Sync:** Optional automatic sync runs exclusively while the application is actively opened or brought to the foreground (throttled to at most once every 5 minutes). The app does not perform background data queries while terminated or backgrounded.

---

## 5. Sharing & Exports

- **User-Initiated Only:** Data exports (Printable Doctor-Visit PDF, portable FHIR JSON Bundle, and CSV) are only generated when you tap Export.
- **Ephemeral Export Files:** Export files are written to isolated temporary device storage and presented directly to the native operating system share sheet. You choose whether, how, and with whom to share your file (e.g., printing, saving to Files, AirDrop, or attaching to an email).
- **Formula Injection Mitigation:** CSV exports automatically sanitize cells beginning with formula trigger characters (`=`, `+`, `-`, `@`, `\t`, `\r`) to protect against CSV injection attacks.

---

## 6. Data Retention and Deletion

- **Full Patient Control:** You have the absolute right to delete all stored health records at any time.
- **Instant Cryptographic Wipe:** Tapping **"Delete all records"** inside the app performs a complete local purge:
  1. Closes and deletes the local SQLite encrypted database file.
  2. Cryptographically erases database encryption keys from platform secure storage.
  3. Revokes and deletes saved SMART-on-FHIR refresh tokens.
  4. Resets all automatic sync preferences.

---

## 7. Medical Disclaimer

Clinical Assistant is a personal health data management tool, not a medical device or diagnostic application. It does not provide medical diagnosis, clinical interpretations, or personalized treatment recommendations. Always consult a qualified healthcare professional regarding medical conditions and clinical decisions.

---

## 8. Contact & Verification

Because Clinical Assistant does not collect user contact information, inquiries or bug reports regarding this Privacy Policy can be submitted directly via the project repository:

- **Repository Issues:** [https://github.com/Aymeric/ClinicalAssistant/issues](https://github.com/Aymeric/ClinicalAssistant/issues)
