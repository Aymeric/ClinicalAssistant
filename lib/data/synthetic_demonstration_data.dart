import '../models/health_record.dart';

const syntheticDemoSource = 'Synthetic Demo';
const syntheticDemoSourceId = 'synthetic-demo';

/// Checks if a record was generated as synthetic demonstration data.
bool isSyntheticRecord(HealthRecord record) =>
    record.source == syntheticDemoSource ||
    record.sourceId == syntheticDemoSourceId;

/// Generates realistic synthetic health records for demonstration and offline exploration.
///
/// In compliance with product guidelines, all records are explicitly tagged
/// with `source: 'Synthetic Demo'`.
List<HealthRecord> generateSyntheticDemonstrationRecords({
  DateTime? referenceDate,
}) {
  final now = referenceDate ?? DateTime.now();
  final records = <HealthRecord>[];

  // 1. Hemoglobin A1c (Lab)
  records.addAll([
    HealthRecord(
      id: 'synthetic:lab:hba1c:1',
      name: 'Hemoglobin A1c',
      value: '5.8',
      unit: '%',
      recordedAt: now.subtract(const Duration(days: 120)),
      category: RecordCategory.lab,
      source: syntheticDemoSource,
      sourceId: syntheticDemoSourceId,
      code: '4548-4',
      referenceRange: '4.0 – 5.6 %',
      status: 'final',
      sourceData: {
        'resourceType': 'Observation',
        'status': 'final',
        'code': {
          'coding': [
            {
              'system': 'http://loinc.org',
              'code': '4548-4',
              'display': 'Hemoglobin A1c/Hemoglobin.total in Blood',
            },
          ],
          'text': 'Hemoglobin A1c',
        },
      },
    ),
    HealthRecord(
      id: 'synthetic:lab:hba1c:2',
      name: 'Hemoglobin A1c',
      value: '5.6',
      unit: '%',
      recordedAt: now.subtract(const Duration(days: 60)),
      category: RecordCategory.lab,
      source: syntheticDemoSource,
      sourceId: syntheticDemoSourceId,
      code: '4548-4',
      referenceRange: '4.0 – 5.6 %',
      status: 'final',
    ),
    HealthRecord(
      id: 'synthetic:lab:hba1c:3',
      name: 'Hemoglobin A1c',
      value: '5.4',
      unit: '%',
      recordedAt: now.subtract(const Duration(days: 10)),
      category: RecordCategory.lab,
      source: syntheticDemoSource,
      sourceId: syntheticDemoSourceId,
      code: '4548-4',
      referenceRange: '4.0 – 5.6 %',
      status: 'final',
    ),
  ]);

  // 2. Total Cholesterol (Lab)
  records.addAll([
    HealthRecord(
      id: 'synthetic:lab:chol:1',
      name: 'Total Cholesterol',
      value: '210',
      unit: 'mg/dL',
      recordedAt: now.subtract(const Duration(days: 120)),
      category: RecordCategory.lab,
      source: syntheticDemoSource,
      sourceId: syntheticDemoSourceId,
      code: '2093-3',
      referenceRange: '< 200 mg/dL',
      status: 'final',
    ),
    HealthRecord(
      id: 'synthetic:lab:chol:2',
      name: 'Total Cholesterol',
      value: '195',
      unit: 'mg/dL',
      recordedAt: now.subtract(const Duration(days: 60)),
      category: RecordCategory.lab,
      source: syntheticDemoSource,
      sourceId: syntheticDemoSourceId,
      code: '2093-3',
      referenceRange: '< 200 mg/dL',
      status: 'final',
    ),
    HealthRecord(
      id: 'synthetic:lab:chol:3',
      name: 'Total Cholesterol',
      value: '185',
      unit: 'mg/dL',
      recordedAt: now.subtract(const Duration(days: 10)),
      category: RecordCategory.lab,
      source: syntheticDemoSource,
      sourceId: syntheticDemoSourceId,
      code: '2093-3',
      referenceRange: '< 200 mg/dL',
      status: 'final',
    ),
  ]);

  // 3. Fasting Blood Glucose (Lab)
  records.addAll([
    HealthRecord(
      id: 'synthetic:lab:glucose:1',
      name: 'Fasting Blood Glucose',
      value: '98',
      unit: 'mg/dL',
      recordedAt: now.subtract(const Duration(days: 28)),
      category: RecordCategory.lab,
      source: syntheticDemoSource,
      sourceId: syntheticDemoSourceId,
      code: '1558-6',
      referenceRange: '70 – 99 mg/dL',
      status: 'final',
    ),
    HealthRecord(
      id: 'synthetic:lab:glucose:2',
      name: 'Fasting Blood Glucose',
      value: '95',
      unit: 'mg/dL',
      recordedAt: now.subtract(const Duration(days: 21)),
      category: RecordCategory.lab,
      source: syntheticDemoSource,
      sourceId: syntheticDemoSourceId,
      code: '1558-6',
      referenceRange: '70 – 99 mg/dL',
      status: 'final',
    ),
    HealthRecord(
      id: 'synthetic:lab:glucose:3',
      name: 'Fasting Blood Glucose',
      value: '92',
      unit: 'mg/dL',
      recordedAt: now.subtract(const Duration(days: 14)),
      category: RecordCategory.lab,
      source: syntheticDemoSource,
      sourceId: syntheticDemoSourceId,
      code: '1558-6',
      referenceRange: '70 – 99 mg/dL',
      status: 'final',
    ),
    HealthRecord(
      id: 'synthetic:lab:glucose:4',
      name: 'Fasting Blood Glucose',
      value: '89',
      unit: 'mg/dL',
      recordedAt: now.subtract(const Duration(days: 7)),
      category: RecordCategory.lab,
      source: syntheticDemoSource,
      sourceId: syntheticDemoSourceId,
      code: '1558-6',
      referenceRange: '70 – 99 mg/dL',
      status: 'final',
    ),
    HealthRecord(
      id: 'synthetic:lab:glucose:5',
      name: 'Fasting Blood Glucose',
      value: '91',
      unit: 'mg/dL',
      recordedAt: now.subtract(const Duration(days: 1)),
      category: RecordCategory.lab,
      source: syntheticDemoSource,
      sourceId: syntheticDemoSourceId,
      code: '1558-6',
      referenceRange: '70 – 99 mg/dL',
      status: 'final',
    ),
  ]);

  // 4. Serum Creatinine (Lab)
  records.addAll([
    HealthRecord(
      id: 'synthetic:lab:creat:1',
      name: 'Serum Creatinine',
      value: '0.98',
      unit: 'mg/dL',
      recordedAt: now.subtract(const Duration(days: 90)),
      category: RecordCategory.lab,
      source: syntheticDemoSource,
      sourceId: syntheticDemoSourceId,
      code: '2160-0',
      referenceRange: '0.70 – 1.30 mg/dL',
      status: 'final',
    ),
    HealthRecord(
      id: 'synthetic:lab:creat:2',
      name: 'Serum Creatinine',
      value: '0.94',
      unit: 'mg/dL',
      recordedAt: now.subtract(const Duration(days: 10)),
      category: RecordCategory.lab,
      source: syntheticDemoSource,
      sourceId: syntheticDemoSourceId,
      code: '2160-0',
      referenceRange: '0.70 – 1.30 mg/dL',
      status: 'final',
    ),
  ]);

  // 5. Resting Heart Rate (Vital)
  const hrValues = [72, 70, 68, 71, 67, 69, 66];
  for (var i = 0; i < hrValues.length; i++) {
    records.add(
      HealthRecord(
        id: 'synthetic:vital:hr:${i + 1}',
        name: 'Heart Rate',
        value: hrValues[i].toString(),
        unit: 'bpm',
        recordedAt: now.subtract(Duration(days: (hrValues.length - 1 - i) * 2)),
        category: RecordCategory.vital,
        source: syntheticDemoSource,
        sourceId: syntheticDemoSourceId,
        code: '8867-4',
        referenceRange: '60 – 100 bpm',
      ),
    );
  }

  // 6. Blood Pressure (Vital)
  const sysValues = [124, 122, 118, 120, 116];
  const diaValues = [82, 80, 78, 78, 76];
  for (var i = 0; i < sysValues.length; i++) {
    final date = now.subtract(Duration(days: (sysValues.length - 1 - i) * 3));
    records.add(
      HealthRecord(
        id: 'synthetic:vital:sys:${i + 1}',
        name: 'Systolic Blood Pressure',
        value: sysValues[i].toString(),
        unit: 'mmHg',
        recordedAt: date,
        category: RecordCategory.vital,
        source: syntheticDemoSource,
        sourceId: syntheticDemoSourceId,
        code: '8480-6',
        referenceRange: '< 120 mmHg',
      ),
    );
    records.add(
      HealthRecord(
        id: 'synthetic:vital:dia:${i + 1}',
        name: 'Diastolic Blood Pressure',
        value: diaValues[i].toString(),
        unit: 'mmHg',
        recordedAt: date,
        category: RecordCategory.vital,
        source: syntheticDemoSource,
        sourceId: syntheticDemoSourceId,
        code: '8462-4',
        referenceRange: '< 80 mmHg',
      ),
    );
  }

  // 7. Daily Step Count (Activity)
  const stepValues = [8420, 9150, 10300, 7920, 11450, 9870, 10200];
  for (var i = 0; i < stepValues.length; i++) {
    records.add(
      HealthRecord(
        id: 'synthetic:activity:steps:${i + 1}',
        name: 'Step Count',
        value: stepValues[i].toString(),
        unit: 'steps',
        recordedAt: now.subtract(Duration(days: stepValues.length - 1 - i)),
        category: RecordCategory.activity,
        source: syntheticDemoSource,
        sourceId: syntheticDemoSourceId,
        code: '55423-8',
      ),
    );
  }

  return records;
}
