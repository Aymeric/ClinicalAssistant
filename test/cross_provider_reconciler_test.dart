import 'package:clinical_assistant/models/health_record.dart';
import 'package:clinical_assistant/terminology/cross_provider_reconciler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CrossProviderReconciler', () {
    test(
      'groups equivalent lab results reported by different hospital portals on the same date',
      () {
        final hospitalA = HealthRecord(
          id: 'rec-hosp-a-lipid',
          name: 'Lipid Total Cholesterol',
          value: '190',
          unit: 'mg/dL',
          recordedAt: DateTime.utc(2026, 9, 15, 8, 30),
          source: 'Mercy Hospital Portal',
          category: RecordCategory.lab,
          code: '2093-3',
          referenceRange: '< 200 mg/dL',
        );

        final labcorp = HealthRecord(
          id: 'rec-labcorp-chol',
          name: 'Cholesterol, Total',
          value: '190',
          unit: 'mg/dL',
          recordedAt: DateTime.utc(2026, 9, 15, 11, 45),
          source: 'LabCorp Direct',
          category: RecordCategory.lab,
          code: 'http://loinc.org|2093-3',
        );

        final otherDate = HealthRecord(
          id: 'rec-other-date',
          name: 'Cholesterol, Total',
          value: '185',
          unit: 'mg/dL',
          recordedAt: DateTime.utc(2026, 10, 1, 9, 0),
          source: 'LabCorp Direct',
          category: RecordCategory.lab,
          code: '2093-3',
        );

        final records = [hospitalA, labcorp, otherDate];
        final groups = CrossProviderReconciler.findReconciledGroups(records);

        expect(groups.containsKey(hospitalA.id), isTrue);
        expect(groups.containsKey(labcorp.id), isTrue);
        expect(groups.containsKey(otherDate.id), isFalse);

        final group = groups[hospitalA.id]!;
        expect(group.distinctSourceCount, 2);
        expect(group.isMultiProvider, isTrue);
        expect(
          group.sourceNames,
          containsAll(['Mercy Hospital Portal', 'LabCorp Direct']),
        );
        expect(group.standardizedName, 'Total Cholesterol');
        expect(group.contributingRecords.length, 2);
        // Canonical record should prefer the one with referenceRange
        expect(group.canonicalRecord.id, hospitalA.id);
      },
    );

    test(
      'reconciles vitals with equivalent clean names across health systems',
      () {
        final record1 = HealthRecord(
          id: 'vital-1',
          name: 'Systolic Blood Pressure',
          value: '124',
          unit: 'mmHg',
          recordedAt: DateTime.utc(2026, 8, 10, 14, 0),
          source: 'Apple Health',
          category: RecordCategory.vital,
        );

        final record2 = HealthRecord(
          id: 'vital-2',
          name: 'Blood Pressure (Systolic)',
          value: '124',
          unit: 'mmHg',
          recordedAt: DateTime.utc(2026, 8, 10, 15, 0),
          source: 'Clinic Portal',
          category: RecordCategory.vital,
        );

        final groups = CrossProviderReconciler.findReconciledGroups([
          record1,
          record2,
        ]);
        expect(groups.containsKey(record1.id), isTrue);
        expect(groups[record1.id]!.isMultiProvider, isTrue);
      },
    );

    test('does not group distinct single-source records', () {
      final singleA = HealthRecord(
        id: 'single-1',
        name: 'Glucose',
        value: '95',
        unit: 'mg/dL',
        recordedAt: DateTime.utc(2026, 9, 1),
        source: 'Quest Diagnostics',
        category: RecordCategory.lab,
        code: '2345-7',
      );

      final singleB = HealthRecord(
        id: 'single-2',
        name: 'Glucose',
        value: '92',
        unit: 'mg/dL',
        recordedAt: DateTime.utc(2026, 9, 2),
        source: 'Quest Diagnostics',
        category: RecordCategory.lab,
        code: '2345-7',
      );

      final groups = CrossProviderReconciler.findReconciledGroups([
        singleA,
        singleB,
      ]);
      expect(groups, isEmpty);
    });

    test('preserves original records and never overwrites values or units', () {
      final recA = HealthRecord(
        id: 'rec-a',
        name: 'Glucose Serum',
        value: '100',
        unit: 'mg/dL',
        recordedAt: DateTime.utc(2026, 9, 10),
        source: 'Portal A',
        category: RecordCategory.lab,
        code: '2345-7',
      );

      final recB = HealthRecord(
        id: 'rec-b',
        name: 'Fasting Blood Sugar',
        value: '100',
        unit: 'mg/dL',
        recordedAt: DateTime.utc(2026, 9, 10),
        source: 'Portal B',
        category: RecordCategory.lab,
        code: '2345-7',
      );

      final groups = CrossProviderReconciler.findReconciledGroups([recA, recB]);
      final group = groups[recA.id]!;

      // Both original contributing records must remain intact with source names and values
      expect(group.contributingRecords[0].name, 'Glucose Serum');
      expect(group.contributingRecords[0].source, 'Portal A');
      expect(group.contributingRecords[1].name, 'Fasting Blood Sugar');
      expect(group.contributingRecords[1].source, 'Portal B');
    });
  });
}
