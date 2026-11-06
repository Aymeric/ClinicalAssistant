import 'package:clinical_assistant/models/health_record.dart';
import 'package:clinical_assistant/terminology/clinical_unit_converter.dart';
import 'package:clinical_assistant/trends/health_trend.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ClinicalUnitConverter Core Lab Analytes', () {
    test('converts Blood Glucose between mg/dL and mmol/L bidirectionally', () {
      final conv = ClinicalUnitConverter.findConversion(
        code: '2345-7',
        name: 'Blood Glucose',
        unit: 'mg/dL',
      );
      expect(conv, isNotNull);
      expect(conv!.id, equals('glucose'));
      expect(conv.usUnit, equals('mg/dL'));
      expect(conv.siUnit, equals('mmol/L'));

      // 100 mg/dL -> ~5.55 mmol/L
      final mmol = conv.convert(100.0, fromUnit: 'mg/dL', toUnit: 'mmol/L');
      expect(mmol, isNotNull);
      expect(mmol!, closeTo(5.55, 0.05));

      // 5.5 mmol/L -> ~99.1 mg/dL
      final mgdl = conv.convert(5.5, fromUnit: 'mmol/L', toUnit: 'mg/dL');
      expect(mgdl, isNotNull);
      expect(mgdl!, closeTo(99.1, 0.5));

      final equivFromMgDl = conv.formatSecondaryValue(100.0, 'mg/dL');
      expect(equivFromMgDl, equals('5.5 mmol/L'));

      final equivFromMmol = conv.formatSecondaryValue(5.5, 'mmol/L');
      expect(equivFromMmol, equals('99 mg/dL'));
    });

    test('converts Total Cholesterol between mg/dL and mmol/L', () {
      final conv = ClinicalUnitConverter.findConversion(
        code: '2093-3',
        name: 'Total Cholesterol',
        unit: 'mg/dL',
      );
      expect(conv, isNotNull);

      // 200 mg/dL -> ~5.17 mmol/L
      final mmol = conv!.convert(200.0, fromUnit: 'mg/dL', toUnit: 'mmol/L');
      expect(mmol, isNotNull);
      expect(mmol!, closeTo(5.17, 0.02));

      // 5.0 mmol/L -> ~193.35 mg/dL
      final mgdl = conv.convert(5.0, fromUnit: 'mmol/L', toUnit: 'mg/dL');
      expect(mgdl, isNotNull);
      expect(mgdl!, closeTo(193.35, 0.5));
    });

    test('converts Serum Creatinine between mg/dL and µmol/L (umol/L)', () {
      final conv = ClinicalUnitConverter.findConversion(
        code: '2160-0',
        name: 'Serum Creatinine',
        unit: 'mg/dL',
      );
      expect(conv, isNotNull);

      // 1.0 mg/dL -> 88.4 umol/L
      final umol = conv!.convert(1.0, fromUnit: 'mg/dL', toUnit: 'µmol/L');
      expect(umol, isNotNull);
      expect(umol!, closeTo(88.4, 0.1));

      // Also accepts alias umol/L
      final fromAlias = conv.convert(88.4, fromUnit: 'umol/L', toUnit: 'mg/dL');
      expect(fromAlias, isNotNull);
      expect(fromAlias!, closeTo(1.0, 0.05));
    });

    test('converts Total Bilirubin between mg/dL and µmol/L', () {
      final conv = ClinicalUnitConverter.findConversion(
        code: '1975-2',
        name: 'Total Bilirubin',
        unit: 'mg/dL',
      );
      expect(conv, isNotNull);

      final umol = conv!.convert(1.2, fromUnit: 'mg/dL', toUnit: 'µmol/L');
      expect(umol, isNotNull);
      expect(umol!, closeTo(20.5, 0.2));
    });

    test('converts Total Calcium between mg/dL and mmol/L', () {
      final conv = ClinicalUnitConverter.findConversion(
        code: '17861-6',
        name: 'Calcium',
        unit: 'mg/dL',
      );
      expect(conv, isNotNull);

      final mmol = conv!.convert(9.5, fromUnit: 'mg/dL', toUnit: 'mmol/L');
      expect(mmol, isNotNull);
      expect(mmol!, closeTo(2.37, 0.05));
    });

    test('converts Blood Urea Nitrogen (BUN) between mg/dL and mmol/L', () {
      final conv = ClinicalUnitConverter.findConversion(
        code: '3094-0',
        name: 'BUN',
        unit: 'mg/dL',
      );
      expect(conv, isNotNull);

      final mmol = conv!.convert(20.0, fromUnit: 'mg/dL', toUnit: 'mmol/L');
      expect(mmol, isNotNull);
      expect(mmol!, closeTo(7.14, 0.1));
    });

    test('converts Albumin and Total Protein between g/dL and g/L', () {
      final conv = ClinicalUnitConverter.findConversion(
        code: '1751-7',
        name: 'Albumin',
        unit: 'g/dL',
      );
      expect(conv, isNotNull);

      final gl = conv!.convert(4.2, fromUnit: 'g/dL', toUnit: 'g/L');
      expect(gl, isNotNull);
      expect(gl!, closeTo(42.0, 0.1));
    });

    test('converts Electrolytes between mEq/L and mmol/L 1:1', () {
      final conv = ClinicalUnitConverter.findConversion(
        code: '2951-2',
        name: 'Sodium',
        unit: 'mEq/L',
      );
      expect(conv, isNotNull);

      final mmol = conv!.convert(140.0, fromUnit: 'mEq/L', toUnit: 'mmol/L');
      expect(mmol, isNotNull);
      expect(mmol!, equals(140.0));
    });

    test('checks unit compatibility correctly', () {
      expect(
        ClinicalUnitConverter.areUnitsCompatible(
          'mg/dL',
          'mmol/L',
          name: 'Glucose',
        ),
        isTrue,
      );
      expect(
        ClinicalUnitConverter.areUnitsCompatible(
          'mg/dL',
          'µmol/L',
          name: 'Creatinine',
        ),
        isTrue,
      );
      expect(
        ClinicalUnitConverter.areUnitsCompatible(
          'mg/dL',
          'beats/min',
          name: 'Glucose',
        ),
        isFalse,
      );
    });

    test('converts reference ranges accurately', () {
      const glucoseRange = HealthReferenceRange(
        lowerBound: 70,
        upperBound: 99,
        sourceText: '70 – 99 mg/dL',
      );

      final siRange = ClinicalUnitConverter.convertReferenceRange(
        glucoseRange,
        fromUnit: 'mg/dL',
        targetUnit: 'mmol/L',
        name: 'Glucose',
      );

      expect(siRange, isNotNull);
      expect(siRange!.lowerBound, closeTo(3.9, 0.1));
      expect(siRange.upperBound, closeTo(5.5, 0.1));
      expect(siRange.sourceText, contains('mmol/L'));
    });

    test('resolves canonicalSeriesId for compatible lab records', () {
      final recA = HealthRecord(
        id: 'r1',
        name: 'Blood Glucose',
        value: '100',
        unit: 'mg/dL',
        recordedAt: DateTime.now(),
        category: RecordCategory.lab,
        source: 'LabCorp',
        code: '2345-7',
      );
      final recB = HealthRecord(
        id: 'r2',
        name: 'Glucose [Mass/volume]',
        value: '5.5',
        unit: 'mmol/L',
        recordedAt: DateTime.now(),
        category: RecordCategory.lab,
        source: 'NHS Portal',
        code: '2345-7',
      );

      expect(
        ClinicalUnitConverter.canonicalSeriesId(recA),
        equals(ClinicalUnitConverter.canonicalSeriesId(recB)),
      );
      expect(
        ClinicalUnitConverter.canonicalSeriesId(recA),
        equals('lab:glucose'),
      );
    });
  });
}
