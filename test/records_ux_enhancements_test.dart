import 'dart:io';

import 'package:clinical_assistant/data/encrypted_record_store.dart';
import 'package:clinical_assistant/integrations/fhir_portal_importer.dart';
import 'package:clinical_assistant/main.dart';
import 'package:clinical_assistant/models/health_record.dart';
import 'package:clinical_assistant/sync/foreground_sync_state.dart';
import 'package:clinical_assistant/ui/records/records_page.dart';
import 'package:clinical_assistant/ui/shared/record_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';

class _FakeRecordStore implements EncryptedRecordStore {
  _FakeRecordStore(this.records);
  final List<HealthRecord> records;

  @override
  Directory? get directory => null;

  @override
  Future<List<HealthRecord>> load() async => List.of(records);

  @override
  Future<void> save(List<HealthRecord> records) async {
    this.records
      ..clear()
      ..addAll(records);
  }

  @override
  Future<bool> verifyIntegrity() async => true;

  @override
  Future<void> clear() async => records.clear();
}

class _MemorySyncValueStore implements SyncValueStore {
  final _values = <String, String>{};
  @override
  Future<String?> read(String key) async => _values[key];
  @override
  Future<void> write(String key, String value) async => _values[key] = value;
  @override
  Future<void> delete(String key) async => _values.remove(key);
}

void main() {
  testWidgets('records page filters by out-of-range flag and displays High/Low badges', (
    tester,
  ) async {
    final records = [
      HealthRecord(
        id: 'lab:high_chol',
        name: 'Total Cholesterol',
        value: '240',
        unit: 'mg/dL',
        referenceRange: '< 200 mg/dL',
        recordedAt: DateTime.utc(2025, 5, 10),
        category: RecordCategory.lab,
        source: 'LabCorp',
      ),
      HealthRecord(
        id: 'lab:normal_chol',
        name: 'HDL Cholesterol',
        value: '55',
        unit: 'mg/dL',
        referenceRange: '> 40 mg/dL',
        recordedAt: DateTime.utc(2025, 5, 10),
        category: RecordCategory.lab,
        source: 'LabCorp',
      ),
      HealthRecord(
        id: 'lab:low_potassium',
        name: 'Potassium',
        value: '3.1',
        unit: 'mmol/L',
        referenceRange: '3.5 - 5.0 mmol/L',
        recordedAt: DateTime.utc(2025, 5, 8),
        category: RecordCategory.lab,
        source: 'Quest',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RecordsPage(records: records),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify all 3 records initially present
    expect(find.text('Total Cholesterol'), findsOneWidget);
    expect(find.text('HDL Cholesterol'), findsOneWidget);
    expect(find.text('Potassium'), findsOneWidget);

    // Verify badges are displayed (High and Low)
    expect(find.text('High'), findsOneWidget);
    expect(find.text('Low'), findsOneWidget);

    // Scroll horizontally if needed and tap "Out of range only" filter chip
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('records-out-of-range-filter')),
      100,
      scrollable: find.byType(Scrollable).at(1),
    );
    await tester.tap(find.byKey(const ValueKey('records-out-of-range-filter')));
    await tester.pumpAndSettle();

    // Normal HDL should be filtered out
    expect(find.text('Total Cholesterol'), findsOneWidget);
    expect(find.text('Potassium'), findsOneWidget);
    expect(find.text('HDL Cholesterol'), findsNothing);
  });

  testWidgets('records page filters by source when multiple sources present', (
    tester,
  ) async {
    final records = [
      HealthRecord(
        id: 'lab:1',
        name: 'Glucose',
        value: '95',
        unit: 'mg/dL',
        recordedAt: DateTime.utc(2025, 5, 10),
        category: RecordCategory.lab,
        source: 'LabCorp',
      ),
      HealthRecord(
        id: 'lab:2',
        name: 'TSH',
        value: '2.1',
        unit: 'mIU/L',
        recordedAt: DateTime.utc(2025, 5, 9),
        category: RecordCategory.lab,
        source: 'Quest',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RecordsPage(records: records),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Glucose'), findsOneWidget);
    expect(find.text('TSH'), findsOneWidget);

    // Scroll to the Source: LabCorp chip in the horizontal row
    await tester.scrollUntilVisible(
      find.text('Source: LabCorp'),
      100,
      scrollable: find.byType(Scrollable).at(1),
    );
    await tester.tap(find.text('Source: LabCorp'));
    await tester.pumpAndSettle();

    expect(find.text('Glucose'), findsOneWidget);
    expect(find.text('TSH'), findsNothing);
  });

  testWidgets('overview out-of-range shortcut opens records with out-of-range filter', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final records = [
      HealthRecord(
        id: 'lab:glucose_high',
        name: 'Fasting Glucose',
        value: '135',
        unit: 'mg/dL',
        referenceRange: '70 - 99 mg/dL',
        recordedAt: DateTime.utc(2025, 5, 10),
        category: RecordCategory.lab,
        source: 'LabCorp',
      ),
      HealthRecord(
        id: 'lab:glucose_normal',
        name: 'Albumin',
        value: '4.2',
        unit: 'g/dL',
        referenceRange: '3.4 - 5.4 g/dL',
        recordedAt: DateTime.utc(2025, 5, 10),
        category: RecordCategory.lab,
        source: 'LabCorp',
      ),
    ];

    final controller = HealthDataController(
      store: _FakeRecordStore(records),
      syncValueStore: _MemorySyncValueStore(),
      fhirImporter: FhirPortalImporter(
        client: MockClient((_) async {
          throw StateError(
            'No network request was expected in this widget test.',
          );
        }),
      ),
    );

    await tester.pumpWidget(
      ClinicalAssistantApp(controller: controller),
    );
    await tester.pumpAndSettle();

    // Scroll to Flagged lab results section on Overview
    await tester.scrollUntilVisible(
      find.text('Flagged lab results'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('1 currently out of range'), findsOneWidget);

    // Tap the View button on the out-of-range metric card
    await tester.tap(find.byKey(const ValueKey('overview-view-out-of-range-button')));
    await tester.pumpAndSettle();

    // Now on Records tab: only Fasting Glucose should be shown, Albumin filtered out
    expect(find.text('Fasting Glucose'), findsOneWidget);
    expect(find.text('Albumin'), findsNothing);
  });

  testWidgets('RecordRow renders long display value without horizontal overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(376, 667);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final record = HealthRecord(
      id: 'nutrition:1',
      name: 'Nutrition',
      value:
          'dinner · Potatoes · 80 kcal · 2.1 g protein · 17.2 g carbs · 0.2 g fat',
      unit: '',
      recordedAt: DateTime.utc(2026, 8, 7),
      category: RecordCategory.nutrition,
      source: 'Google Health',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: RecordRow(
              record: record,
              isLast: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nutrition'), findsOneWidget);
    expect(
      find.text(
        'dinner · Potatoes · 80 kcal · 2.1 g protein · 17.2 g carbs · 0.2 g fat',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

