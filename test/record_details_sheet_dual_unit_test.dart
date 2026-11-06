import 'package:clinical_assistant/models/health_record.dart';
import 'package:clinical_assistant/ui/records/record_details_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'RecordDetailsSheet displays secondary unit equivalent and reference range equivalent',
    (WidgetTester tester) async {
      final record = HealthRecord(
        id: 'glucose-1',
        name: 'Blood Glucose',
        value: '100',
        unit: 'mg/dL',
        recordedAt: DateTime(2026, 11, 1, 8, 30),
        category: RecordCategory.lab,
        source: 'Quest Diagnostics',
        code: '2345-7',
        referenceRange: '70 – 99 mg/dL',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RecordDetailsSheet(record: record, isNumeric: true),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify raw reported value is displayed
      expect(find.text('100 mg/dL'), findsWidgets);

      // Verify secondary unit equivalent is displayed
      expect(find.text('Secondary unit equivalent'), findsOneWidget);
      expect(
        find.textContaining('5.5 mmol/L (calculated equivalent)'),
        findsOneWidget,
      );

      // Verify reference range equivalent is displayed
      expect(find.text('Reference range equivalent'), findsOneWidget);
      expect(find.textContaining('mmol/L (calculated)'), findsOneWidget);
    },
  );
}
