import 'package:flutter_test/flutter_test.dart';
import 'package:clinical_assistant/models/health_record.dart';
import 'package:clinical_assistant/terminology/loinc_dictionary.dart';

void main() {
  group('LoincDictionary', () {
    test('normalizes LOINC codes with various prefixes and URIs', () {
      expect(LoincDictionary.normalizeCode('2345-7'), '2345-7');
      expect(
        LoincDictionary.normalizeCode('http://loinc.org|2345-7'),
        '2345-7',
      );
      expect(
        LoincDictionary.normalizeCode('https://loinc.org/2345-7'),
        '2345-7',
      );
      expect(LoincDictionary.normalizeCode('loinc:2345-7'), '2345-7');
      expect(LoincDictionary.normalizeCode('  2345-7  '), '2345-7');
    });

    test('lookups concepts by primary and alternate codes', () {
      final glucose = LoincDictionary.lookup('2345-7');
      expect(glucose, isNotNull);
      expect(glucose!.patientFriendlyName, 'Blood Glucose');
      expect(glucose.category, 'Metabolic');

      final altGlucose = LoincDictionary.lookup('http://loinc.org|2339-0');
      expect(altGlucose, isNotNull);
      expect(altGlucose!.patientFriendlyName, 'Blood Glucose');

      final a1c = LoincDictionary.lookup('4548-4');
      expect(a1c, isNotNull);
      expect(a1c!.patientFriendlyName, 'Hemoglobin A1c');

      final unknown = LoincDictionary.lookup('99999-9');
      expect(unknown, isNull);
    });

    test('resolves patient-friendly name falling back to record name', () {
      final glucoseRecord = HealthRecord(
        id: '1',
        name: 'Glucose [Mass/vol] in Serum',
        value: '95',
        unit: 'mg/dL',
        recordedAt: DateTime(2026, 10, 1),
        source: 'LabCorp',
        category: RecordCategory.lab,
        code: '2345-7',
      );
      expect(
        LoincDictionary.resolvePatientFriendlyName(glucoseRecord),
        'Blood Glucose',
      );

      final unknownRecord = HealthRecord(
        id: '2',
        name: 'Special Research Analyte XYZ',
        value: '12',
        unit: 'U/L',
        recordedAt: DateTime(2026, 10, 1),
        source: 'LabCorp',
        category: RecordCategory.lab,
        code: '99999-9',
      );
      expect(
        LoincDictionary.resolvePatientFriendlyName(unknownRecord),
        'Special Research Analyte XYZ',
      );
    });

    test(
      'computes descriptive unit conversions without mutating source values',
      () {
        // Blood glucose mg/dL to mmol/L and vice-versa
        final mmolFromMgdl = LoincDictionary.computeDescriptiveEquivalent(
          value: 90,
          fromUnit: 'mg/dL',
          code: '2345-7',
        );
        expect(mmolFromMgdl, '5.0 mmol/L');

        final mgdlFromMmol = LoincDictionary.computeDescriptiveEquivalent(
          value: 5.0,
          fromUnit: 'mmol/L',
          code: '2345-7',
        );
        expect(mgdlFromMmol, '90 mg/dL');

        // Cholesterol mg/dL to mmol/L (1 mmol/L = 38.67 mg/dL)
        final cholMmol = LoincDictionary.computeDescriptiveEquivalent(
          value: 193.35,
          fromUnit: 'mg/dL',
          code: '2093-3',
        );
        expect(cholMmol, '5.00 mmol/L');

        // Creatinine mg/dL to umol/L (1 mg/dL = 88.4 umol/L)
        final creatUmol = LoincDictionary.computeDescriptiveEquivalent(
          value: 1.0,
          fromUnit: 'mg/dL',
          code: '2160-0',
        );
        expect(creatUmol, '88 umol/L');

        // Incompatible unit returns null
        final invalidUnit = LoincDictionary.computeDescriptiveEquivalent(
          value: 90,
          fromUnit: 'g/L',
          code: '2345-7',
        );
        expect(invalidUnit, isNull);

        // Unknown code returns null
        final unknownCode = LoincDictionary.computeDescriptiveEquivalent(
          value: 90,
          fromUnit: 'mg/dL',
          code: 'unknown',
        );
        expect(unknownCode, isNull);
      },
    );
  });
}
