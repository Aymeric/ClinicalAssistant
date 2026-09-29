# Product

<!-- impeccable:product-schema 1 -->

## Platform

adaptive

## Users

Patients collecting their own health history from phone health platforms and provider portals.

## Product Purpose

Bring a patient's health records and lab results together so they can understand their collected history and export it for their own use or sharing.

## Positioning

Combine patient-authorized records from Apple Health, Android Health Connect, and FHIR-enabled provider portals, then offer both a readable summary and portable data files.

## Operating Context

Patients connect the health sources they choose, download and review imported records and lab results, and export copies. The first version is local-only: imported records and exports remain on the device and are not uploaded to an app account or cloud service.

## Capabilities and Constraints

- The intended sources are Apple HealthKit, Android Health Connect, and patient portals that support FHIR.
- Exports include a readable PDF summary and portable FHIR JSON Bundle and CSV files.
- Optional device notifications can summarize new imported records and numeric reading trends or patterns; they are opt-in, checked after manual imports and foreground syncs, and contain no record values.
- Optional foreground sync can check opted-in health platforms and FHIR portals when the app opens or returns to the foreground, at most once every five minutes; it does not fetch data while the app is closed or in the background.
- FHIR portal auto-sync requires a provider-issued refresh token and a separate explicit opt-in; the refresh token and patient context are stored in platform secure storage, while access tokens remain in memory.
- Deleting the local record vault also disables automatic sync and removes saved FHIR refresh credentials so deleted records are not immediately re-imported.
- Health-platform imports cover supported measurements; clinical lab Observations are imported from FHIR provider portals.
- Patients can manually log measurements and correct the value or recorded date/time later. Blood-pressure values remain a paired systolic/diastolic entry; imported records stay read-only so their source data is preserved.
- Patients can manually record medication name, dose/instructions, frequency, route, status, start date, optional end date, and notes. Medication entries remain on-device and can be included in FHIR exports as `MedicationStatement` resources.
- Numeric lab results, vital measurements, and activity totals can be explored in category- and measurement-specific trend charts. Source-provided reference ranges are shown at the associated reading when numeric and unit-compatible. Trends show descriptive changes and ranges, not clinical interpretation; non-numeric results are not charted.
- Available records and lab results depend on the connected platform, provider, and the patient's permissions; do not imply that every source exposes the same data.
- Product-specific encryption, authentication, retention, deletion, and data-format requirements remain to be specified.

## Evidence on Hand

No real patient records, provider connections, logos, or clinical claims are supplied. Any demonstration records must be clearly identified as synthetic.

## Product Principles

- Let patients control which sources they connect and what they export.
- Make source and import status visible beside health data.
- Preserve clinical values, units, and dates as received.
- Keep patient records on-device in the first version.
- Distinguish collected information from interpretation; numeric trends and patterns are descriptive only and must not imply clinical advice.
