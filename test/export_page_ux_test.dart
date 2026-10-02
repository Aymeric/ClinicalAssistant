import 'package:clinical_assistant/models/health_record.dart';
import 'package:clinical_assistant/ui/export/export_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('ExportPage filter chips display accessible tooltips', (
    WidgetTester tester,
  ) async {
    final sampleRecord = HealthRecord(
      id: 'vitals-1',
      name: 'Heart Rate',
      category: RecordCategory.vitals,
      value: '72 bpm',
      recordedAt: DateTime.now(),
      source: 'Test',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ExportPage(
            records: [sampleRecord],
            exporting: false,
            onPdf: (_) {},
            onFhir: (_) {},
            onCsv: (_) {},
          ),
        ),
      ),
    );

    // Verify initial chip tooltip (selected state)
    final chipFinder = find.byType(FilterChip);
    expect(chipFinder, findsOneWidget);

    final FilterChip initialChip = tester.widget(chipFinder);
    expect(initialChip.tooltip, equals('Exclude Vitals from export'));

    // Tap to deselect
    await tester.tap(chipFinder);
    await tester.pumpAndSettle();

    final FilterChip deselectedChip = tester.widget(chipFinder);
    expect(deselectedChip.tooltip, equals('Include Vitals in export'));
  });
}
