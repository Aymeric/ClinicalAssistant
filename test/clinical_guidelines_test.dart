import 'dart:io';

import 'package:clinical_assistant/guidelines/clinical_guideline.dart';
import 'package:clinical_assistant/guidelines/clinical_guideline_catalog.dart';
import 'package:clinical_assistant/guidelines/guideline_pdf_export_service.dart';
import 'package:clinical_assistant/guidelines/guideline_source.dart';
import 'package:clinical_assistant/guidelines/guideline_storage_service.dart';
import 'package:clinical_assistant/guidelines/guideline_viewer_page.dart';
import 'package:clinical_assistant/guidelines/guidelines_library_page.dart';
import 'package:clinical_assistant/models/health_record.dart';
import 'package:clinical_assistant/trends/health_trends_page.dart';
import 'package:clinical_assistant/ui/records/record_details_sheet.dart';
import 'package:clinical_assistant/ui/shared/record_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ClinicalGuidelineCatalog', () {
    test('filters guidelines by topic and jurisdiction', () {
      final conditionGuidelines = ClinicalGuidelineCatalog.filter(
        topic: GuidelineTopic.conditionCare,
      );
      expect(
        conditionGuidelines.map((g) => g.id),
        containsAll([
          'nice-ng136-hypertension',
          'nice-ng28-diabetes',
          'who-hypertension-pharmacological',
        ]),
      );

      final usGuidelines = ClinicalGuidelineCatalog.filter(
        jurisdiction: GuidelineJurisdiction.unitedStates,
      );
      expect(
        usGuidelines.map((g) => g.id),
        containsAll([
          'uspstf-hypertension-screening',
          'uspstf-diabetes-screening',
          'uspstf-statin-cvd',
        ]),
      );
      expect(
        usGuidelines.every(
          (g) => g.jurisdiction == GuidelineJurisdiction.unitedStates,
        ),
        isTrue,
      );
    });

    test('searches guidelines by query across title, identifier, and recommendations', () {
      final bpResults = ClinicalGuidelineCatalog.filter(
        query: 'blood pressure',
      );
      expect(bpResults.isNotEmpty, isTrue);
      expect(
        bpResults.any((g) => g.id == 'nice-ng136-hypertension'),
        isTrue,
      );
      expect(
        bpResults.any((g) => g.id == 'uspstf-hypertension-screening'),
        isTrue,
      );

      final statinResults = ClinicalGuidelineCatalog.filter(
        query: 'statin',
      );
      expect(
        statinResults.map((g) => g.id),
        containsAll(['uspstf-statin-cvd', 'nice-cg181-lipids']),
      );
    });

    test('filters by downloaded IDs', () {
      final downloadedOnly = ClinicalGuidelineCatalog.filter(
        downloadedIds: {'nice-ng136-hypertension'},
        downloadedOnly: true,
      );
      expect(downloadedOnly.length, 1);
      expect(downloadedOnly.first.id, 'nice-ng136-hypertension');
    });

    test('findRelatedGuidelines maps measurement names to clinical guidelines', () {
      final bp = ClinicalGuidelineCatalog.findRelatedGuidelines(
        measurementName: 'Blood Pressure',
      );
      expect(bp.map((g) => g.id), containsAll([
        'nice-ng136-hypertension',
        'uspstf-hypertension-screening',
        'who-hypertension-pharmacological',
      ]));

      final a1c = ClinicalGuidelineCatalog.findRelatedGuidelines(
        measurementName: 'Hemoglobin A1c',
      );
      expect(a1c.map((g) => g.id), containsAll([
        'nice-ng28-diabetes',
        'uspstf-diabetes-screening',
      ]));

      final ldl = ClinicalGuidelineCatalog.findRelatedGuidelines(
        measurementName: 'LDL Cholesterol',
      );
      expect(ldl.map((g) => g.id), containsAll([
        'nice-cg181-lipids',
        'uspstf-statin-cvd',
      ]));

      final steps = ClinicalGuidelineCatalog.findRelatedGuidelines(
        measurementName: 'Steps',
        category: 'Activity',
      );
      expect(steps.map((g) => g.id), contains('who-physical-activity'));

      final unrelated = ClinicalGuidelineCatalog.findRelatedGuidelines(
        measurementName: 'Caffeine Intake',
      );
      expect(unrelated, isEmpty);
    });

    test('findRelatedGuidelines matches by LOINC codes and abbreviations', () {
      // LOINC matching for HbA1c even with arbitrary lab display name
      final a1cByLoinc = ClinicalGuidelineCatalog.findRelatedGuidelines(
        measurementName: 'Special Lab Test 401',
        loincCode: '4548-4',
      );
      expect(a1cByLoinc.map((g) => g.id), contains('nice-ng28-diabetes'));

      // Prefixed LOINC string from FHIR
      final fhirBp = ClinicalGuidelineCatalog.findRelatedGuidelines(
        measurementName: 'Unknown Observation',
        loincCode: 'http://loinc.org|8480-6',
      );
      expect(fhirBp.map((g) => g.id), contains('nice-ng136-hypertension'));

      // CKD / Renal function via LOINC and abbreviations
      final ckdByLoinc = ClinicalGuidelineCatalog.findRelatedGuidelines(
        measurementName: 'Creatinine in Serum',
        loincCode: '2160-0',
      );
      expect(ckdByLoinc.map((g) => g.id), contains('nice-ng203-ckd'));

      final egfrByAbbr = ClinicalGuidelineCatalog.findRelatedGuidelines(
        measurementName: 'eGFR non-African',
      );
      expect(egfrByAbbr.map((g) => g.id), contains('nice-ng203-ckd'));

      final uacr = ClinicalGuidelineCatalog.findRelatedGuidelines(
        measurementName: 'uACR spot test',
      );
      expect(uacr.map((g) => g.id), contains('nice-ng203-ckd'));

      // Weight management and BMI
      final bmi = ClinicalGuidelineCatalog.findRelatedGuidelines(
        measurementName: 'BMI',
        loincCode: '39156-5',
      );
      expect(bmi.map((g) => g.id), contains('uspstf-weight-management'));

      // Asthma and SpO2
      final asthma = ClinicalGuidelineCatalog.findRelatedGuidelines(
        measurementName: 'SpO2 pulse oximetry',
        loincCode: '2708-6',
      );
      expect(asthma.map((g) => g.id), contains('nice-ng80-asthma'));

      final peakFlow = ClinicalGuidelineCatalog.findRelatedGuidelines(
        measurementName: 'Peak Flow Meter reading',
      );
      expect(peakFlow.map((g) => g.id), contains('nice-ng80-asthma'));

      // hasRelatedGuidelines helper
      expect(
        ClinicalGuidelineCatalog.hasRelatedGuidelines(
          measurementName: 'eGFR',
        ),
        isTrue,
      );
      expect(
        ClinicalGuidelineCatalog.hasRelatedGuidelines(
          measurementName: 'Random metric',
        ),
        isFalse,
      );
    });
  });

  group('ClinicalGuideline JSON Serialization', () {
    test('serializes and deserializes ClinicalGuideline and DownloadedGuideline', () {
      final guideline = ClinicalGuidelineCatalog.guidelines.first;
      final json = guideline.toJson();
      final restored = ClinicalGuideline.fromJson(json);

      expect(restored.id, guideline.id);
      expect(restored.title, guideline.title);
      expect(restored.identifier, guideline.identifier);
      expect(restored.recommendations.length, guideline.recommendations.length);
      expect(restored.sections.length, guideline.sections.length);

      final downloaded = DownloadedGuideline(
        guideline: guideline,
        downloadedAt: DateTime.utc(2026, 10, 18, 12, 0),
        localFilePath: '/tmp/test.json',
        fileSizeBytes: 284000,
      );
      expect(downloaded.formattedSize, '277.3 KB');

      final downloadedJson = downloaded.toJson();
      final restoredDownloaded = DownloadedGuideline.fromJson(downloadedJson);
      expect(restoredDownloaded.guideline.id, guideline.id);
      expect(restoredDownloaded.fileSizeBytes, 284000);
      expect(restoredDownloaded.localFilePath, '/tmp/test.json');
    });
  });

  group('GuidelineStorageService', () {
    late Directory tempDir;
    late GuidelineStorageService service;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('guideline-service-test-');
      service = GuidelineStorageService(storageDirectory: tempDir);
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('downloads, verifies, retrieves, and deletes guidelines', () async {
      final guideline = ClinicalGuidelineCatalog.guidelines.first;

      expect(await service.isDownloaded(guideline.id), isFalse);
      expect(await service.getDownloadedGuidelines(), isEmpty);

      final downloaded = await service.downloadGuideline(guideline);
      expect(downloaded.guideline.id, guideline.id);
      expect(downloaded.fileSizeBytes, greaterThan(0));
      expect(await service.isDownloaded(guideline.id), isTrue);

      final loaded = await service.getDownloadedGuideline(guideline.id);
      expect(loaded, isNotNull);
      expect(loaded!.guideline.title, guideline.title);
      expect(loaded.guideline.recommendations.length, guideline.recommendations.length);

      final allDownloaded = await service.getDownloadedGuidelines();
      expect(allDownloaded.length, 1);
      expect(allDownloaded.first.guideline.id, guideline.id);

      final ids = await service.getDownloadedIds();
      expect(ids.contains(guideline.id), isTrue);

      final totalBytes = await service.getTotalDownloadedSizeBytes();
      expect(totalBytes, greaterThan(0));

      final deleted = await service.deleteDownloadedGuideline(guideline.id);
      expect(deleted, isTrue);
      expect(await service.isDownloaded(guideline.id), isFalse);
      expect(await service.getDownloadedGuidelines(), isEmpty);
    });

    test('deleteAllDownloadedGuidelines removes all saved files', () async {
      final g1 = ClinicalGuidelineCatalog.guidelines[0];
      final g2 = ClinicalGuidelineCatalog.guidelines[1];

      await service.downloadGuideline(g1);
      await service.downloadGuideline(g2);
      expect(await service.getDownloadedGuidelines(), hasLength(2));

      await service.deleteAllDownloadedGuidelines();
      expect(await service.getDownloadedGuidelines(), isEmpty);
    });

    test('manages favorites and persists them correctly', () async {
      expect(await service.getFavoriteIds(), isEmpty);
      expect(await service.isFavorite('nice-ng136-hypertension'), isFalse);

      await service.toggleFavorite('nice-ng136-hypertension');
      expect(await service.isFavorite('nice-ng136-hypertension'), isTrue);
      expect(await service.getFavoriteIds(), {'nice-ng136-hypertension'});

      await service.setFavorite('uspstf-statin-cvd', true);
      expect(
        await service.getFavoriteIds(),
        {'nice-ng136-hypertension', 'uspstf-statin-cvd'},
      );

      await service.toggleFavorite('nice-ng136-hypertension');
      expect(await service.isFavorite('nice-ng136-hypertension'), isFalse);
      expect(await service.getFavoriteIds(), {'uspstf-statin-cvd'});
    });

    test('saves, retrieves, updates, and deletes patient notes', () async {
      const id = 'nice-ng136-hypertension';
      expect(await service.getGuidelineNotes(id), isNull);

      await service.saveGuidelineNotes(
        id,
        'Ask Dr. Smith about target systolic pressure',
      );
      expect(
        await service.getGuidelineNotes(id),
        'Ask Dr. Smith about target systolic pressure',
      );

      await service.saveGuidelineNotes(
        id,
        'Ask Dr. Smith about target systolic pressure and diet',
      );
      expect(
        await service.getGuidelineNotes(id),
        'Ask Dr. Smith about target systolic pressure and diet',
      );

      await service.deleteGuidelineNotes(id);
      expect(await service.getGuidelineNotes(id), isNull);
    });
  });

  group('GuidelinePdfExportService', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('guideline-pdf-test-');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('generates doctor visit summary PDF with recommendations and notes', () async {
      const exporter = GuidelinePdfExportService();
      final guideline = ClinicalGuidelineCatalog.guidelines.first;
      final file = await exporter.generateGuidelinePdf(
        guideline: guideline,
        patientNotes: 'Question for my appointment: should I take statins?',
        outputDirectory: tempDir,
      );

      expect(file.existsSync(), isTrue);
      expect(file.lengthSync(), greaterThan(1000));
      expect(file.path.endsWith('.pdf'), isTrue);
    });
  });

  group('Guideline UI & Viewer Integration', () {
    late Directory tempDir;
    late GuidelineStorageService service;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('guideline-ui-test-');
      service = GuidelineStorageService(storageDirectory: tempDir);
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    testWidgets('downloads and removes guideline from guidelines library page', (tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: GuidelinesLibraryPage(storageService: service),
        ),
      );
      await tester.pumpAndSettle();

      final scrollable = find.descendant(
        of: find.byType(ListView),
        matching: find.byType(Scrollable),
      ).first;

      // Tap "Guidelines" mode chip
      await tester.tap(find.byKey(const ValueKey('guideline-view-mode-guidelines')));
      await tester.pumpAndSettle();

      final firstGuideline = ClinicalGuidelineCatalog.guidelines.first;
      final downloadKey = ValueKey('guideline-download-${firstGuideline.id}');

      await tester.scrollUntilVisible(
        find.byKey(downloadKey),
        100,
        scrollable: scrollable,
      );
      await tester.ensureVisible(find.byKey(downloadKey));
      await tester.pumpAndSettle();
      expect(find.byKey(downloadKey), findsOneWidget);

      // Download guideline
      await tester.tap(find.byKey(downloadKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();

      expect(find.textContaining('Downloaded "${firstGuideline.shortTitle}"'), findsOneWidget);
      final deleteKey = ValueKey('guideline-delete-${firstGuideline.id}');
      await tester.ensureVisible(find.byKey(deleteKey));
      await tester.pumpAndSettle();
      expect(find.byKey(deleteKey), findsOneWidget);

      // Switch to Downloaded view mode
      await tester.drag(scrollable, const Offset(0, 1000));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('guideline-view-mode-downloaded')));
      await tester.pumpAndSettle();
      expect(find.text(firstGuideline.title), findsOneWidget);

      // Remove download
      await tester.ensureVisible(find.byKey(deleteKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(deleteKey));
      await tester.pumpAndSettle();
      expect(find.textContaining('Removed "${firstGuideline.shortTitle}"'), findsOneWidget);
      expect(find.text('No downloaded guidelines'), findsOneWidget);
    });

    testWidgets('GuidelineViewerPage displays sections, recommendations, and search', (tester) async {
      tester.view.physicalSize = const Size(400, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final guideline = ClinicalGuidelineCatalog.guidelines.first;

      await tester.pumpWidget(
        MaterialApp(
          home: GuidelineViewerPage(
            guideline: guideline,
            storageService: service,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final scrollable = find.descendant(
        of: find.byType(ListView),
        matching: find.byType(Scrollable),
      ).first;

      expect(find.text(guideline.identifier), findsAtLeastNWidgets(1));
      expect(find.text(guideline.title), findsOneWidget);
      expect(find.text(guideline.publisher), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text(guideline.recommendations.first.title),
        100,
        scrollable: scrollable,
      );
      expect(find.textContaining('Key Recommendations'), findsOneWidget);
      expect(find.text(guideline.recommendations.first.title), findsOneWidget);

      await tester.scrollUntilVisible(
        find.textContaining('Full Clinical Guidance'),
        100,
        scrollable: scrollable,
      );
      expect(find.textContaining('Full Clinical Guidance'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text(guideline.sections.first.title),
        100,
        scrollable: scrollable,
      );
      expect(find.text(guideline.sections.first.title), findsOneWidget);

      await tester.scrollUntilVisible(
        find.textContaining('Citation & Provenance'),
        100,
        scrollable: scrollable,
      );
      expect(find.textContaining('Citation & Provenance'), findsOneWidget);

      // Search within guideline
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('guideline-viewer-search')),
        -100,
        scrollable: scrollable,
      );
      await tester.enterText(
        find.byKey(const ValueKey('guideline-viewer-search')),
        'lifestyle',
      );
      await tester.pumpAndSettle();
      expect(find.text('Lifestyle advice across all stages'), findsOneWidget);

      // Clear search
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      // Download from viewer
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('guideline-viewer-download-toggle')),
        -100,
        scrollable: scrollable,
      );
      await tester.ensureVisible(find.byKey(const ValueKey('guideline-viewer-download-toggle')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('guideline-viewer-download-toggle')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
      expect(find.textContaining('Available offline on this device'), findsOneWidget);
      expect(find.text('Remove'), findsOneWidget);
    });

    testWidgets('GuidelineViewerPage records patient notes and opens evidence guide modal', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final guideline = ClinicalGuidelineCatalog.guidelines.first;

      await tester.pumpWidget(
        MaterialApp(
          home: GuidelineViewerPage(
            guideline: guideline,
            storageService: service,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final scrollable = find.descendant(
        of: find.byType(ListView),
        matching: find.byType(Scrollable),
      ).first;

      // Open and verify Evidence Guide
      await tester.scrollUntilVisible(
        find.text('Evidence Guide'),
        100,
        scrollable: scrollable,
      );
      expect(find.text('Evidence Guide'), findsOneWidget);
      await tester.tap(find.text('Evidence Guide'));
      await tester.pumpAndSettle();
      expect(find.text('Understanding Evidence Grades'), findsOneWidget);
      expect(find.textContaining('USPSTF Letter Grades'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('close-evidence-guide-button')));
      await tester.pumpAndSettle();

      // Favorite toggle in AppBar
      await tester.tap(find.byIcon(Icons.star_outline));
      await tester.pumpAndSettle();
      expect(await service.isFavorite(guideline.id), isTrue);
      expect(find.byIcon(Icons.star), findsOneWidget);

      // Add doctor visit notes
      await tester.scrollUntilVisible(
        find.text('Doctor Visit Discussion Notes'),
        -100,
        scrollable: scrollable,
      );
      expect(find.text('Doctor Visit Discussion Notes'), findsOneWidget);
      await tester.ensureVisible(find.byIcon(Icons.add_circle_outline));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.add_circle_outline));
      await tester.pumpAndSettle();
      expect(find.text('Doctor Visit Questions & Notes'), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('guideline-notes-input')),
        'Ask about target blood pressure for elderly patient',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save Note'));
      await tester.pumpAndSettle();

      expect(
        find.text('Ask about target blood pressure for elderly patient'),
        findsOneWidget,
      );
      expect(
        await service.getGuidelineNotes(guideline.id),
        'Ask about target blood pressure for elderly patient',
      );
    });

    testWidgets('GuidelinesLibraryPage filters and toggles favorite guidelines', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: GuidelinesLibraryPage(storageService: service),
        ),
      );
      await tester.pumpAndSettle();

      final scrollable = find.descendant(
        of: find.byType(ListView),
        matching: find.byType(Scrollable),
      ).first;

      final favModeKey = const ValueKey('guideline-view-mode-favorites');
      await tester.scrollUntilVisible(
        find.byKey(favModeKey),
        100,
        scrollable: scrollable,
      );
      expect(find.byKey(favModeKey), findsOneWidget);

      // Initially no favorites
      await tester.tap(find.byKey(favModeKey));
      await tester.pumpAndSettle();
      expect(find.text('No favorite guidelines'), findsOneWidget);

      // Return to All and favorite the first guideline
      await tester.tap(find.byKey(const ValueKey('guideline-view-mode-all')));
      await tester.pumpAndSettle();

      final firstGuideline = ClinicalGuidelineCatalog.guidelines.first;
      final favButtonKey = ValueKey('guideline-favorite-${firstGuideline.id}');
      await tester.scrollUntilVisible(
        find.byKey(favButtonKey),
        100,
        scrollable: scrollable,
      );
      await tester.ensureVisible(find.byKey(favButtonKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(favButtonKey));
      await tester.pumpAndSettle();

      // Return to top
      await tester.scrollUntilVisible(
        find.byKey(favModeKey),
        -100,
        scrollable: scrollable,
      );
      await tester.ensureVisible(find.byKey(favModeKey));
      await tester.pumpAndSettle();
      expect(find.byKey(favModeKey), findsOneWidget);
      await tester.tap(find.byKey(favModeKey));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text(firstGuideline.title),
        100,
        scrollable: scrollable,
      );
      expect(find.text(firstGuideline.title), findsOneWidget);
    });

    testWidgets('RecordDetailsSheet displays related guidelines for blood pressure', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final record = HealthRecord(
        id: 'test-bp-1',
        name: 'Blood Pressure',
        value: '138/88',
        unit: 'mmHg',
        recordedAt: DateTime.utc(2025, 6, 1, 10, 0),
        category: RecordCategory.vital,
        source: 'Manual entry',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RecordDetailsSheet(
              record: record,
              isNumeric: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final scrollable = find.descendant(
        of: find.byType(SingleChildScrollView),
        matching: find.byType(Scrollable),
      ).first;

      await tester.scrollUntilVisible(
        find.text('Evidence-Based Guidelines'),
        100,
        scrollable: scrollable,
      );
      expect(find.text('Evidence-Based Guidelines'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('related-guideline-nice-ng136-hypertension')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('browse-related-guidelines-button')),
        findsOneWidget,
      );
    });

    testWidgets('HealthTrendsPage displays related guidelines for selected measurement series', (tester) async {
      tester.view.physicalSize = const Size(390, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final records = [
        HealthRecord(
          id: 'bp:sys:1',
          name: 'Blood Pressure Systolic',
          value: '135',
          unit: 'mmHg',
          recordedAt: DateTime.utc(2025, 6, 1, 8, 0),
          category: RecordCategory.vital,
          source: 'Manual entry',
        ),
        HealthRecord(
          id: 'bp:dia:1',
          name: 'Blood Pressure Diastolic',
          value: '85',
          unit: 'mmHg',
          recordedAt: DateTime.utc(2025, 6, 1, 8, 0),
          category: RecordCategory.vital,
          source: 'Manual entry',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HealthTrendsPage(
              records: records,
              initialSeriesId: 'combined_blood_pressure',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final scrollable = find.descendant(
        of: find.byType(CustomScrollView),
        matching: find.byType(Scrollable),
      ).first;

      await tester.scrollUntilVisible(
        find.text('Evidence-Based Guidelines'),
        100,
        scrollable: scrollable,
      );
      expect(find.text('Evidence-Based Guidelines'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('related-guideline-nice-ng136-hypertension')),
        findsOneWidget,
      );
    });

    testWidgets('RecordRow displays guideline badge for matching clinical records', (tester) async {
      final ckdRecord = HealthRecord(
        id: 'rec-ckd-1',
        name: 'eGFR',
        value: '58',
        unit: 'mL/min/1.73m2',
        recordedAt: DateTime.utc(2025, 6, 1, 9, 0),
        category: RecordCategory.lab,
        source: 'LabCorp',
        code: '33914-3',
      );

      final unlinkedRecord = HealthRecord(
        id: 'rec-unlinked-1',
        name: 'Random Unmapped Observation',
        value: 'Normal',
        unit: '',
        recordedAt: DateTime.utc(2025, 6, 1, 9, 0),
        category: RecordCategory.vital,
        source: 'Manual entry',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                RecordRow(record: ckdRecord, isLast: false),
                RecordRow(record: unlinkedRecord, isLast: true),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Guideline'), findsOneWidget);
      expect(find.byIcon(Icons.menu_book_outlined), findsOneWidget);
    });
  });
}
