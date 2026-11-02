import 'package:clinical_assistant/models/health_record.dart';
import 'package:clinical_assistant/records/manual_record_entry_sheet.dart';
import 'package:clinical_assistant/trends/health_trend.dart';
import 'package:clinical_assistant/trends/health_trends_page.dart';
import 'package:clinical_assistant/trends/trend_chart_panel.dart';
import 'package:clinical_assistant/ui/records/record_details_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HealthRecord measurementContext resolution', () {
    test('defaults to Unspecified when no context metadata is present', () {
      final record = HealthRecord(
        id: 'rec-1',
        name: 'Blood Glucose',
        value: '95',
        unit: 'mg/dL',
        recordedAt: DateTime.utc(2025, 6, 1),
        category: RecordCategory.lab,
        source: 'Lab Corp',
      );

      expect(record.measurementContext, 'Unspecified');
      expect(record.hasExplicitMeasurementContext, isFalse);
    });

    test('resolves from explicit sourceData measurementContext', () {
      final record = HealthRecord(
        id: 'rec-2',
        name: 'Blood Glucose',
        value: '140',
        unit: 'mg/dL',
        recordedAt: DateTime.utc(2025, 6, 1),
        category: RecordCategory.lab,
        source: 'Manual Entry',
        sourceData: const {'measurementContext': 'Post-meal (2 hr)'},
      );

      expect(record.measurementContext, 'Post-meal (2 hr)');
      expect(record.hasExplicitMeasurementContext, isTrue);
    });

    test('resolves from health platform metadata meal keys in sourceData', () {
      final record = HealthRecord(
        id: 'rec-3',
        name: 'Blood Glucose',
        value: '92',
        unit: 'mg/dL',
        recordedAt: DateTime.utc(2025, 6, 1),
        category: RecordCategory.lab,
        source: 'HealthKit',
        sourceData: const {
          'metadata': {'meal_type': 'Fasting'},
        },
      );

      expect(record.measurementContext, 'Fasting');
      expect(record.hasExplicitMeasurementContext, isTrue);
    });

    test('resolves backward-compatible context from notes text', () {
      final record = HealthRecord(
        id: 'rec-4',
        name: 'Blood Glucose',
        value: '110',
        unit: 'mg/dL',
        recordedAt: DateTime.utc(2025, 6, 1),
        category: RecordCategory.lab,
        source: 'Manual Entry',
        notes: 'Context: Pre-meal · Felt hungry before lunch',
      );

      expect(record.measurementContext, 'Pre-meal');
      expect(record.hasExplicitMeasurementContext, isTrue);
    });
  });

  group('ManualRecordEntrySheet glucose context tagging', () {
    testWidgets('stores structured measurementContext in sourceData', (
      tester,
    ) async {
      List<HealthRecord>? savedRecords;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ManualRecordEntrySheet(
              onSave: (records) {
                savedRecords = records;
              },
            ),
          ),
        ),
      );

      // Select Blood Glucose type
      await tester.tap(find.text('Blood Glucose'));
      await tester.pumpAndSettle();

      // Enter glucose value
      final valueField = find.widgetWithText(TextFormField, 'Value (mg/dL)');
      await tester.enterText(valueField, '140');

      // Tap Post-meal (2 hr) context chip
      await tester.tap(
        find.byKey(const ValueKey('glucose-context-chip-Post-meal (2 hr)')),
      );
      await tester.pumpAndSettle();

      // Tap Save
      final saveButton = find.text('Save Measurement to Vault');
      await tester.ensureVisible(saveButton);
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      expect(savedRecords, isNotNull);
      expect(savedRecords, hasLength(1));
      final glucoseRecord = savedRecords!.first;
      expect(glucoseRecord.name, 'Blood Glucose');
      expect(glucoseRecord.value, '140');
      expect(
        glucoseRecord.sourceData?['measurementContext'],
        'Post-meal (2 hr)',
      );
      expect(glucoseRecord.measurementContext, 'Post-meal (2 hr)');
      expect(glucoseRecord.hasExplicitMeasurementContext, isTrue);
    });
  });

  group('HealthTrendsPage Context Filtering', () {
    testWidgets(
      'does not show context filter chips when series has only 1 context',
      (tester) async {
        final records = [
          HealthRecord(
            id: 'g1',
            name: 'Blood Glucose',
            value: '90',
            unit: 'mg/dL',
            recordedAt: DateTime.now().subtract(const Duration(days: 2)),
            category: RecordCategory.lab,
            source: 'Lab',
            sourceData: const {'measurementContext': 'Fasting'},
          ),
          HealthRecord(
            id: 'g2',
            name: 'Blood Glucose',
            value: '95',
            unit: 'mg/dL',
            recordedAt: DateTime.now().subtract(const Duration(days: 1)),
            category: RecordCategory.lab,
            source: 'Lab',
            sourceData: const {'measurementContext': 'Fasting'},
          ),
        ];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: HealthTrendsPage(records: records)),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('trend-context-filter-chips')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'displays context filter chips and recalculates summary statistics for active filter',
      (tester) async {
        final records = [
          HealthRecord(
            id: 'g1',
            name: 'Blood Glucose',
            value: '90',
            unit: 'mg/dL',
            recordedAt: DateTime.now().subtract(const Duration(days: 3)),
            category: RecordCategory.lab,
            source: 'Lab',
            sourceData: const {'measurementContext': 'Fasting'},
          ),
          HealthRecord(
            id: 'g2',
            name: 'Blood Glucose',
            value: '100',
            unit: 'mg/dL',
            recordedAt: DateTime.now().subtract(const Duration(days: 2)),
            category: RecordCategory.lab,
            source: 'Lab',
            sourceData: const {'measurementContext': 'Fasting'},
          ),
          HealthRecord(
            id: 'g3',
            name: 'Blood Glucose',
            value: '160',
            unit: 'mg/dL',
            recordedAt: DateTime.now().subtract(const Duration(days: 1)),
            category: RecordCategory.lab,
            source: 'Lab',
            sourceData: const {'measurementContext': 'Post-meal (2 hr)'},
          ),
        ];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: HealthTrendsPage(records: records)),
          ),
        );
        await tester.pumpAndSettle();

        // Context chips should be visible because we have 'Fasting' and 'Post-meal (2 hr)'
        expect(
          find.byKey(const ValueKey('trend-context-filter-chips')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('trend-context-chip-all')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('trend-context-chip-Fasting')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('trend-context-chip-Post-meal (2 hr)')),
          findsOneWidget,
        );

        // All contexts active: average is (90 + 100 + 160) / 3 = 116.67
        expect(find.text('116.67'), findsWidgets);

        // Tap Fasting chip
        await tester.tap(
          find.byKey(const ValueKey('trend-context-chip-Fasting')),
        );
        await tester.pumpAndSettle();

        // Fasting only: 90 and 100 => average is 95
        expect(find.text('95'), findsWidgets);

        // Tap Post-meal (2 hr) chip
        await tester.tap(
          find.byKey(const ValueKey('trend-context-chip-Post-meal (2 hr)')),
        );
        await tester.pumpAndSettle();

        // Post-meal only: 160 => average is 160
        expect(find.text('160'), findsWidgets);

        // Tap All contexts chip
        await tester.tap(find.byKey(const ValueKey('trend-context-chip-all')));
        await tester.pumpAndSettle();

        expect(find.text('116.67'), findsWidgets);
      },
    );
  });

  group('TrendChartPanel inspection banner context tag', () {
    testWidgets('shows context tag when inspected record has context', (
      tester,
    ) async {
      final points = [
        HealthTrendPoint(
          record: HealthRecord(
            id: 'g1',
            name: 'Blood Glucose',
            value: '92',
            unit: 'mg/dL',
            recordedAt: DateTime.utc(2025, 6, 1, 8, 30),
            category: RecordCategory.lab,
            source: 'Manual Entry',
            sourceData: const {'measurementContext': 'Fasting'},
          ),
          value: 92,
        ),
        HealthTrendPoint(
          record: HealthRecord(
            id: 'g2',
            name: 'Blood Glucose',
            value: '105',
            unit: 'mg/dL',
            recordedAt: DateTime.utc(2025, 6, 2, 8, 30),
            category: RecordCategory.lab,
            source: 'Manual Entry',
            sourceData: const {'measurementContext': 'Fasting'},
          ),
          value: 105,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TrendChartPanel(
              points: points,
              showMovingAverage: false,
              onMovingAverageChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap the canvas to trigger inspection
      final canvas = find.byKey(const ValueKey('trend-chart-canvas'));
      expect(canvas, findsOneWidget);
      await tester.tap(canvas);
      await tester.pumpAndSettle();

      // Verify Context is displayed in inspection banner
      expect(find.textContaining('Context: Fasting'), findsOneWidget);
    });
  });

  group('RecordDetailsSheet context display', () {
    testWidgets('shows Measurement context detail line when present', (
      tester,
    ) async {
      final record = HealthRecord(
        id: 'g1',
        name: 'Blood Glucose',
        value: '95',
        unit: 'mg/dL',
        recordedAt: DateTime.utc(2025, 6, 1, 8, 30),
        category: RecordCategory.lab,
        source: 'Manual Entry',
        sourceData: const {'measurementContext': 'Fasting'},
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RecordDetailsSheet(record: record, isNumeric: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Measurement context'), findsOneWidget);
      expect(find.text('Fasting'), findsWidgets);
    });
  });
}
