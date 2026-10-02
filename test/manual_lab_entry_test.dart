import 'package:clinical_assistant/models/health_record.dart';
import 'package:clinical_assistant/records/manual_record_entry_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('logs a standard lab result using preset chips', (tester) async {
    List<HealthRecord>? savedRecords;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ManualRecordEntrySheet(
            onSave: (records) => savedRecords = records,
          ),
        ),
      ),
    );

    // Switch to Lab Result
    await tester.ensureVisible(find.text('Lab Result'));
    await tester.tap(find.text('Lab Result'));
    await tester.pumpAndSettle();

    expect(find.text('Log Lab Result'), findsOneWidget);
    expect(find.byKey(const ValueKey('manual-lab-name')), findsOneWidget);

    // Default preset is Hemoglobin A1c
    expect(find.text('Hemoglobin A1c'), findsWidgets);
    expect(find.text('4.0 – 5.6 %'), findsOneWidget);

    // Switch to Total Cholesterol preset
    await tester.tap(
      find.byKey(const ValueKey('manual-lab-preset-Total Cholesterol')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Total Cholesterol'), findsWidgets);
    expect(find.text('< 200 mg/dL'), findsOneWidget);

    // Enter result value
    await tester.enterText(
      find.byKey(const ValueKey('manual-lab-value')),
      '185',
    );
    await tester.pumpAndSettle();

    // Tap Save
    await tester.ensureVisible(find.text('Save Lab Result to Vault'));
    await tester.tap(find.text('Save Lab Result to Vault'));
    await tester.pumpAndSettle();

    expect(savedRecords, isNotNull);
    expect(savedRecords!.length, 1);

    final record = savedRecords!.first;
    expect(record.name, 'Total Cholesterol');
    expect(record.value, '185');
    expect(record.unit, 'mg/dL');
    expect(record.category, RecordCategory.lab);
    expect(record.referenceRange, '< 200 mg/dL');
    expect(record.source, 'Manual Entry');
    expect(record.isManual, isTrue);
  });

  testWidgets(
    'logs a custom lab result with custom reference range and notes',
    (tester) async {
      List<HealthRecord>? savedRecords;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ManualRecordEntrySheet(
              onSave: (records) => savedRecords = records,
            ),
          ),
        ),
      );

      await tester.ensureVisible(find.text('Lab Result'));
      await tester.tap(find.text('Lab Result'));
      await tester.pumpAndSettle();

      // Custom test name
      await tester.enterText(
        find.byKey(const ValueKey('manual-lab-name')),
        'Serum Ferritin',
      );
      await tester.enterText(
        find.byKey(const ValueKey('manual-lab-value')),
        '45.2',
      );
      await tester.enterText(
        find.byKey(const ValueKey('manual-lab-unit')),
        'ng/mL',
      );
      await tester.enterText(
        find.byKey(const ValueKey('manual-lab-ref-range')),
        '30 – 400 ng/mL',
      );

      // Save
      await tester.ensureVisible(find.text('Save Lab Result to Vault'));
      await tester.tap(find.text('Save Lab Result to Vault'));
      await tester.pumpAndSettle();

      expect(savedRecords, isNotNull);
      final record = savedRecords!.single;
      expect(record.name, 'Serum Ferritin');
      expect(record.value, '45.2');
      expect(record.unit, 'ng/mL');
      expect(record.referenceRange, '30 – 400 ng/mL');
      expect(record.category, RecordCategory.lab);
    },
  );
}
