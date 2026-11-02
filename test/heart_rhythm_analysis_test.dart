import 'package:clinical_assistant/models/health_record.dart';
import 'package:clinical_assistant/trends/health_trend.dart';
import 'package:clinical_assistant/trends/heart_rhythm_analysis_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HeartRhythmAnalysisCard Widget Test', () {
    testWidgets(
      'renders comparative rates, HRV metrics, and irregular rhythm warning',
      (tester) async {
        final records = [
          HealthRecord(
            id: 'hr-resting-1',
            name: 'Resting Heart Rate',
            value: '58',
            unit: 'bpm',
            category: RecordCategory.vital,
            recordedAt: DateTime(2026, 1, 1, 7, 0),
            source: 'Apple Health',
          ),
          HealthRecord(
            id: 'hr-resting-2',
            name: 'Resting Heart Rate',
            value: '62',
            unit: 'bpm',
            category: RecordCategory.vital,
            recordedAt: DateTime(2026, 1, 2, 7, 0),
            source: 'Apple Health',
          ),
          HealthRecord(
            id: 'hr-walking-1',
            name: 'Walking Heart Rate Average',
            value: '94',
            unit: 'bpm',
            category: RecordCategory.vital,
            recordedAt: DateTime(2026, 1, 2, 12, 0),
            source: 'Apple Health',
          ),
          HealthRecord(
            id: 'hr-workout-1',
            name: 'Heart Rate',
            value: '155',
            unit: 'bpm',
            category: RecordCategory.vital,
            recordedAt: DateTime(2026, 1, 2, 17, 30),
            source: 'Apple Health',
          ),
          HealthRecord(
            id: 'hrv-1',
            name: 'Heart Rate Variability (SDNN)',
            value: '46',
            unit: 'ms',
            category: RecordCategory.vital,
            recordedAt: DateTime(2026, 1, 2, 8, 0),
            source: 'Apple Health',
          ),
          HealthRecord(
            id: 'irregular-1',
            name: 'Irregular Heart Rhythm Notification',
            value: '1',
            unit: '',
            category: RecordCategory.vital,
            recordedAt: DateTime(2026, 1, 2, 14, 0),
            source: 'Apple Health',
          ),
        ];

        final series = HealthTrendSeries(
          id: 'vital:heart_rate',
          name: 'Heart Rate',
          unit: 'bpm',
          category: RecordCategory.vital,
          points: [
            HealthTrendPoint(record: records[0], value: 58),
            HealthTrendPoint(record: records[1], value: 62),
          ],
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: HeartRhythmAnalysisCard(
                  allRecords: records,
                  selectedSeries: series,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('heart-rhythm-analysis-card')),
          findsOneWidget,
        );
        expect(find.text('Heart Rhythm & Rate'), findsOneWidget);

        // Verify Resting rate metric box (latest 62, avg 60)
        expect(find.text('Resting Rate'), findsOneWidget);
        expect(find.text('62 bpm'), findsOneWidget);
        expect(find.text('Avg: 60 bpm'), findsOneWidget);

        // Verify Walking rate metric box
        expect(find.text('Walking Avg'), findsOneWidget);
        expect(find.text('94 bpm'), findsOneWidget);

        // Verify Peak workout heart rate (155 bpm)
        expect(find.text('Peak Rate'), findsOneWidget);
        expect(find.text('155 bpm'), findsOneWidget);

        // Verify HRV summary
        expect(
          find.text('Heart Rate Variability (HRV / SDNN)'),
          findsOneWidget,
        );
        expect(find.textContaining('Latest: 46 ms'), findsOneWidget);

        // Verify Irregular Rhythm notification banner
        expect(
          find.text('Irregular Rhythm Notification History'),
          findsOneWidget,
        );
        expect(
          find.textContaining('1 imported notification recorded'),
          findsOneWidget,
        );
      },
    );
  });
}
