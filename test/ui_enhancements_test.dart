import 'dart:io';

import 'package:clinical_assistant/data/encrypted_record_store.dart';
import 'package:clinical_assistant/integrations/fhir_portal_importer.dart';
import 'package:clinical_assistant/main.dart';
import 'package:clinical_assistant/models/health_record.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';

void main() {
  testWidgets('records page sort menu reorders records dynamically', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final records = [
      HealthRecord(
        id: 'vital:alpha',
        name: 'Alpha Vital',
        value: '10',
        unit: 'bpm',
        recordedAt: DateTime.utc(2025, 5, 1),
        category: RecordCategory.vital,
        source: 'Apple Health',
      ),
      HealthRecord(
        id: 'vital:beta',
        name: 'Beta Vital',
        value: '20',
        unit: 'bpm',
        recordedAt: DateTime.utc(2025, 5, 15),
        category: RecordCategory.vital,
        source: 'Apple Health',
      ),
      HealthRecord(
        id: 'vital:gamma',
        name: 'Gamma Vital',
        value: '30',
        unit: 'bpm',
        recordedAt: DateTime.utc(2025, 5, 8),
        category: RecordCategory.vital,
        source: 'Apple Health',
      ),
    ];

    final controller = HealthDataController(
      store: _MemoryRecordStore(records),
      fhirImporter: FhirPortalImporter(
        client: MockClient((_) async => throw StateError('No net')),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(home: HealthHome(controller: controller)),
    );
    await tester.pumpAndSettle();

    // Navigate to Records tab
    await tester.tap(find.byIcon(Icons.list_alt_outlined));
    await tester.pumpAndSettle();

    // Default sort: newestFirst -> Beta (May 15), Gamma (May 8), Alpha (May 1)
    double betaY = tester.getTopLeft(find.text('Beta Vital')).dy;
    double gammaY = tester.getTopLeft(find.text('Gamma Vital')).dy;
    double alphaY = tester.getTopLeft(find.text('Alpha Vital')).dy;
    expect(betaY < gammaY, isTrue);
    expect(gammaY < alphaY, isTrue);

    // Change to Oldest first -> Alpha (May 1), Gamma (May 8), Beta (May 15)
    await tester.tap(find.byKey(const ValueKey('record-sort-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Oldest first'));
    await tester.pumpAndSettle();

    alphaY = tester.getTopLeft(find.text('Alpha Vital')).dy;
    gammaY = tester.getTopLeft(find.text('Gamma Vital')).dy;
    betaY = tester.getTopLeft(find.text('Beta Vital')).dy;
    expect(alphaY < gammaY, isTrue);
    expect(gammaY < betaY, isTrue);

    // Change to Name (Z–A) -> Gamma, Beta, Alpha
    await tester.tap(find.byKey(const ValueKey('record-sort-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Name (Z–A)'));
    await tester.pumpAndSettle();

    gammaY = tester.getTopLeft(find.text('Gamma Vital')).dy;
    betaY = tester.getTopLeft(find.text('Beta Vital')).dy;
    alphaY = tester.getTopLeft(find.text('Alpha Vital')).dy;
    expect(gammaY < betaY, isTrue);
    expect(betaY < alphaY, isTrue);

    // Change to Name (A–Z) -> Alpha, Beta, Gamma
    await tester.tap(find.byKey(const ValueKey('record-sort-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Name (A–Z)'));
    await tester.pumpAndSettle();

    alphaY = tester.getTopLeft(find.text('Alpha Vital')).dy;
    betaY = tester.getTopLeft(find.text('Beta Vital')).dy;
    gammaY = tester.getTopLeft(find.text('Gamma Vital')).dy;
    expect(alphaY < betaY, isTrue);
    expect(betaY < gammaY, isTrue);
  });

  testWidgets(
    'overview category badge navigates to records with category filter',
    (tester) async {
      tester.view.physicalSize = const Size(420, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final records = [
        HealthRecord(
          id: 'vital:1',
          name: 'Resting heart rate',
          value: '68',
          unit: 'bpm',
          recordedAt: DateTime.utc(2025, 5, 10),
          category: RecordCategory.vital,
          source: 'Health Connect',
        ),
        HealthRecord(
          id: 'lab:1',
          name: 'Serum Potassium',
          value: '4.2',
          unit: 'mmol/L',
          recordedAt: DateTime.utc(2025, 5, 8),
          category: RecordCategory.lab,
          source: 'Hospital Lab',
        ),
      ];

      final controller = HealthDataController(
        store: _MemoryRecordStore(records),
        fhirImporter: FhirPortalImporter(
          client: MockClient((_) async => throw StateError('No net')),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(home: HealthHome(controller: controller)),
      );
      await tester.pumpAndSettle();

      // Scroll to Category breakdown in Overview
      await tester.scrollUntilVisible(
        find.text('Categories'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.text('Categories'), findsOneWidget);
      expect(find.text('Vitals'), findsWidgets);
      expect(find.text('Labs'), findsWidgets);

      // Tap on the Vitals badge in Overview
      await tester.tap(find.text('Vitals').first);
      await tester.pumpAndSettle();

      // Verify we navigated to Records tab and Vitals filter is active
      expect(find.byKey(const ValueKey('record-search')), findsOneWidget);
      expect(find.text('Resting heart rate'), findsOneWidget);
      expect(find.text('Serum Potassium'), findsNothing);
    },
  );

  testWidgets(
    'record detail modal bottom sheet opens with copy actions and raw JSON inspector',
    (tester) async {
      tester.view.physicalSize = const Size(420, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final record = HealthRecord(
        id: 'fhir:potassium',
        name: 'Serum Potassium',
        value: '4.2',
        unit: 'mmol/L',
        recordedAt: DateTime.utc(2025, 5, 8, 14, 30),
        category: RecordCategory.lab,
        source: 'Hospital Lab',
        referenceRange: '3.5 - 5.0 mmol/L',
        status: 'final',
        code: '2823-3',
        sourceId: 'obs-potassium-01',
        sourceData: {
          'resourceType': 'Observation',
          'id': 'obs-potassium-01',
          'status': 'final',
          'code': {
            'coding': [
              {'system': 'http://loinc.org', 'code': '2823-3'},
            ],
          },
        },
      );

      final controller = HealthDataController(
        store: _MemoryRecordStore([record]),
        fhirImporter: FhirPortalImporter(
          client: MockClient((_) async => throw StateError('No net')),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(home: HealthHome(controller: controller)),
      );
      await tester.pumpAndSettle();

      // Go to records tab
      await tester.tap(find.byIcon(Icons.list_alt_outlined));
      await tester.pumpAndSettle();

      // Tap on the record to open detail sheet
      await tester.tap(find.text('Serum Potassium'));
      await tester.pumpAndSettle();

      // Verify sheet details: 3 occurrences of '4.2 mmol/L' (list row behind sheet, header value, detail line)
      expect(find.text('4.2 mmol/L'), findsNWidgets(3));
      expect(find.byTooltip('Copy value'), findsOneWidget);
      expect(find.byTooltip('Copy all details'), findsOneWidget);
      expect(find.text('Reference range'), findsOneWidget);
      expect(find.text('3.5 - 5.0 mmol/L'), findsOneWidget);
      expect(find.text('Source status'), findsOneWidget);
      expect(find.text('final'), findsOneWidget);
      expect(find.text('Code'), findsOneWidget);
      expect(find.text('2823-3'), findsOneWidget);
      expect(find.text('Source ID'), findsOneWidget);
      expect(find.text('obs-potassium-01'), findsOneWidget);

      // Verify Copy value works and triggers snackbar
      await tester.tap(find.byTooltip('Copy value'));
      await tester.pump();
      expect(find.text('Value copied to clipboard'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      // Scroll inside bottom sheet to reveal Raw Source / FHIR Data tile
      await tester.ensureVisible(find.text('Raw Source / FHIR Data'));
      await tester.pumpAndSettle();

      expect(find.text('Raw Source / FHIR Data'), findsOneWidget);
      expect(find.text('Copy JSON'), findsOneWidget);
      expect(find.textContaining('http://loinc.org'), findsNothing);

      // Expand raw source inspector
      await tester.tap(find.text('Raw Source / FHIR Data'));
      await tester.pumpAndSettle();
      expect(find.textContaining('http://loinc.org'), findsOneWidget);

      // Scroll to and copy raw JSON to trigger snackbar
      final copyBtn = find.byKey(const ValueKey('record-copy-json-button'));
      await tester.ensureVisible(copyBtn);
      await tester.pumpAndSettle();
      await tester.tap(copyBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Raw JSON copied to clipboard'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'record details sheet View in Trends shortcut jumps to Trends tab',
    (tester) async {
      tester.view.physicalSize = const Size(420, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final record = HealthRecord(
        id: 'vital:pulse',
        name: 'Pulse rate',
        value: '72',
        unit: 'bpm',
        recordedAt: DateTime.utc(2025, 5, 8, 9, 0),
        category: RecordCategory.vital,
        source: 'Apple Health',
      );

      final controller = HealthDataController(
        store: _MemoryRecordStore([record]),
        fhirImporter: FhirPortalImporter(
          client: MockClient((_) async => throw StateError('No net')),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(home: HealthHome(controller: controller)),
      );
      await tester.pumpAndSettle();

      // Go to records tab
      await tester.tap(find.byIcon(Icons.list_alt_outlined));
      await tester.pumpAndSettle();

      // Tap record to open sheet
      await tester.tap(find.text('Pulse rate'));
      await tester.pumpAndSettle();

      // Tap 'View in Trends'
      expect(find.text('View in Trends'), findsOneWidget);
      await tester.tap(find.text('View in Trends'));
      await tester.pumpAndSettle();

      // Sheet should be closed and Trends page should be active
      expect(find.text('Follow a reading over time.'), findsOneWidget);
      expect(find.text('Pulse rate'), findsOneWidget);
      expect(find.textContaining('Pulse rate'), findsNWidgets(2));
    },
  );

  testWidgets(
    'trend chart scrubbing displays point banner with source and reference info and dismisses',
    (tester) async {
      tester.view.physicalSize = const Size(420, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final records = [
        HealthRecord(
          id: 'vital:bp:1',
          name: 'Systolic blood pressure',
          value: '118',
          unit: 'mmHg',
          recordedAt: DateTime.utc(2025, 5, 1, 8, 0),
          category: RecordCategory.vital,
          source: 'Health Connect',
          referenceRange: '< 120 mmHg',
        ),
        HealthRecord(
          id: 'vital:bp:2',
          name: 'Systolic blood pressure',
          value: '124',
          unit: 'mmHg',
          recordedAt: DateTime.utc(2025, 5, 2, 8, 0),
          category: RecordCategory.vital,
          source: 'Health Connect',
          referenceRange: '< 120 mmHg',
        ),
      ];

      final controller = HealthDataController(
        store: _MemoryRecordStore(records),
        fhirImporter: FhirPortalImporter(
          client: MockClient((_) async => throw StateError('No net')),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(home: HealthHome(controller: controller)),
      );
      await tester.pumpAndSettle();

      // Go to Trends tab
      await tester.tap(find.byIcon(Icons.show_chart_outlined));
      await tester.pumpAndSettle();

      expect(find.text('Recorded values'), findsOneWidget);
      expect(find.byIcon(Icons.touch_app_outlined), findsNothing);

      // Ensure chart canvas is visible and tap on it
      final chartFinder = find.byKey(const ValueKey('trend-chart-canvas'));
      await tester.ensureVisible(chartFinder);
      await tester.pumpAndSettle();
      await tester.tap(chartFinder);
      await tester.pumpAndSettle();

      // Inspection banner appears
      expect(find.byIcon(Icons.touch_app_outlined), findsOneWidget);
      expect(find.textContaining('mmHg'), findsWidgets);
      expect(find.textContaining('Source: Health Connect'), findsOneWidget);
      expect(find.textContaining('Ref: < 120 mmHg'), findsOneWidget);

      // Tap dismiss on banner
      await tester.tap(find.byTooltip('Dismiss'));
      await tester.pumpAndSettle();

      // Banner is removed
      expect(find.byIcon(Icons.touch_app_outlined), findsNothing);
    },
  );

  testWidgets(
    'export page Select all / Clear shortcuts and date preset filtering update export selection',
    (tester) async {
      tester.view.physicalSize = const Size(420, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final now = DateTime.now();
      final records = [
        HealthRecord(
          id: 'vital:recent',
          name: 'Heart Rate',
          value: '72',
          unit: 'bpm',
          recordedAt: now.subtract(const Duration(days: 2)),
          category: RecordCategory.vital,
          source: 'Apple Health',
        ),
        HealthRecord(
          id: 'lab:month',
          name: 'Blood Glucose',
          value: '95',
          unit: 'mg/dL',
          recordedAt: now.subtract(const Duration(days: 20)),
          category: RecordCategory.lab,
          source: 'LabCorp',
        ),
        HealthRecord(
          id: 'vital:older',
          name: 'Resting HR',
          value: '68',
          unit: 'bpm',
          recordedAt: now.subtract(const Duration(days: 60)),
          category: RecordCategory.vital,
          source: 'Apple Health',
        ),
      ];

      final controller = HealthDataController(
        store: _MemoryRecordStore(records),
        fhirImporter: FhirPortalImporter(
          client: MockClient((_) async => throw StateError('No net')),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(home: HealthHome(controller: controller)),
      );
      await tester.pumpAndSettle();

      // Go to Export tab
      await tester.tap(find.byIcon(Icons.ios_share_outlined));
      await tester.pumpAndSettle();

      // Initial: all 3 records selected
      expect(find.text('3 of 3 records selected'), findsOneWidget);
      expect(find.text('Vitals: 2'), findsOneWidget);
      expect(find.text('Labs: 1'), findsOneWidget);

      // Tap Clear shortcut
      await tester.tap(find.byKey(const ValueKey('export-deselect-all')));
      await tester.pumpAndSettle();
      expect(find.text('0 of 3 records selected'), findsOneWidget);
      expect(find.text('Choose a category to continue'), findsOneWidget);

      // Tap Select all shortcut
      await tester.tap(find.byKey(const ValueKey('export-select-all')));
      await tester.pumpAndSettle();
      expect(find.text('3 of 3 records selected'), findsOneWidget);

      // Switch date preset to Last 30 days -> only recent (2d) and month (20d) match
      await tester.tap(find.byKey(const ValueKey('export-date-preset-days30')));
      await tester.pumpAndSettle();
      expect(find.text('2 of 3 records selected'), findsOneWidget);

      // Switch date preset to Last 90 days -> all 3 match
      await tester.tap(find.byKey(const ValueKey('export-date-preset-days90')));
      await tester.pumpAndSettle();
      expect(find.text('3 of 3 records selected'), findsOneWidget);

      // Reset dates via 'All dates' text button
      await tester.tap(find.byKey(const ValueKey('export-date-reset')));
      await tester.pumpAndSettle();
      expect(find.text('3 of 3 records selected'), findsOneWidget);
    },
  );

  testWidgets(
    'overview page metric summary strip and quick action shortcuts navigation',
    (tester) async {
      tester.view.physicalSize = const Size(420, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final now = DateTime.now();
      final records = [
        HealthRecord(
          id: 'vital:1',
          name: 'Heart Rate',
          value: '72',
          unit: 'bpm',
          recordedAt: now.subtract(const Duration(days: 5)),
          category: RecordCategory.vital,
          source: 'Apple Health',
        ),
        HealthRecord(
          id: 'lab:1',
          name: 'Cholesterol',
          value: '180',
          unit: 'mg/dL',
          recordedAt: now.subtract(const Duration(days: 1)),
          category: RecordCategory.lab,
          source: 'LabCorp',
        ),
      ];

      final controller = HealthDataController(
        store: _MemoryRecordStore(records),
        fhirImporter: FhirPortalImporter(
          client: MockClient((_) async => throw StateError('No net')),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(home: HealthHome(controller: controller)),
      );
      await tester.pumpAndSettle();

      // Scroll to reveal overview metric strip
      await tester.scrollUntilVisible(
        find.text('Quick actions'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      // Metric strip shows total records (2) and types (2)
      expect(find.text('Records'), findsWidgets);
      expect(find.text('Types'), findsOneWidget);
      expect(find.text('Span'), findsOneWidget);

      // Tap Quick Action: Trends
      await tester.tap(find.byKey(const ValueKey('overview-action-trends')));
      await tester.pumpAndSettle();
      expect(find.text('Follow a reading over time.'), findsOneWidget);

      // Return to Overview
      await tester.tap(find.byIcon(Icons.space_dashboard_outlined));
      await tester.pumpAndSettle();

      // Scroll to Quick actions and tap Records
      await tester.scrollUntilVisible(
        find.text('Quick actions'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('overview-action-records')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('record-search')), findsOneWidget);

      // Return to Overview
      await tester.tap(find.byIcon(Icons.space_dashboard_outlined));
      await tester.pumpAndSettle();

      // Scroll to Quick actions and tap Export
      await tester.scrollUntilVisible(
        find.text('Quick actions'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('overview-action-export')));
      await tester.pumpAndSettle();
      expect(find.text('Include in export'), findsOneWidget);
    },
  );

  testWidgets(
    'records page displays month-year date section headers and quick date preset filters',
    (tester) async {
      tester.view.physicalSize = const Size(420, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final now = DateTime.now();
      final records = [
        HealthRecord(
          id: 'rec:1',
          name: 'Recent Check',
          value: '70',
          unit: 'bpm',
          recordedAt: now.subtract(const Duration(days: 2)),
          category: RecordCategory.vital,
          source: 'Health',
        ),
        HealthRecord(
          id: 'rec:2',
          name: 'Older Check',
          value: '75',
          unit: 'bpm',
          recordedAt: now.subtract(const Duration(days: 45)),
          category: RecordCategory.vital,
          source: 'Health',
        ),
      ];

      final controller = HealthDataController(
        store: _MemoryRecordStore(records),
        fhirImporter: FhirPortalImporter(
          client: MockClient((_) async => throw StateError('No net')),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(home: HealthHome(controller: controller)),
      );
      await tester.pumpAndSettle();

      // Go to Records tab
      await tester.tap(find.byIcon(Icons.list_alt_outlined));
      await tester.pumpAndSettle();

      // Both records are visible initially
      expect(find.text('Recent Check'), findsOneWidget);
      expect(find.text('Older Check'), findsOneWidget);

      // Quick date preset chips are rendered
      expect(find.byKey(const ValueKey('record-preset-all')), findsOneWidget);
      expect(find.byKey(const ValueKey('record-preset-7d')), findsOneWidget);
      expect(find.byKey(const ValueKey('record-preset-30d')), findsOneWidget);
      expect(find.byKey(const ValueKey('record-preset-90d')), findsOneWidget);
      expect(find.byKey(const ValueKey('record-preset-1y')), findsOneWidget);

      // Tap 7D preset -> only Recent Check (2 days ago) matches
      await tester.tap(find.byKey(const ValueKey('record-preset-7d')));
      await tester.pumpAndSettle();
      expect(find.text('Recent Check'), findsOneWidget);
      expect(find.text('Older Check'), findsNothing);

      // Tap All time preset -> both restored
      await tester.tap(find.byKey(const ValueKey('record-preset-all')));
      await tester.pumpAndSettle();
      expect(find.text('Recent Check'), findsOneWidget);
      expect(find.text('Older Check'), findsOneWidget);

      // Sort by Name (A–Z) -> alphabetical headers 'O' and 'R' appear
      await tester.tap(find.byKey(const ValueKey('record-sort-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Name (A–Z)'));
      await tester.pumpAndSettle();
      expect(find.text('O'), findsOneWidget);
      expect(find.text('R'), findsOneWidget);
    },
  );
}

class _MemoryRecordStore extends EncryptedRecordStore {
  _MemoryRecordStore([this.records = const []])
    : super(directory: Directory.systemTemp);

  final List<HealthRecord> records;

  @override
  Future<List<HealthRecord>> load() async => records;

  @override
  Future<void> save(List<HealthRecord> records) async {}

  @override
  Future<void> clear() async {}
}
