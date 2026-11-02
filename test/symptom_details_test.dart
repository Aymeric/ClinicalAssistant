import 'package:clinical_assistant/models/health_record.dart';
import 'package:clinical_assistant/models/symptom_details.dart';
import 'package:clinical_assistant/trends/health_trend.dart';
import 'package:clinical_assistant/trends/trend_chart_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SymptomDetails & SymptomChartEvent', () {
    test('serializes and deserializes SymptomDetails round-trip', () {
      final details = const SymptomDetails(
        name: 'Headache',
        severity: SymptomSeverity.severe,
        category: SymptomCategory.neurological,
        notes: 'Pulsing right temple pain',
      );

      final sourceData = details.withSourceData(null);
      final record = HealthRecord(
        id: 'manual:symptom:1',
        name: 'Headache',
        value: 'Severe',
        unit: '',
        recordedAt: DateTime.utc(2026, 10, 15, 14, 0),
        category: RecordCategory.symptom,
        source: 'Manual Entry',
        sourceData: sourceData,
      );

      final parsed = SymptomDetails.fromRecord(record);
      expect(parsed.name, 'Headache');
      expect(parsed.severity, SymptomSeverity.severe);
      expect(parsed.category, SymptomCategory.neurological);
      expect(parsed.notes, 'Pulsing right temple pain');
    });

    test('extracts symptom events strictly within the chart time window', () {
      final insideRecord = HealthRecord(
        id: 'symp-inside',
        name: 'Dizziness',
        value: 'Moderate',
        unit: '',
        recordedAt: DateTime.utc(2026, 10, 10, 10, 0),
        category: RecordCategory.symptom,
        source: 'Manual Entry',
        sourceData: const SymptomDetails(
          name: 'Dizziness',
          severity: SymptomSeverity.moderate,
          category: SymptomCategory.cardiorespiratory,
        ).withSourceData(null),
      );

      final outsideRecord = HealthRecord(
        id: 'symp-outside',
        name: 'Chest tightness',
        value: 'Mild',
        unit: '',
        recordedAt: DateTime.utc(2026, 9, 1),
        category: RecordCategory.symptom,
        source: 'Apple Health',
      );

      final vitalRecord = HealthRecord(
        id: 'vital-record',
        name: 'Heart Rate',
        value: '75',
        unit: 'bpm',
        recordedAt: DateTime.utc(2026, 10, 10),
        category: RecordCategory.vital,
        source: 'Apple Health',
      );

      final events = SymptomChartEvent.extractEvents(
        [insideRecord, outsideRecord, vitalRecord],
        start: DateTime.utc(2026, 10, 1),
        end: DateTime.utc(2026, 10, 20),
      );

      expect(events.length, 1);
      expect(events.first.name, 'Dizziness');
      expect(events.first.severity, SymptomSeverity.moderate);
      expect(events.first.date, DateTime.utc(2026, 10, 10, 10, 0));
    });

    test('SymptomSeverity maps labels and colors faithfully', () {
      expect(SymptomSeverity.fromString('mild'), SymptomSeverity.mild);
      expect(SymptomSeverity.fromString('severe'), SymptomSeverity.severe);
      expect(SymptomSeverity.fromString('unknown'), SymptomSeverity.moderate);
    });

    testWidgets(
      'renders symptom overlay chip and displays timeline list when toggled',
      (tester) async {
        final points = [
          HealthTrendPoint(
            record: HealthRecord(
              id: 'hr1',
              name: 'Heart Rate',
              value: '72',
              unit: 'bpm',
              recordedAt: DateTime.utc(2026, 10, 1),
              category: RecordCategory.vital,
              source: 'Apple Health',
            ),
            value: 72,
          ),
          HealthTrendPoint(
            record: HealthRecord(
              id: 'hr2',
              name: 'Heart Rate',
              value: '80',
              unit: 'bpm',
              recordedAt: DateTime.utc(2026, 10, 15),
              category: RecordCategory.vital,
              source: 'Apple Health',
            ),
            value: 80,
          ),
        ];

        final symptoms = [
          HealthRecord(
            id: 'symp1',
            name: 'Palpitations',
            value: 'Moderate',
            unit: '',
            recordedAt: DateTime.utc(2026, 10, 8),
            category: RecordCategory.symptom,
            source: 'Manual Entry',
            notes: 'Felt irregular fluttering while resting',
            sourceData: const SymptomDetails(
              name: 'Palpitations',
              severity: SymptomSeverity.moderate,
              category: SymptomCategory.cardiorespiratory,
              notes: 'Felt irregular fluttering while resting',
            ).withSourceData(null),
          ),
        ];

        HealthRecord? tappedRecord;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: TrendChartPanel(
                  points: points,
                  showMovingAverage: false,
                  onMovingAverageChanged: (_) {},
                  symptomRecords: symptoms,
                  onRecordTap: (rec) => tappedRecord = rec,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Symptom markers chip should be visible with count
        final chipFinder = find.byKey(const ValueKey('trend-symptom-markers'));
        expect(chipFinder, findsOneWidget);
        expect(find.text('Symptoms (1)'), findsOneWidget);

        // Timeline not visible before toggle
        expect(find.text('Symptoms in this timeframe'), findsNothing);

        // Tap chip to toggle
        await tester.tap(chipFinder);
        await tester.pumpAndSettle();

        // Timeline should now be visible
        expect(find.text('Symptoms in this timeframe'), findsOneWidget);
        expect(find.text('Palpitations (Moderate)'), findsOneWidget);
        expect(
          find.textContaining('Felt irregular fluttering while resting'),
          findsOneWidget,
        );
        expect(
          find.textContaining(
            'Patient-reported symptoms are displayed chronologically',
          ),
          findsOneWidget,
        );

        // Tap timeline action button
        await tester.tap(find.byTooltip('View symptom details'));
        await tester.pump();
        expect(tappedRecord?.id, 'symp1');
      },
    );
  });
}
