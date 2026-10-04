import 'package:clinical_assistant/models/health_record.dart';
import 'package:clinical_assistant/trends/health_trend.dart';
import 'package:clinical_assistant/trends/trend_chart_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Trends Enhancements & Dual-Metric Blood Pressure', () {
    test(
      'synthesizes combined blood pressure series when systolic and diastolic exist',
      () {
        final records = [
          HealthRecord(
            id: 'bp:sys:1',
            name: 'Blood Pressure Systolic',
            value: '128',
            unit: 'mmHg',
            recordedAt: DateTime.utc(2025, 6, 1, 8, 0),
            category: RecordCategory.vital,
            source: 'Apple Health',
          ),
          HealthRecord(
            id: 'bp:dia:1',
            name: 'Blood Pressure Diastolic',
            value: '82',
            unit: 'mmHg',
            recordedAt: DateTime.utc(2025, 6, 1, 8, 0),
            category: RecordCategory.vital,
            source: 'Apple Health',
          ),
          HealthRecord(
            id: 'bp:sys:2',
            name: 'Blood Pressure Systolic',
            value: '122',
            unit: 'mmHg',
            recordedAt: DateTime.utc(2025, 6, 2, 8, 0),
            category: RecordCategory.vital,
            source: 'Apple Health',
          ),
          HealthRecord(
            id: 'bp:dia:2',
            name: 'Blood Pressure Diastolic',
            value: '78',
            unit: 'mmHg',
            recordedAt: DateTime.utc(2025, 6, 2, 8, 0),
            category: RecordCategory.vital,
            source: 'Apple Health',
          ),
        ];

        final seriesList = buildHealthTrendSeries(records);
        final combined = seriesList.firstWhere(
          (s) => s.id == 'combined_blood_pressure',
        );

        expect(combined.name, 'Blood Pressure');
        expect(combined.points.length, 2);
        expect(combined.secondaryPoints.length, 2);
        expect(combined.secondaryName, 'Diastolic');
        expect(combined.referenceBand?.lowerBound, 90);
        expect(combined.referenceBand?.upperBound, 120);

        // Points are sorted ascending
        expect(combined.points.first.value, 128);
        expect(combined.points.last.value, 122);
        expect(combined.secondaryPoints.first.value, 82);
        expect(combined.secondaryPoints.last.value, 78);
      },
    );

    test('findReferenceBand extracts reference range from points', () {
      final points = [
        HealthTrendPoint(
          record: HealthRecord(
            id: 'glu:1',
            name: 'Glucose',
            value: '95',
            unit: 'mg/dL',
            recordedAt: DateTime.utc(2025, 5, 1),
            category: RecordCategory.lab,
            source: 'LabCorp',
            referenceRange: '70 - 99 mg/dL',
          ),
          value: 95,
        ),
      ];

      final band = findReferenceBand(points, unit: 'mg/dL');
      expect(band, isNotNull);
      expect(band?.lowerBound, 70);
      expect(band?.upperBound, 99);
      expect(band?.sourceText, '70 - 99 mg/dL');
    });

    testWidgets(
      'TrendChartPanel renders dual-metric series and reference band',
      (tester) async {
        final sysRecord = HealthRecord(
          id: 'sys:1',
          name: 'Blood Pressure Systolic',
          value: '120',
          unit: 'mmHg',
          recordedAt: DateTime.utc(2025, 5, 1),
          category: RecordCategory.vital,
          source: 'Manual',
        );
        final diaRecord = HealthRecord(
          id: 'dia:1',
          name: 'Blood Pressure Diastolic',
          value: '80',
          unit: 'mmHg',
          recordedAt: DateTime.utc(2025, 5, 1),
          category: RecordCategory.vital,
          source: 'Manual',
        );

        final points = [HealthTrendPoint(record: sysRecord, value: 120)];
        final secondaryPoints = [
          HealthTrendPoint(record: diaRecord, value: 80),
        ];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TrendChartPanel(
                points: points,
                secondaryPoints: secondaryPoints,
                primaryName: 'Systolic',
                secondaryName: 'Diastolic',
                referenceBand: const HealthReferenceRange(
                  lowerBound: 90,
                  upperBound: 120,
                  sourceText: '90 - 120 mmHg',
                ),
                showMovingAverage: false,
                onMovingAverageChanged: (_) {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Systolic'), findsOneWidget);
        expect(find.text('Diastolic'), findsOneWidget);
      },
    );
  });
}
