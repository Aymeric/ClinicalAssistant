# Clinical Assistant

A patient-controlled Flutter app for collecting health measurements and lab
results on iOS and Android, then exporting them as a readable PDF, FHIR JSON,
or CSV.

## What it does

- Reads the shared measurement, sleep, activity, nutrition, hydration, and
  cycle-tracking types from Apple HealthKit on iOS or Google Health Connect on
  Android, after the user grants access. Structured entries retain their
  original source data, including available workout-route samples, in the
  encrypted on-device vault. Apple-only clinical lab imports remain supported.
- Connects to a patient portal that exposes a SMART-on-FHIR endpoint and imports
  laboratory `Observation` resources, including result panels. Users can also directly
  import local FHIR JSON files (single or multiple) with live resource count previews
  and atomic pre-validation.
- Tracks per-source import history and coverage, displaying local sync outcomes, last-checked
  timestamps, record counts, and observed date coverage across all connected sources.
- Preserves the source, date, units, status, and original FHIR resource where
  available. The app does not interpret results or provide medical advice.
- Lets users log measurements manually and correct their values or recorded
  date/time later. Blood-pressure readings are edited as a systolic/diastolic
  pair; imported health-platform and provider records remain source-preserving
  and read-only.
- Lets users record medication name, dose or instructions, frequency, route,
  status, start date, optional end date, and personal notes. Manual medication
  entries remain on-device and export as FHIR `MedicationStatement` resources.
- Charts numeric lab results, vital measurements, sleep durations, nutrition
  measures, and daily activity totals by measurement and time range, with
  source-provided reference ranges marked at the associated readings when they
  are numeric and unit-compatible. Filter trends by fasting context (fasting,
  pre-meal, post-meal, bedtime, random) for like-for-like comparisons, and optionally
  overlay medication start/stop milestone markers. Trend indicators summarize observed change,
  average, and range; an optional
  three-reading moving average is descriptive only and does not assess clinical
  significance.
- Stores step and distance activity as daily or workout totals to avoid retaining a high-volume
  per-sample stream; other supported health records remain individual records.
  iOS and Android health imports use matching ten-year query windows.
- Offers opt-in on-device alerts after imports for new lab results and health
  records, configurable numeric change thresholds, and three-reading
  directional patterns. Automatic sync can check connected sources when the
  app opens or returns to the foreground, no more than once every five minutes.
  Alerts show counts and rule summaries only; the app does not fetch data while
  closed or in the background, and it does not interpret clinical significance.
- Automatic health-platform sync is opt-in and uses the permissions granted to
  the app; the OS may ask for health access when sync is enabled.
  FHIR portal sync is separately opt-in and only works when the provider issues
  a refresh token. When enabled, the refresh token and patient context are held
  in platform secure storage; access tokens remain in memory.
- Encrypts the on-device record vault with AES-GCM. The encryption key is held
  in platform secure storage. The app does not upload records to an account or
  app-operated cloud service. Deleting the local records also turns off
  automatic sync and removes the saved FHIR refresh token.
- Creates PDF, FHIR Bundle JSON, and CSV exports in temporary device storage.
  Users can scope exports by source or measurement, toggle privacy redactions for
  personal notes and raw payload data, and run preflight conformance validation
  against HL7 FHIR Release 4 (R4 v4.0.1) before sharing.
- Includes an offline directory of guideline publishers and curated clinical
  guidelines from trusted organizations (NICE, USPSTF, WHO, Australian
  Department of Health, Canadian Task Force). Authoritative guidelines can be
  downloaded for offline reading, bookmarked to favorites, searched by topic
  and jurisdiction, and explored in an interactive in-app viewer with table-of-contents
  navigation, key recommendations, evidence grade explanations, and full structured guidance.
  Users can save private consultation notes to prepare questions for upcoming
  clinical appointments and export clean, printable doctor-visit summary PDFs;
  the app does not connect guidelines to a person's records or provide
  individualized clinical recommendations.

## Guideline directory maintenance

The bundled directory is a curated starting point, not a complete or live
clinical guideline feed. Source links and directory metadata are checked when
the catalog is maintained; that check does not verify that every linked
recommendation is current. Users should confirm a document's population,
jurisdiction, publication or review date, and status on the issuing body's
website.

When updating `lib/guidelines/guideline_source.dart`:

- Prefer the issuing organization's own catalog or document page. Discovery
  indexes such as G-I-N and PubMed are for finding sources, not substitutes for
  publisher verification or evidence of endorsement.
- Label archives and discovery indexes clearly; do not represent them as
  current official recommendation portals.
- Keep summaries original and descriptive. Do not copy recommendation text
  into the app unless the publisher's terms explicitly permit that reuse.
- Record the jurisdiction, intended population, link-check date, source status,
  and any known update or licensing caveats. Re-check those details before a
  release and seek clinical/editorial and licensing review for new clinical
  content.

## Run

```sh
flutter pub get
flutter run
```

Run the unit tests and static checks with:

```sh
flutter test
flutter analyze
```

## Beta testing

- [Apple TestFlight](https://testflight.apple.com/join/wQWTZ4kZ)
- [Google Play internal testing](https://play.google.com/apps/internaltest/4701380658244067623)

## Platform setup and limitations

**iOS:** HealthKit access requires the HealthKit and Clinical Health Records
capabilities and user approval. Health-data types use the standard HealthKit
permission prompt; clinical lab records require a separate prompt. The app
imports supported health records and FHIR `Observation` lab results already
stored in Apple Health. Clinical records are read-only and only include data
that a provider has shared with Apple Health and the user has approved.

**Android:** Health Connect must be available on the device. Health Connect
permissions for the shared data types, including step access, are requested at
import time. Reading an individual workout route may also require separate
Health Connect consent; routes that are not yet accessible are marked
accordingly rather than reported as imported route samples. Manual imports on
both platforms download all available history directly (Android uses ten-year
query windows). Health Connect may limit access to
the most recent 30 days unless historical access is granted in Health Connect;
when supported, the app requests that access for imports spanning older dates.
On devices with Health Connect Medical Records support, laboratory `Observation`
resources are also available through a separate lab-results permission. This
experimental Health Connect feature depends on the installed Health Connect
version and on medical records being shared to Health Connect; it is separate
from the existing provider-portal FHIR import.

**FHIR portals:** Provider support and app registration are required. The user
enters the provider's HTTPS FHIR base URL and an OAuth client ID registered for
this app's redirect URI:

```text
com.cidevelop.clinicalAssistant:/oauth2redirect
```

The server must expose SMART-on-FHIR configuration, authorize standalone
patient access, return a patient context, and permit reading laboratory
Observations. Patient-portal access is not universal; no provider credentials
or registrations are included in this repository.

The encrypted vault is stored in Android's no-backup directory. On iOS, its
directory is excluded from device backup and protected while the device is
locked. FHIR access tokens are held only in memory. A refresh token and patient
context are stored in platform secure storage only when the user opts in to
portal auto-sync; disabling it removes them. The iOS URL cache is disabled to
avoid persisting authorization callback data.

Before a public release, configure production app identifiers, enable the
HealthKit Clinical Health Records capability for the iOS app's signing profile,
verify Health Connect's permission declarations and Play review requirements,
register the OAuth redirect URI with each supported portal, and publish an
accurate privacy policy. Integrations must be tested on physical iOS and
Android devices with real provider registrations; desktop and simulator
environments do not provide the native health stores.

## Roadmap

See [ROADMAP.md](ROADMAP.md) for planned milestones, upcoming features, and technical initiatives.
