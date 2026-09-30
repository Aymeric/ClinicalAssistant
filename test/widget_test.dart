import 'dart:io';

import 'package:clinical_assistant/data/encrypted_record_store.dart';
import 'package:clinical_assistant/integrations/fhir_portal_importer.dart';
import 'package:clinical_assistant/integrations/health_platform_importer.dart';
import 'package:clinical_assistant/main.dart';
import 'package:clinical_assistant/models/health_record.dart';
import 'package:clinical_assistant/notifications/result_notification_manager.dart';
import 'package:clinical_assistant/notifications/result_notification_preferences.dart';
import 'package:clinical_assistant/sync/foreground_sync_state.dart';
import 'package:clinical_assistant/sync/import_progress.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';

void main() {
  testWidgets('follows the system appearance with a dark color scheme', (
    tester,
  ) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    final controller = HealthDataController(
      store: _MemoryRecordStore(),
      syncValueStore: _MemorySyncValueStore(),
      fhirImporter: FhirPortalImporter(
        client: MockClient((_) async {
          throw StateError(
            'No network request was expected in this widget test.',
          );
        }),
      ),
    );

    await tester.pumpWidget(ClinicalAssistantApp(controller: controller));
    await tester.pumpAndSettle();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.system);
    expect(app.theme?.brightness, Brightness.light);
    expect(app.darkTheme?.brightness, Brightness.dark);
    expect(
      Theme.of(tester.element(find.text('Your health history,\nall together.')))
          .brightness,
      Brightness.dark,
    );
  });

  testWidgets('opens numeric trends from primary navigation', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = HealthDataController(
      store: _MemoryRecordStore([_recordForDate('Heart rate', DateTime.now())]),
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
      MaterialApp(home: HealthHome(controller: controller)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.show_chart_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Follow a reading over time.'), findsOneWidget);
    expect(find.text('Heart rate'), findsNWidgets(2));
    await tester.tap(find.byIcon(Icons.list_alt_outlined));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('record-search')), findsOneWidget);
  });

  testWidgets('flags only latest out-of-range labs with dated trend context', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    HealthRecord lab(
      String id,
      String name,
      String value,
      int day,
      String referenceRange,
    ) =>
        HealthRecord(
          id: id,
          name: name,
          value: value,
          unit: name == 'Blood glucose' ? 'mg/dL' : '%',
          recordedAt: DateTime(2026, 9, day, 12),
          category: RecordCategory.lab,
          source: 'Test lab',
          referenceRange: referenceRange,
        );

    final controller = HealthDataController(
      store: _MemoryRecordStore([
        lab('glucose-old', 'Blood glucose', '150', 1, '70–99 mg/dL'),
        lab('glucose-latest', 'Blood glucose', '120', 10, '70–99 mg/dL'),
        lab('a1c-old', 'Hemoglobin A1c', '6.5', 2, '4–5.6 %'),
        lab('a1c-latest', 'Hemoglobin A1c', '5.4', 11, '4–5.6 %'),
      ]),
      fhirImporter: FhirPortalImporter(
        client: MockClient((_) async {
          throw StateError(
            'No network request was expected in this widget test.',
          );
        }),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(home: HealthHome(controller: controller)),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Flagged lab results'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('1 currently out of range'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('flagged-lab-glucose-latest')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('flagged-lab-a1c-latest')), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('flagged-lab-glucose-latest')),
        matching: find.textContaining('120 mg/dL'),
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Reference range: 70–99 mg/dL'), findsOneWidget);
    final flaggedResult = find.byKey(
      const ValueKey('flagged-lab-glucose-latest'),
    );
    expect(
      find.descendant(
        of: flaggedResult,
        matching: find.textContaining('Sep 10, 2026'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: flaggedResult,
        matching: find.textContaining('Previous Sep 1, 2026'),
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Moved closer to range'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows recent numeric trends and opens the selected series', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    HealthRecord reading(
      String id,
      String name,
      String value,
      String unit,
      RecordCategory category,
      int day,
    ) =>
        HealthRecord(
          id: id,
          name: name,
          value: value,
          unit: unit,
          recordedAt: DateTime(2026, 9, day, 12),
          category: category,
          source: 'Test source',
        );

    final controller = HealthDataController(
      store: _MemoryRecordStore([
        reading(
          'glucose-previous',
          'Blood glucose',
          '100',
          'mg/dL',
          RecordCategory.vital,
          1,
        ),
        reading(
          'glucose-latest',
          'Blood glucose',
          '105',
          'mg/dL',
          RecordCategory.vital,
          10,
        ),
        reading(
          'creatinine-previous',
          'Serum creatinine',
          '1.0',
          'mg/dL',
          RecordCategory.lab,
          2,
        ),
        reading(
          'creatinine-latest',
          'Serum creatinine',
          '1.2',
          'mg/dL',
          RecordCategory.lab,
          12,
        ),
        reading(
          'steps-previous',
          'Steps',
          '7000',
          'count',
          RecordCategory.activity,
          3,
        ),
        reading(
          'steps-latest',
          'Steps',
          '8000',
          'count',
          RecordCategory.activity,
          13,
        ),
        reading(
          'heart-previous',
          'Heart rate',
          '60',
          'bpm',
          RecordCategory.vital,
          4,
        ),
        reading(
          'heart-latest',
          'Heart rate',
          '72',
          'bpm',
          RecordCategory.vital,
          14,
        ),
      ]),
      fhirImporter: FhirPortalImporter(
        client: MockClient((_) async {
          throw StateError(
            'No network request was expected in this widget test.',
          );
        }),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(home: HealthHome(controller: controller)),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('overview-trends-view-all')),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('overview-trend-heart-latest')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('overview-trend-steps-latest')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('overview-trend-creatinine-latest')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('overview-trend-glucose-latest')),
      findsNothing,
    );
    expect(find.textContaining('Change: +12 bpm'), findsOneWidget);
    expect(
      find.textContaining('Previous 60 bpm on Sep 4, 2026'),
      findsOneWidget,
    );
    expect(find.text('Sep 14, 2026'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const ValueKey('overview-trend-heart-latest')),
    );
    await tester.tap(find.byKey(const ValueKey('overview-trend-heart-latest')));
    await tester.pumpAndSettle();

    expect(find.text('Follow a reading over time.'), findsOneWidget);
    expect(find.text('Heart rate (bpm)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows an empty Trends prompt and opens the trends screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = HealthDataController(
      store: _MemoryRecordStore(),
      fhirImporter: FhirPortalImporter(
        client: MockClient((_) async {
          throw StateError(
            'No network request was expected in this widget test.',
          );
        }),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(home: HealthHome(controller: controller)),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('overview-trends-view-all')),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('No numeric readings yet'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('overview-trends-view-all')));
    await tester.pumpAndSettle();

    expect(find.text('No numeric readings to chart'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('opens guidelines from Overview and Sources without a new tab', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = HealthDataController(
      store: _MemoryRecordStore(),
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
      MaterialApp(home: HealthHome(controller: controller)),
    );
    await tester.pumpAndSettle();

    final navigation = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(navigation.destinations, hasLength(5));

    await tester.tap(
      find.byKey(const ValueKey('overview-guidelines-shortcut')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Evidence-based sources'), findsOneWidget);
    expect(find.byKey(const ValueKey('guideline-search')), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.hub_outlined));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('sources-guidelines-entry')),
    );
    await tester.tap(find.byKey(const ValueKey('sources-guidelines-entry')));
    await tester.pumpAndSettle();
    expect(find.text('Evidence-based sources'), findsOneWidget);
    expect(find.byKey(const ValueKey('guideline-search')), findsOneWidget);
  });

  testWidgets('searches records and combines search with category filters', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final records = [
      HealthRecord(
        id: 'health:glucose',
        name: 'Glucose',
        value: '104',
        unit: 'mg/dL',
        recordedAt: DateTime.utc(2025, 5, 10),
        category: RecordCategory.vital,
        source: 'Health Connect',
      ),
      HealthRecord(
        id: 'fhir:hba1c',
        name: 'Hemoglobin A1c',
        value: '6.1',
        unit: '%',
        recordedAt: DateTime.utc(2025, 4, 12),
        category: RecordCategory.lab,
        source: 'Provider portal',
      ),
    ];
    final controller = HealthDataController(
      store: _MemoryRecordStore(records),
      fhirImporter: FhirPortalImporter(
        client: MockClient((_) async {
          throw StateError(
            'No network request was expected in this widget test.',
          );
        }),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(home: HealthHome(controller: controller)),
    );
    await tester.scrollUntilVisible(
      find.text('Recent records'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Glucose'), findsOneWidget);
    expect(find.text('Hemoglobin A1c'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.list_alt_outlined));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('record-search')),
      'HEALTH CONNECT',
    );
    await tester.pumpAndSettle();

    expect(find.text('Glucose'), findsOneWidget);
    expect(find.text('Hemoglobin A1c'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('record-search-clear')));
    await tester.pumpAndSettle();
    expect(find.text('Glucose'), findsOneWidget);
    expect(find.text('Hemoglobin A1c'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('record-search')),
      'HEALTH CONNECT',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Labs'));
    await tester.pumpAndSettle();
    expect(find.text('No matching records'), findsOneWidget);

    await tester.tap(find.text('Clear search, filters, and date range'));
    await tester.pumpAndSettle();
    expect(find.text('Glucose'), findsOneWidget);
    expect(find.text('Hemoglobin A1c'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('record-search')),
      '6.1 %',
    );
    await tester.pumpAndSettle();
    expect(find.text('Hemoglobin A1c'), findsOneWidget);
    expect(find.text('Glucose'), findsNothing);
  });

  testWidgets('keeps large record history lazy on the records page', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final records = List.generate(
      10000,
      (index) => HealthRecord(
        id: 'health:test:$index',
        name: 'Record $index',
        value: '$index',
        unit: '',
        recordedAt: DateTime.utc(2020).add(Duration(minutes: index)),
        category: RecordCategory.vital,
        source: 'Apple Health',
      ),
    );
    final controller = HealthDataController(
      store: _MemoryRecordStore(records),
      fhirImporter: FhirPortalImporter(
        client: MockClient((_) async {
          throw StateError(
            'No network request was expected in this widget test.',
          );
        }),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(home: HealthHome(controller: controller)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.list_alt_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Record 9999'), findsOneWidget);
    expect(find.text('Record 0'), findsNothing);
  });

  testWidgets('filters by date range and steps between adjacent ranges', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = HealthDataController(
      store: _MemoryRecordStore([
        _recordForDate('Apr 10', DateTime(2025, 4, 10)),
        _recordForDate('Apr 12', DateTime(2025, 4, 12)),
        _recordForDate('Apr 15', DateTime(2025, 4, 15)),
      ]),
      fhirImporter: FhirPortalImporter(
        client: MockClient((_) async {
          throw StateError(
            'No network request was expected in this widget test.',
          );
        }),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(home: HealthHome(controller: controller)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.list_alt_outlined));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('record-date-picker')));
    await tester.pumpAndSettle();
    expect(find.text('Choose a date range'), findsOneWidget);
    await tester.tap(find.text('12'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('15'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    final dateLabel = find.descendant(
      of: find.byKey(const ValueKey('record-date-picker')),
      matching: find.byType(Text),
    );
    expect(tester.widget<Text>(dateLabel).data, contains('Apr 12'));
    expect(tester.widget<Text>(dateLabel).data, contains('Apr 15'));
    expect(find.text('Apr 10'), findsNothing);
    expect(find.text('Apr 12'), findsOneWidget);
    expect(find.text('Apr 15'), findsOneWidget);

    await tester.tap(find.byTooltip('Older records'));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(dateLabel).data, contains('Apr 10'));
    expect(tester.widget<Text>(dateLabel).data, contains('Apr 13'));
    expect(find.text('Apr 10'), findsOneWidget);
    expect(find.text('Apr 12'), findsOneWidget);
    expect(find.text('Apr 15'), findsNothing);

    await tester.tap(find.byTooltip('Newer records'));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(dateLabel).data, contains('Apr 12'));
    expect(tester.widget<Text>(dateLabel).data, contains('Apr 15'));

    await tester.tap(find.byKey(const ValueKey('record-date-clear')));
    await tester.pumpAndSettle();
    expect(find.text('Apr 10'), findsOneWidget);
    expect(find.text('Apr 12'), findsOneWidget);
    expect(find.text('Apr 15'), findsOneWidget);
  });

  test('reports only newly added records across repeated imports', () async {
    final record = HealthRecord(
      id: 'health:glucose',
      name: 'Glucose',
      value: '104',
      unit: 'mg/dL',
      recordedAt: DateTime.utc(2025, 5, 10),
      category: RecordCategory.vital,
      source: 'Health Connect',
    );
    final controller = HealthDataController(
      store: _MemoryRecordStore(),
      healthImporter: _FakeHealthPlatformImporter([record]),
      syncValueStore: _MemorySyncValueStore(),
      fhirImporter: FhirPortalImporter(
        client: MockClient((_) async {
          throw StateError(
            'No network request was expected in this widget test.',
          );
        }),
      ),
    );
    addTearDown(controller.dispose);
    await controller.load();

    final firstImport = await controller.importHealth(
      since: DateTime.utc(2025),
    );
    final repeatedImport = await controller.importHealth(
      since: DateTime.utc(2025),
    );

    expect(firstImport, [record]);
    expect(repeatedImport, isEmpty);
    expect(controller.records, [record]);
  });

  testWidgets('limits exports to selected record categories', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = HealthDataController(
      store: _MemoryRecordStore([
        HealthRecord(
          id: 'health:glucose',
          name: 'Glucose',
          value: '104',
          unit: 'mg/dL',
          recordedAt: DateTime.utc(2025, 5, 10),
          category: RecordCategory.vital,
          source: 'Health Connect',
        ),
        HealthRecord(
          id: 'fhir:hba1c',
          name: 'Hemoglobin A1c',
          value: '6.1',
          unit: '%',
          recordedAt: DateTime.utc(2025, 4, 12),
          category: RecordCategory.lab,
          source: 'Provider portal',
        ),
      ]),
      fhirImporter: FhirPortalImporter(
        client: MockClient((_) async {
          throw StateError(
            'No network request was expected in this widget test.',
          );
        }),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(home: HealthHome(controller: controller)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.ios_share_outlined));
    await tester.pumpAndSettle();

    expect(find.text('2 of 2 records selected'), findsOneWidget);
    await tester.tap(find.text('Vitals (1)'));
    await tester.pumpAndSettle();
    expect(find.text('1 of 2 records selected'), findsOneWidget);

    await tester.tap(find.text('Labs (1)'));
    await tester.pumpAndSettle();
    expect(find.text('0 of 2 records selected'), findsOneWidget);
    expect(find.text('Choose a category to continue'), findsOneWidget);
    await tester.ensureVisible(find.text('Create PDF'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Create PDF'),
          )
          .onPressed,
      isNull,
    );

    await tester.drag(find.byType(ListView).last, const Offset(0, 700));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Labs (1)'));
    await tester.pumpAndSettle();
    expect(find.text('1 of 2 records selected'), findsOneWidget);
    await tester.ensureVisible(find.text('Create PDF'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Create PDF'),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('requests permission before enabling result notifications', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final notifications = _FakeResultNotificationManager();
    final controller = HealthDataController(
      store: _MemoryRecordStore(),
      fhirImporter: FhirPortalImporter(
        client: MockClient((_) async {
          throw StateError(
            'No network request was expected in this widget test.',
          );
        }),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: HealthHome(
          controller: controller,
          notificationManager: notifications,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(notifications.permissionRequests, 0);
    await tester.tap(find.byIcon(Icons.hub_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Result notifications'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).last, const Offset(0, -400));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Enable notifications'));
    await tester.tap(find.text('Enable notifications'));
    await tester.pumpAndSettle();

    expect(notifications.permissionRequests, 1);
    expect(notifications.preferences.enabled, isTrue);
    expect(
      find.text(
        'Alerts run after manual imports or automatic foreground sync. The app does not check sources while closed.',
      ),
      findsOneWidget,
    );

    await tester.ensureVisible(find.text('10%'));
    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('20%').last);
    await tester.pumpAndSettle();
    expect(notifications.preferences.trendThresholdPercent, 20);

    await tester.ensureVisible(find.text('Trend changes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Trend changes'));
    await tester.pumpAndSettle();
    expect(notifications.preferences.trends, isFalse);
  });

  testWidgets('keeps notifications off when device permission is denied', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final notifications = _FakeResultNotificationManager()
      ..permissionGranted = false;
    final controller = HealthDataController(
      store: _MemoryRecordStore(),
      fhirImporter: FhirPortalImporter(
        client: MockClient((_) async {
          throw StateError(
            'No network request was expected in this widget test.',
          );
        }),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: HealthHome(
          controller: controller,
          notificationManager: notifications,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.hub_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Result notifications'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).last, const Offset(0, -400));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Enable notifications'));
    await tester.tap(find.text('Enable notifications'));
    await tester.pumpAndSettle();

    expect(notifications.preferences.enabled, isFalse);
    expect(
      find.text('Allow notifications in your device settings, then try again.'),
      findsOneWidget,
    );
  });

  testWidgets('shows the empty record state and FHIR connection form', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = HealthDataController(
      store: _MemoryRecordStore(),
      fhirImporter: FhirPortalImporter(
        client: MockClient((_) async {
          throw StateError(
            'No network request was expected in this widget test.',
          );
        }),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(home: HealthHome(controller: controller)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Your health history,\nall together.'), findsOneWidget);
    await tester.ensureVisible(find.text('Your timeline starts here'));
    await tester.pumpAndSettle();
    expect(find.text('Connect a health source'), findsOneWidget);
    expect(find.text('Your timeline starts here'), findsOneWidget);
    expect(find.text('No records yet'), findsNothing);
    await tester.tap(find.byIcon(Icons.list_alt_outlined));
    await tester.pumpAndSettle();
    expect(find.text('No records in this view'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.hub_outlined));
    await tester.pumpAndSettle();
    expect(find.text('FHIR patient portal'), findsOneWidget);
    await tester.drag(find.byType(ListView).last, const Offset(0, -700));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Registered app client ID'));
    await tester.pumpAndSettle();
    expect(find.text('Registered app client ID'), findsOneWidget);
    expect(find.text('Automatically sync this portal'), findsOneWidget);
    expect(find.text('Connected'), findsNothing);
  });

  testWidgets('shows connected status for a source with imported records', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = HealthDataController(
      store: _MemoryRecordStore([
        HealthRecord(
          id: 'fhir:hba1c',
          name: 'Hemoglobin A1c',
          value: '6.1',
          unit: '%',
          recordedAt: DateTime.utc(2025, 4, 12),
          category: RecordCategory.lab,
          source: 'Provider portal',
        ),
      ]),
      fhirImporter: FhirPortalImporter(
        client: MockClient((_) async {
          throw StateError(
            'No network request was expected in this widget test.',
          );
        }),
      ),
      syncValueStore: _MemorySyncValueStore(),
    );
    await tester.pumpWidget(
      MaterialApp(home: HealthHome(controller: controller)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.hub_outlined));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('FHIR patient portal').last);
    await tester.pumpAndSettle();

    expect(find.text('FHIR patient portal'), findsNWidgets(2));
    expect(find.text('Connected'), findsOneWidget);
    expect(find.text('1 imported'), findsOneWidget);
  });
}

HealthRecord _recordForDate(String name, DateTime recordedAt) => HealthRecord(
      id: 'test:$name',
      name: name,
      value: '1',
      unit: '',
      recordedAt: recordedAt,
      category: RecordCategory.vital,
      source: 'Test source',
    );

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

class _FakeResultNotificationManager implements ResultNotificationManager {
  ResultNotificationPreferences preferences =
      const ResultNotificationPreferences();
  bool permissionGranted = true;
  int permissionRequests = 0;

  @override
  Future<ResultNotificationPreferences> loadPreferences() async => preferences;

  @override
  Future<void> savePreferences(
    ResultNotificationPreferences preferences,
  ) async {
    this.preferences = preferences;
  }

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return permissionGranted;
  }

  @override
  Future<void> notifyForImport({
    required List<HealthRecord> newlyImported,
    required List<HealthRecord> allRecords,
  }) async {}
}

class _FakeHealthPlatformImporter extends HealthPlatformImporter {
  _FakeHealthPlatformImporter(this.records);

  final List<HealthRecord> records;

  @override
  Future<List<HealthRecord>> importRecords({
    required DateTime since,
    ImportProgressCallback? onProgress,
  }) async =>
      records;
}

class _MemorySyncValueStore implements SyncValueStore {
  final values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}
