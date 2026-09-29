import 'package:clinical_assistant/models/health_record.dart';
import 'package:clinical_assistant/models/manual_medication_details.dart';
import 'package:clinical_assistant/records/manual_record_entry_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('logs Blood Pressure as systolic and diastolic records', (tester) async {
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

    // Initial state is Blood Pressure with 120 and 80 pre-filled
    expect(find.text('Log Health Measurement'), findsOneWidget);
    expect(find.text('Systolic (mmHg)'), findsOneWidget);
    expect(find.text('Diastolic (mmHg)'), findsOneWidget);

    // Enter personal note
    await tester.enterText(
      find.byType(TextFormField).at(2), // notes controller
      'Morning resting measurement',
    );

    // Tap Save
    await tester.tap(find.text('Save Measurement to Vault'));
    await tester.pump();

    expect(savedRecords, isNotNull);
    expect(savedRecords!.length, 2);

    final sys = savedRecords!.firstWhere((r) => r.name == 'Systolic Blood Pressure');
    final dia = savedRecords!.firstWhere((r) => r.name == 'Diastolic Blood Pressure');

    expect(sys.value, '120');
    expect(sys.unit, 'mmHg');
    expect(sys.isManual, isTrue);
    expect(sys.notes, 'Morning resting measurement');

    expect(dia.value, '80');
    expect(dia.unit, 'mmHg');
    expect(dia.isManual, isTrue);
    expect(dia.notes, 'Morning resting measurement');
  });

  testWidgets('logs Blood Glucose with context tag', (tester) async {
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

    // Switch to Blood Glucose
    await tester.tap(find.text('Blood Glucose'));
    await tester.pump();

    expect(find.text('Value (mg/dL)'), findsOneWidget);

    // Enter glucose value
    await tester.enterText(find.byType(TextFormField).first, '95');

    // Tap Save
    await tester.tap(find.text('Save Measurement to Vault'));
    await tester.pump();

    expect(savedRecords, isNotNull);
    expect(savedRecords!.length, 1);
    final glucose = savedRecords!.first;
    expect(glucose.name, 'Blood Glucose');
    expect(glucose.value, '95');
    expect(glucose.unit, 'mg/dL');
    expect(glucose.category, RecordCategory.lab);
    expect(glucose.notes, contains('Context: Fasting'));
    expect(glucose.isManual, isTrue);
  });

  testWidgets('logs a medication with structured dose, frequency, and route', (
    tester,
  ) async {
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

    await tester.ensureVisible(find.text('Medication'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Medication'));
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('manual-medication-name')),
      'Example Medicine',
    );
    await tester.enterText(
      find.byKey(const ValueKey('manual-medication-dose')),
      '10 mg',
    );
    await tester.enterText(
      find.byKey(const ValueKey('manual-medication-frequency')),
      'once daily',
    );
    await tester.enterText(
      find.byKey(const ValueKey('manual-medication-route')),
      'oral',
    );

    await tester.tap(find.byKey(const ValueKey('manual-medication-status')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Stopped').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save Medication to Vault'));
    await tester.tap(find.text('Save Medication to Vault'));
    await tester.pump();
    expect(savedRecords, isNull);
    expect(find.text('Choose an end date'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const ValueKey('manual-medication-end-date')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('manual-medication-end-date')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save Medication to Vault'));
    await tester.tap(find.text('Save Medication to Vault'));
    await tester.pump();

    expect(savedRecords, hasLength(1));
    final medication = savedRecords!.single;
    expect(medication.name, 'Example Medicine');
    expect(medication.value, '10 mg');
    expect(medication.unit, isEmpty);
    expect(medication.category, RecordCategory.medication);
    expect(medication.status, 'stopped');
    expect(medication.isManual, isTrue);

    final details = ManualMedicationDetails.fromRecord(medication);
    expect(details.frequency, 'once daily');
    expect(details.route, 'oral');
    expect(details.endDate, isNotNull);

    final restored = HealthRecord.fromJson(medication.toJson());
    expect(ManualMedicationDetails.fromRecord(restored).frequency, 'once daily');
    expect(ManualMedicationDetails.fromRecord(restored).route, 'oral');
    expect(ManualMedicationDetails.fromRecord(restored).endDate, isNotNull);
    expect(restored.status, 'stopped');
  });
}
