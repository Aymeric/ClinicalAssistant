import 'package:clinical_assistant/models/health_record.dart';
import 'package:clinical_assistant/safety/drug_interaction_database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DrugInteractionDatabase', () {
    test('detects high-severity drug-drug interaction (Warfarin + NSAID)', () {
      final warfarin = HealthRecord(
        id: 'med-1',
        name: 'Warfarin Sodium',
        value: '5 mg oral tablet',
        unit: '',
        recordedAt: DateTime(2026, 10, 1),
        source: 'Cardiology Clinic',
        category: RecordCategory.medication,
      );
      final ibuprofen = HealthRecord(
        id: 'med-2',
        name: 'Ibuprofen',
        value: '400 mg oral tablet',
        unit: '',
        recordedAt: DateTime(2026, 10, 2),
        source: 'Manual Entry',
        category: RecordCategory.medication,
      );

      final detected = DrugInteractionDatabase.evaluateInteractions([
        warfarin,
        ibuprofen,
      ]);

      expect(detected.isNotEmpty, isTrue);
      final ddi = detected.firstWhere(
        (i) => i.interaction.id == 'ddi-warfarin-nsaids',
      );
      expect(ddi.interaction.severity, DrugInteractionSeverity.high);
      expect(ddi.interaction.type, DrugInteractionType.drugDrug);
      expect(ddi.medicationA.name, 'Warfarin Sodium');
      expect(ddi.medicationB?.name, 'Ibuprofen');
      expect(ddi.isFoodDrug, isFalse);
    });

    test('detects ACE inhibitor + Potassium-sparing diuretic interaction', () {
      final lisinopril = HealthRecord(
        id: 'med-lisinopril',
        name: 'Lisinopril',
        value: '20 mg oral',
        unit: '',
        recordedAt: DateTime(2026, 10, 1),
        source: 'Primary Care',
        category: RecordCategory.medication,
      );
      final spiro = HealthRecord(
        id: 'med-spiro',
        name: 'Spironolactone',
        value: '25 mg oral',
        unit: '',
        recordedAt: DateTime(2026, 10, 2),
        source: 'Primary Care',
        category: RecordCategory.medication,
      );

      final detected = DrugInteractionDatabase.evaluateInteractions([
        lisinopril,
        spiro,
      ]);

      expect(detected.isNotEmpty, isTrue);
      final hyperkalemia = detected.firstWhere(
        (i) => i.interaction.id == 'ddi-acei-arb-potassium',
      );
      expect(hyperkalemia.interaction.severity, DrugInteractionSeverity.high);
      expect(hyperkalemia.interaction.title, contains('Hyperkalemia'));
    });

    test('detects food-drug dietary interaction (Statin + Grapefruit)', () {
      final atorvastatin = HealthRecord(
        id: 'med-atorvastatin',
        name: 'Atorvastatin Calcium',
        value: '40 mg oral tablet',
        unit: '',
        recordedAt: DateTime(2026, 10, 1),
        source: 'Pharmacy',
        category: RecordCategory.medication,
      );

      final detected = DrugInteractionDatabase.evaluateInteractions([
        atorvastatin,
      ]);

      expect(detected.isNotEmpty, isTrue);
      final statinDiet = detected.firstWhere(
        (i) => i.interaction.id == 'fdi-statin-grapefruit',
      );
      expect(statinDiet.isFoodDrug, isTrue);
      expect(statinDiet.interaction.substanceB, contains('Grapefruit'));
      expect(statinDiet.medicationB, isNull);
    });

    test('detects food-drug dietary interaction (Warfarin + Vitamin K)', () {
      final warfarin = HealthRecord(
        id: 'med-warfarin',
        name: 'Coumadin',
        value: '2.5 mg',
        unit: '',
        recordedAt: DateTime(2026, 10, 1),
        source: 'Anticoagulation Clinic',
        category: RecordCategory.medication,
      );

      final detected = DrugInteractionDatabase.evaluateInteractions([warfarin]);

      final vitK = detected.firstWhere(
        (i) => i.interaction.id == 'fdi-warfarin-vitamin-k',
      );
      expect(vitK.isFoodDrug, isTrue);
      expect(vitK.interaction.severity, DrugInteractionSeverity.high);
    });

    test(
      'returns empty list when no interacting medications or dietary risks exist',
      () {
        final amoxicillin = HealthRecord(
          id: 'med-amox',
          name: 'Amoxicillin',
          value: '500 mg oral capsule',
          unit: '',
          recordedAt: DateTime(2026, 10, 1),
          source: 'Urgent Care',
          category: RecordCategory.medication,
        );
        final acetaminophen = HealthRecord(
          id: 'med-tylenol',
          name: 'Acetaminophen',
          value: '500 mg as needed',
          unit: '',
          recordedAt: DateTime(2026, 10, 1),
          source: 'Manual Entry',
          category: RecordCategory.medication,
        );

        final detected = DrugInteractionDatabase.evaluateInteractions([
          amoxicillin,
          acetaminophen,
        ]);

        expect(detected, isEmpty);
      },
    );

    test('deduplicates drug-drug pairs regardless of medication ordering', () {
      final warfarin = HealthRecord(
        id: 'med-1',
        name: 'Warfarin',
        value: '5 mg',
        unit: '',
        recordedAt: DateTime(2026, 10, 1),
        source: 'Clinic',
        category: RecordCategory.medication,
      );
      final aspirin = HealthRecord(
        id: 'med-2',
        name: 'Aspirin',
        value: '81 mg',
        unit: '',
        recordedAt: DateTime(2026, 10, 1),
        source: 'Clinic',
        category: RecordCategory.medication,
      );

      final detected = DrugInteractionDatabase.evaluateInteractions([
        aspirin,
        warfarin,
      ]);

      final warfarinNsaidCount = detected
          .where((i) => i.interaction.id == 'ddi-warfarin-nsaids')
          .length;
      expect(warfarinNsaidCount, 1);
    });
  });
}
