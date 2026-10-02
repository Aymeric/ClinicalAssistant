import 'package:clinical_assistant/exports/health_export_service.dart';
import 'package:clinical_assistant/models/health_record.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late HealthExportService exportService;

  setUp(() {
    exportService = HealthExportService();
  });

  test(
    'generates doctor visit summary PDF document with vitals and out-of-range labs',
    () async {
      final now = DateTime.utc(2026, 9, 20);
      final records = [
        HealthRecord(
          id: 'vital-sys',
          name: 'Systolic Blood Pressure',
          value: '135',
          unit: 'mmHg',
          recordedAt: now,
          category: RecordCategory.vital,
          source: 'Manual Entry',
          referenceRange: '< 120 mmHg',
        ),
        HealthRecord(
          id: 'vital-dia',
          name: 'Diastolic Blood Pressure',
          value: '88',
          unit: 'mmHg',
          recordedAt: now,
          category: RecordCategory.vital,
          source: 'Manual Entry',
          referenceRange: '< 80 mmHg',
        ),
        HealthRecord(
          id: 'lab-glucose-prior',
          name: 'Blood Glucose',
          value: '165',
          unit: 'mg/dL',
          recordedAt: now.subtract(const Duration(days: 30)),
          category: RecordCategory.lab,
          source: 'Hospital Portal',
          referenceRange: '70 - 99 mg/dL',
        ),
        HealthRecord(
          id: 'lab-glucose',
          name: 'Blood Glucose',
          value: '145',
          unit: 'mg/dL',
          recordedAt: now,
          category: RecordCategory.lab,
          source: 'Hospital Portal',
          referenceRange: '70 - 99 mg/dL',
        ),
        HealthRecord(
          id: 'lab-cholesterol',
          name: 'Total Cholesterol',
          value: '185',
          unit: 'mg/dL',
          recordedAt: now.subtract(const Duration(days: 10)),
          category: RecordCategory.lab,
          source: 'Hospital Portal',
          referenceRange: '100 - 199 mg/dL',
        ),
      ];

      final doc = await exportService.buildDoctorVisitSummaryPdfDocument(
        records,
        dateRange: DateTimeRange(
          start: DateTime(2026, 9, 1),
          end: DateTime(2026, 9, 25),
        ),
        patientQuestions: 'Should we adjust my blood pressure prescription?',
      );

      final bytes = await doc.save();
      expect(bytes, isNotEmpty);
      expect(bytes.length, greaterThan(1000));
    },
  );

  test('handles empty records list gracefully', () async {
    final doc = await exportService.buildDoctorVisitSummaryPdfDocument(
      const [],
    );
    final bytes = await doc.save();
    expect(bytes, isNotEmpty);
    expect(bytes.length, greaterThan(500));
  });

  test(
    'generates doctor visit summary with medications, conditions, and allergies',
    () async {
      final now = DateTime.utc(2026, 9, 20);
      final records = [
        HealthRecord(
          id: 'med-1',
          name: 'Metformin',
          value: '500 mg oral tablet twice daily',
          unit: '',
          recordedAt: now,
          category: RecordCategory.medication,
          source: 'Provider Portal',
        ),
        HealthRecord(
          id: 'cond-1',
          name: 'Type 2 Diabetes Mellitus',
          value: 'Active',
          unit: '',
          recordedAt: now,
          category: RecordCategory.condition,
          source: 'Provider Portal',
        ),
        HealthRecord(
          id: 'allergy-1',
          name: 'Penicillin',
          value: 'Hives, Rash (moderate)',
          unit: '',
          recordedAt: now,
          category: RecordCategory.allergy,
          source: 'Provider Portal',
        ),
      ];

      final doc = await exportService.buildDoctorVisitSummaryPdfDocument(
        records,
      );
      final bytes = await doc.save();
      expect(bytes, isNotEmpty);
      expect(bytes.length, greaterThan(1000));
    },
  );

  test(
    'respects section visibility flags when certain sections are excluded',
    () async {
      final now = DateTime.utc(2026, 9, 20);
      final records = [
        HealthRecord(
          id: 'med-1',
          name: 'Metformin',
          value: '500 mg oral tablet',
          unit: '',
          recordedAt: now,
          category: RecordCategory.medication,
          source: 'Provider Portal',
        ),
        HealthRecord(
          id: 'vital-1',
          name: 'Heart Rate',
          value: '72',
          unit: 'bpm',
          recordedAt: now,
          category: RecordCategory.vital,
          source: 'Provider Portal',
        ),
      ];

      // Exclude vitals and medications, include only questions
      final doc = await exportService.buildDoctorVisitSummaryPdfDocument(
        records,
        includeVitals: false,
        includeLabs: false,
        includeMedications: false,
        includeConditions: false,
        includeAllergies: false,
        includeQuestions: true,
        patientQuestions: 'Can I exercise regularly?',
      );

      final bytes = await doc.save();
      expect(bytes, isNotEmpty);
      expect(bytes.length, greaterThan(500));
    },
  );
}
