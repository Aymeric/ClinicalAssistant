import 'package:clinical_assistant/models/health_record.dart';
import 'package:clinical_assistant/terminology/clinical_unit_converter.dart';
import 'package:clinical_assistant/trends/health_trend.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HealthTrend Dual-Unit Normalization & Grouping', () {
    final now = DateTime.utc(2026, 11, 1);
    final glucoseUsRecord = HealthRecord(
      id: 'gl-us',
      name: 'Blood Glucose',
      value: '99',
      unit: 'mg/dL',
      recordedAt: now.subtract(const Duration(days: 10)),
      category: RecordCategory.lab,
      source: 'Quest Diagnostics',
      code: '2345-7',
      referenceRange: '70 – 99 mg/dL',
    );
    final glucoseSiRecord = HealthRecord(
      id: 'gl-si',
      name: 'Blood Glucose',
      value: '5.5',
      unit: 'mmol/L',
      recordedAt: now.subtract(const Duration(days: 2)),
      category: RecordCategory.lab,
      source: 'NHS Portal',
      code: '2345-7',
      referenceRange: '3.9 – 5.5 mmol/L',
    );

    test(
      'groups compatible multi-unit records into a single HealthTrendSeries',
      () {
        final records = [glucoseUsRecord, glucoseSiRecord];
        final seriesList = buildHealthTrendSeries(records);

        expect(seriesList, hasLength(1));
        final series = seriesList.first;
        expect(series.id, equals('lab:glucose'));
        expect(series.points, hasLength(2));
        expect(series.hasSecondaryUnit, isTrue);
      },
    );

    test('normalizes points to US Conventional when preferred', () {
      final records = [glucoseUsRecord, glucoseSiRecord];
      final seriesList = buildHealthTrendSeries(
        records,
        preferredUnitSystem: ClinicalUnitSystem.usConventional,
      );

      final series = seriesList.first;
      expect(series.unit, equals('mg/dL'));
      expect(series.secondaryUnit, equals('mmol/L'));

      // First point was reported in mg/dL: 99
      expect(series.points[0].value, closeTo(99.0, 0.01));
      expect(
        series.points[0].record.unit,
        equals('mg/dL'),
      ); // raw source preserved!

      // Second point was reported in mmol/L: 5.5 -> ~99.1 mg/dL
      expect(series.points[1].value, closeTo(99.1, 0.5));
      expect(
        series.points[1].record.unit,
        equals('mmol/L'),
      ); // raw source preserved!
    });

    test('normalizes points to International SI when preferred', () {
      final records = [glucoseUsRecord, glucoseSiRecord];
      final seriesList = buildHealthTrendSeries(
        records,
        preferredUnitSystem: ClinicalUnitSystem.internationalSi,
      );

      final series = seriesList.first;
      expect(series.unit, equals('mmol/L'));
      expect(series.secondaryUnit, equals('mg/dL'));

      // First point was 99 mg/dL -> ~5.5 mmol/L
      expect(series.points[0].value, closeTo(5.5, 0.1));
      expect(
        series.points[0].record.unit,
        equals('mg/dL'),
      ); // raw source preserved!

      // Second point was 5.5 mmol/L
      expect(series.points[1].value, closeTo(5.5, 0.01));
      expect(
        series.points[1].record.unit,
        equals('mmol/L'),
      ); // raw source preserved!
    });

    test('adapts reference marks and bands across unit systems', () {
      final records = [glucoseUsRecord, glucoseSiRecord];
      final seriesList = buildHealthTrendSeries(
        records,
        preferredUnitSystem: ClinicalUnitSystem.usConventional,
      );
      final series = seriesList.first;

      final marks = buildHealthTrendReferenceMarks(
        series.points,
        unit: series.unit,
      );

      // Both points have reference ranges that should resolve in the display unit
      expect(marks, hasLength(2));
      expect(marks[0].range.lowerBound, closeTo(70, 0.1));
      expect(
        marks[1].range.lowerBound,
        closeTo(70, 2.0),
      ); // 3.9 mmol/L converted to mg/dL
    });

    test(
      'canonicalTrendSeriesId unifies compatible records while healthTrendSeriesId preserves exact unit identity',
      () {
        final elevatedUs = HealthRecord(
          id: 'r-elevated',
          name: 'Blood Glucose',
          value: '130',
          unit: 'mg/dL',
          recordedAt: now.subtract(const Duration(days: 20)),
          category: RecordCategory.lab,
          code: '2345-7',
          referenceRange: '70 – 99 mg/dL',
          source: 'LabCorp',
        );
        final normalSi = HealthRecord(
          id: 'r-normal',
          name: 'Blood Glucose',
          value: '5.0',
          unit: 'mmol/L',
          recordedAt: now.subtract(const Duration(days: 2)),
          category: RecordCategory.lab,
          code: '2345-7',
          referenceRange: '3.9 – 5.5 mmol/L',
          source: 'NHS Portal',
        );

        expect(canonicalTrendSeriesId(elevatedUs), equals('lab:glucose'));
        expect(canonicalTrendSeriesId(normalSi), equals('lab:glucose'));
        expect(
          healthTrendSeriesId(elevatedUs),
          isNot(equals(healthTrendSeriesId(normalSi))),
        );

        final series = buildHealthTrendSeries([elevatedUs, normalSi]);
        expect(series, hasLength(1));
        expect(series.first.points, hasLength(2));
      },
    );
  });
}
