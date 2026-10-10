import 'package:clinical_assistant/records/manual_record_entry_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'ManualRecordEntrySheet filter chips display accessible tooltips',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ManualRecordEntrySheet(onSave: (_) {})),
        ),
      );

      for (final type in ManualEntryType.values) {
        final chipFinder = find.widgetWithText(FilterChip, type.label);
        expect(chipFinder, findsOneWidget);

        final filterChip = tester.widget<FilterChip>(chipFinder);
        expect(
          filterChip.tooltip,
          equals('Select ${type.label} measurement type'),
        );
      }
    },
  );
}
