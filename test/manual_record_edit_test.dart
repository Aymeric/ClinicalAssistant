import 'package:clinical_assistant/models/health_record.dart';
import 'package:clinical_assistant/models/manual_medication_details.dart';
import 'package:clinical_assistant/records/manual_record_edit_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final recordedAt = DateTime.utc(2025, 5, 10, 8);

  HealthRecord manualRecord({
    required String id,
    required String name,
    required String value,
    String unit = 'bpm',
    DateTime? date,
  }) {
    return HealthRecord(
      id: id,
      name: name,
      value: value,
      unit: unit,
      recordedAt: date ?? recordedAt,
      category: RecordCategory.vital,
      source: 'Manual Entry',
      referenceRange: '60 – 100 bpm',
      notes: 'Before breakfast',
    );
  }

  test(
    'manual edits change only value and recorded date, preserving identity',
    () {
      final record = manualRecord(
        id: 'manual:hr:1',
        name: 'Heart Rate',
        value: '68',
      );
      final imported = record.copyWith(
        id: 'health:other',
        name: 'Imported Heart Rate',
        source: 'Apple Health',
        recordedAt: recordedAt.subtract(const Duration(days: 1)),
      );
      final edit = record.copyWith(
        id: 'manual:hr:1',
        value: '72',
        recordedAt: DateTime.utc(2025, 5, 11, 9),
        name: 'Changed name',
        unit: 'changed unit',
        notes: 'Changed note',
      );

      final updated = applyManualRecordEdits([record, imported], [edit]);

      expect(updated.first.id, record.id);
      expect(updated.first.name, record.name);
      expect(updated.first.value, '72');
      expect(updated.first.unit, record.unit);
      expect(updated.first.recordedAt, DateTime.utc(2025, 5, 11, 9));
      expect(updated.first.notes, record.notes);
      expect(updated.last, imported);
    },
  );

  test('manual edits reject imported records', () {
    final imported = manualRecord(
      id: 'health:hr:1',
      name: 'Heart Rate',
      value: '68',
    ).copyWith(source: 'Apple Health');

    expect(
      () =>
          applyManualRecordEdits([imported], [imported.copyWith(value: '72')]),
      throwsStateError,
    );
  });

  test('blood-pressure pair must be edited together', () {
    final systolic = manualRecord(
      id: 'manual:sys:1',
      name: 'Systolic Blood Pressure',
      value: '120',
      unit: 'mmHg',
    );
    final diastolic = manualRecord(
      id: 'manual:dia:1',
      name: 'Diastolic Blood Pressure',
      value: '80',
      unit: 'mmHg',
    );

    expect(
      () => applyManualRecordEdits(
        [systolic, diastolic],
        [systolic.copyWith(value: '125')],
      ),
      throwsStateError,
    );
    expect(
      () => applyManualRecordEdits(
        [systolic, diastolic],
        [
          systolic.copyWith(
            value: '125',
            recordedAt: recordedAt.add(const Duration(minutes: 1)),
          ),
          diastolic.copyWith(value: '82'),
        ],
      ),
      throwsStateError,
    );

    final updated = applyManualRecordEdits(
      [systolic, diastolic],
      [systolic.copyWith(value: '125'), diastolic.copyWith(value: '82')],
    );
    expect(updated.map((record) => record.value), ['125', '82']);
  });

  test('medication edits preserve metadata and require a valid end date', () {
    final medication = HealthRecord(
      id: 'manual:medication:1',
      name: 'Example Medicine',
      value: '10 mg',
      unit: '',
      recordedAt: recordedAt,
      category: RecordCategory.medication,
      source: 'Manual Entry',
      status: 'active',
      sourceData: {
        'otherMetadata': 'preserved',
        ...ManualMedicationDetails(
          frequency: 'once daily',
          route: 'oral',
        ).withSourceData(null),
      },
    );

    expect(
      () => applyManualRecordEdits(
        [medication],
        [medication.copyWith(status: 'stopped')],
      ),
      throwsStateError,
    );

    final edit = medication.copyWith(
      value: '20 mg',
      status: 'stopped',
      sourceData: ManualMedicationDetails(
        frequency: 'twice daily',
        route: 'oral',
        endDate: DateTime(2025, 5, 12),
      ).withSourceData(medication.sourceData),
    );
    final updated = applyManualRecordEdits([medication], [edit]).single;

    expect(updated.id, medication.id);
    expect(updated.source, medication.source);
    expect(updated.value, '20 mg');
    expect(updated.status, 'stopped');
    expect(updated.sourceData?['otherMetadata'], 'preserved');
    expect(
      ManualMedicationDetails.fromRecord(updated).frequency,
      'twice daily',
    );
  });

  testWidgets(
    'editor saves a corrected value while preserving record metadata',
    (tester) async {
      final record = manualRecord(
        id: 'manual:hr:1',
        name: 'Heart Rate',
        value: '68',
      );
      List<HealthRecord>? saved;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => ManualRecordEditSheet(
                      records: [record],
                      onSave: (records) async => saved = records,
                    ),
                  ),
                  child: const Text('Open editor'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open editor'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('edit-record-value')),
        '72',
      );
      await tester.tap(find.byKey(const ValueKey('save-manual-record-edit')));
      await tester.pumpAndSettle();

      expect(saved, hasLength(1));
      expect(saved!.single.id, record.id);
      expect(saved!.single.name, record.name);
      expect(saved!.single.value, '72');
      expect(saved!.single.recordedAt, record.recordedAt);
      expect(saved!.single.source, record.source);
      expect(saved!.single.notes, record.notes);
    },
  );

  testWidgets('editor validates numeric values before saving', (tester) async {
    final record = manualRecord(
      id: 'manual:hr:1',
      name: 'Heart Rate',
      value: '68',
    );
    var didSave = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => ManualRecordEditSheet(
                    records: [record],
                    onSave: (_) async => didSave = true,
                  ),
                ),
                child: const Text('Open editor'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open editor'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('edit-record-value')),
      'not a number',
    );
    await tester.tap(find.byKey(const ValueKey('save-manual-record-edit')));
    await tester.pumpAndSettle();

    expect(didSave, isFalse);
    expect(find.text('Enter a valid number'), findsOneWidget);
  });

  testWidgets('editor updates blood-pressure values as a pair', (tester) async {
    final systolic = manualRecord(
      id: 'manual:sys:1',
      name: 'Systolic Blood Pressure',
      value: '120',
      unit: 'mmHg',
    );
    final diastolic = manualRecord(
      id: 'manual:dia:1',
      name: 'Diastolic Blood Pressure',
      value: '80',
      unit: 'mmHg',
    );
    List<HealthRecord>? saved;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => ManualRecordEditSheet(
                    records: [systolic, diastolic],
                    onSave: (records) async => saved = records,
                  ),
                ),
                child: const Text('Open editor'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open editor'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('edit-systolic-value')),
      '125',
    );
    await tester.enterText(
      find.byKey(const ValueKey('edit-diastolic-value')),
      '82',
    );
    await tester.tap(find.byKey(const ValueKey('save-manual-record-edit')));
    await tester.pumpAndSettle();

    expect(saved, hasLength(2));
    expect(saved!.map((record) => record.value), ['125', '82']);
    expect(saved!.map((record) => record.id), [systolic.id, diastolic.id]);
    expect(saved![0].recordedAt, saved![1].recordedAt);
  });

  testWidgets('editor updates manually entered medication details', (
    tester,
  ) async {
    final medication = HealthRecord(
      id: 'manual:medication:1',
      name: 'Example Medicine',
      value: '10 mg',
      unit: '',
      recordedAt: recordedAt,
      category: RecordCategory.medication,
      source: 'Manual Entry',
      status: 'active',
      sourceData: ManualMedicationDetails(
        frequency: 'once daily',
        route: 'oral',
      ).withSourceData(null),
    );
    List<HealthRecord>? saved;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => ManualRecordEditSheet(
                    records: [medication],
                    onSave: (records) async => saved = records,
                  ),
                ),
                child: const Text('Open editor'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open editor'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('edit-record-value')),
      '20 mg',
    );
    await tester.enterText(
      find.byKey(const ValueKey('edit-medication-frequency')),
      'twice daily',
    );
    await tester.enterText(
      find.byKey(const ValueKey('edit-medication-route')),
      'oral',
    );
    await tester.tap(find.byKey(const ValueKey('edit-medication-status')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('On hold').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('save-manual-record-edit')));
    await tester.pumpAndSettle();

    expect(saved, hasLength(1));
    final edited = saved!.single;
    expect(edited.value, '20 mg');
    expect(edited.status, 'on-hold');
    final details = ManualMedicationDetails.fromRecord(edited);
    expect(details.frequency, 'twice daily');
    expect(details.route, 'oral');
  });
}
