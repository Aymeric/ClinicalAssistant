import 'package:clinical_assistant/models/health_record.dart';
import 'package:clinical_assistant/models/manual_medication_details.dart';
import 'package:clinical_assistant/trends/health_trend.dart';
import 'package:clinical_assistant/trends/health_trends_page.dart';
import 'package:clinical_assistant/trends/medication_chart_event.dart';
import 'package:clinical_assistant/trends/trend_chart_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MedicationChartEvent extraction', () {
    test('extracts start and end events strictly within the chart window', () {
      final now = DateTime.utc(2025, 6, 15);
      final records = [
        // Medication 1: Started inside window, ongoing
        HealthRecord(
          id: 'med-1',
          name: 'Lisinopril',
          value: '10 mg',
          unit: '',
          recordedAt: DateTime.utc(2025, 6, 5),
          category: RecordCategory.medication,
          source: 'Manual Entry',
        ),
        // Medication 2: Started before window, ended inside window
        HealthRecord(
          id: 'med-2',
          name: 'Metformin',
          value: '500 mg',
          unit: '',
          recordedAt: DateTime.utc(2025, 5, 1),
          category: RecordCategory.medication,
          source: 'MyChart',
          sourceData: ManualMedicationDetails(
            frequency: 'Daily',
            endDate: DateTime.utc(2025, 6, 10),
          ).withSourceData(null),
        ),
        // Medication 3: Outside window completely
        HealthRecord(
          id: 'med-3',
          name: 'Amoxicillin',
          value: '250 mg',
          unit: '',
          recordedAt: DateTime.utc(2025, 1, 1),
          category: RecordCategory.medication,
          source: 'Manual Entry',
          sourceData: ManualMedicationDetails(
            frequency: 'TID',
            endDate: DateTime.utc(2025, 1, 10),
          ).withSourceData(null),
        ),
        // Lab record (should be ignored)
        HealthRecord(
          id: 'lab-1',
          name: 'Blood Glucose',
          value: '95',
          unit: 'mg/dL',
          recordedAt: DateTime.utc(2025, 6, 6),
          category: RecordCategory.lab,
          source: 'LabCorp',
        ),
      ];

      final events = MedicationChartEvent.extractEvents(
        records,
        start: DateTime.utc(2025, 6, 1),
        end: now,
      );

      expect(events, hasLength(2));
      expect(events[0].medicationName, 'Lisinopril');
      expect(events[0].type, MedicationChartEventType.started);
      expect(events[0].date, DateTime.utc(2025, 6, 5));

      expect(events[1].medicationName, 'Metformin');
      expect(events[1].type, MedicationChartEventType.ended);
      expect(events[1].date.year, 2025);
      expect(events[1].date.month, 6);
      expect(events[1].date.day, 10);
    });
  });

  group('TrendChartPanel Medication Start/Stop Overlay', () {
    testWidgets(
      'hides medication chip when no medications exist in timeframe',
      (tester) async {
        final points = [
          HealthTrendPoint(
            record: HealthRecord(
              id: 'g1',
              name: 'Blood Glucose',
              value: '92',
              unit: 'mg/dL',
              recordedAt: DateTime.utc(2025, 6, 1),
              category: RecordCategory.lab,
              source: 'Manual Entry',
            ),
            value: 92,
          ),
          HealthTrendPoint(
            record: HealthRecord(
              id: 'g2',
              name: 'Blood Glucose',
              value: '96',
              unit: 'mg/dL',
              recordedAt: DateTime.utc(2025, 6, 5),
              category: RecordCategory.lab,
              source: 'Manual Entry',
            ),
            value: 96,
          ),
        ];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TrendChartPanel(
                points: points,
                showMovingAverage: false,
                onMovingAverageChanged: (_) {},
                medicationRecords: const [],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('trend-medication-markers')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'displays medication chip and toggles timeline with non-causal disclaimer',
      (tester) async {
        final points = [
          HealthTrendPoint(
            record: HealthRecord(
              id: 'bp1',
              name: 'Blood Pressure Systolic',
              value: '135',
              unit: 'mmHg',
              recordedAt: DateTime.utc(2025, 6, 1),
              category: RecordCategory.vital,
              source: 'Manual Entry',
            ),
            value: 135,
          ),
          HealthTrendPoint(
            record: HealthRecord(
              id: 'bp2',
              name: 'Blood Pressure Systolic',
              value: '120',
              unit: 'mmHg',
              recordedAt: DateTime.utc(2025, 6, 20),
              category: RecordCategory.vital,
              source: 'Manual Entry',
            ),
            value: 120,
          ),
        ];

        final medications = [
          HealthRecord(
            id: 'med-bp',
            name: 'Amlodipine',
            value: '5 mg',
            unit: '',
            recordedAt: DateTime.utc(2025, 6, 10),
            category: RecordCategory.medication,
            source: 'Manual Entry',
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
                  medicationRecords: medications,
                  onRecordTap: (rec) => tappedRecord = rec,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // The medication chip should be visible with count (1)
        final chipFinder = find.byKey(
          const ValueKey('trend-medication-markers'),
        );
        expect(chipFinder, findsOneWidget);
        expect(find.text('Medication dates (1)'), findsOneWidget);

        // Timeline list should not be visible before toggle
        expect(
          find.byKey(const ValueKey('trend-medication-timeline-heading')),
          findsNothing,
        );

        // Tap the chip to enable medication date markers
        await tester.tap(chipFinder);
        await tester.pumpAndSettle();

        // Timeline heading, non-causal disclaimer, and event details should appear
        expect(
          find.byKey(const ValueKey('trend-medication-timeline-heading')),
          findsOneWidget,
        );
        expect(
          find.text(
            'Chronological alignment on a chart is descriptive only and does not imply treatment efficacy or clinical causation.',
          ),
          findsOneWidget,
        );
        expect(find.text('Started: Amlodipine (5 mg)'), findsOneWidget);
        expect(find.textContaining('Source: Manual Entry'), findsOneWidget);
        expect(find.text('Medication started'), findsOneWidget);

        // Tap on view details
        final viewDetailsButton = find.byTooltip('View medication details');
        expect(viewDetailsButton, findsOneWidget);
        await tester.tap(viewDetailsButton);
        await tester.pumpAndSettle();

        expect(tappedRecord?.id, 'med-bp');
      },
    );
  });

  group('HealthTrendsPage Integration', () {
    testWidgets(
      'passes medication records and allows toggling medication markers',
      (tester) async {
        final records = [
          HealthRecord(
            id: 'g1',
            name: 'Blood Glucose',
            value: '95',
            unit: 'mg/dL',
            recordedAt: DateTime.now().subtract(const Duration(days: 10)),
            category: RecordCategory.lab,
            source: 'Lab',
          ),
          HealthRecord(
            id: 'g2',
            name: 'Blood Glucose',
            value: '100',
            unit: 'mg/dL',
            recordedAt: DateTime.now().subtract(const Duration(days: 1)),
            category: RecordCategory.lab,
            source: 'Lab',
          ),
          HealthRecord(
            id: 'med-gl',
            name: 'Metformin',
            value: '500 mg',
            unit: '',
            recordedAt: DateTime.now().subtract(const Duration(days: 5)),
            category: RecordCategory.medication,
            source: 'Clinic Portal',
          ),
        ];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: HealthTrendsPage(records: records)),
          ),
        );
        await tester.pumpAndSettle();

        final chipFinder = find.byKey(
          const ValueKey('trend-medication-markers'),
        );
        expect(chipFinder, findsOneWidget);

        await tester.tap(chipFinder);
        await tester.pumpAndSettle();

        expect(
          find.text(
            'Chronological alignment on a chart is descriptive only and does not imply treatment efficacy or clinical causation.',
          ),
          findsOneWidget,
        );
        expect(find.text('Started: Metformin (500 mg)'), findsOneWidget);
      },
    );
  });
}
