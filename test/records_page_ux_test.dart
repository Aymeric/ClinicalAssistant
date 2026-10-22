import 'package:clinical_assistant/models/health_record.dart';
import 'package:clinical_assistant/ui/records/records_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('DatePresetChip displays tooltips and semantics labels', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final sampleRecord = HealthRecord(
      id: 'vital-1',
      name: 'Heart Rate',
      category: RecordCategory.vital,
      value: '72',
      unit: 'bpm',
      recordedAt: DateTime.now(),
      source: 'Test Source',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: RecordsPage(records: [sampleRecord])),
      ),
    );

    await tester.pumpAndSettle();

    // Verify DatePresetChip tooltips and semantics for preset keys
    final presetKeys = {
      'record-preset-all': (
        tooltip: 'Filter records from all time',
        semantics: 'All time date range filter',
      ),
      'record-preset-7d': (
        tooltip: 'Filter records from last 7 days',
        semantics: 'Last 7 days date range filter',
      ),
      'record-preset-30d': (
        tooltip: 'Filter records from last 30 days',
        semantics: 'Last 30 days date range filter',
      ),
      'record-preset-90d': (
        tooltip: 'Filter records from last 90 days',
        semantics: 'Last 90 days date range filter',
      ),
      'record-preset-1y': (
        tooltip: 'Filter records from last 1 year',
        semantics: 'Last 1 year date range filter',
      ),
    };

    for (final entry in presetKeys.entries) {
      final chipFinder = find.byKey(ValueKey(entry.key));
      expect(chipFinder, findsOneWidget);

      final tooltip = tester.widget<Tooltip>(
        find.descendant(of: chipFinder, matching: find.byType(Tooltip)).first,
      );
      expect(tooltip.message, equals(entry.value.tooltip));

      final semanticsList = tester
          .widgetList<Semantics>(
            find.descendant(of: chipFinder, matching: find.byType(Semantics)),
          )
          .where((s) => s.properties.label == entry.value.semantics);
      expect(semanticsList, hasLength(1));
      expect(semanticsList.first.properties.button, isTrue);
    }
  });
}
