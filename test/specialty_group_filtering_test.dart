import 'package:clinical_assistant/models/doctor_visit_preparation.dart';
import 'package:clinical_assistant/models/health_record.dart';
import 'package:clinical_assistant/trends/health_trend.dart';
import 'package:clinical_assistant/trends/health_trends_page.dart';
import 'package:clinical_assistant/ui/overview/overview_page.dart';
import 'package:clinical_assistant/ui/records/records_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DoctorVisitSpecialty Domain Matching Logic', () {
    final bpRecord = HealthRecord(
      id: 'rec-bp',
      name: 'Systolic Blood Pressure',
      value: '135',
      unit: 'mmHg',
      recordedAt: DateTime.utc(2026, 10, 10),
      category: RecordCategory.vital,
      source: 'Clinic Monitor',
    );

    final ldlRecord = HealthRecord(
      id: 'rec-ldl',
      name: 'LDL Cholesterol',
      value: '142',
      unit: 'mg/dL',
      recordedAt: DateTime.utc(2026, 10, 10),
      category: RecordCategory.lab,
      source: 'LabCorp',
      code: '2085-9',
    );

    final glucoseRecord = HealthRecord(
      id: 'rec-glucose',
      name: 'Fasting Blood Glucose',
      value: '115',
      unit: 'mg/dL',
      recordedAt: DateTime.utc(2026, 10, 10),
      category: RecordCategory.lab,
      source: 'Quest',
      code: '1558-6',
    );

    final hba1cRecord = HealthRecord(
      id: 'rec-a1c',
      name: 'Hemoglobin A1c',
      value: '6.8',
      unit: '%',
      recordedAt: DateTime.utc(2026, 10, 10),
      category: RecordCategory.lab,
      source: 'Quest',
      code: '4548-4',
    );

    final lisinoprilRecord = HealthRecord(
      id: 'rec-lisinopril',
      name: 'Lisinopril 10 MG Oral Tablet',
      value: 'Active',
      unit: '',
      recordedAt: DateTime.utc(2026, 10, 10),
      category: RecordCategory.medication,
      source: 'EHR',
    );

    final metforminRecord = HealthRecord(
      id: 'rec-metformin',
      name: 'Metformin hydrochloride 500 MG',
      value: 'Active',
      unit: '',
      recordedAt: DateTime.utc(2026, 10, 10),
      category: RecordCategory.medication,
      source: 'EHR',
    );

    final htCondition = HealthRecord(
      id: 'rec-htn',
      name: 'Essential Hypertension',
      value: 'Confirmed',
      unit: '',
      recordedAt: DateTime.utc(2026, 10, 10),
      category: RecordCategory.condition,
      source: 'EHR',
    );

    final t2dCondition = HealthRecord(
      id: 'rec-t2d',
      name: 'Type 2 Diabetes Mellitus',
      value: 'Active',
      unit: '',
      recordedAt: DateTime.utc(2026, 10, 10),
      category: RecordCategory.condition,
      source: 'EHR',
    );

    test('Cardiology correctly matches cardiac observations', () {
      final cardiology = DoctorVisitSpecialty.cardiology;
      expect(cardiology.matchesRecord(bpRecord), isTrue);
      expect(cardiology.matchesRecord(ldlRecord), isTrue);
      expect(cardiology.matchesRecord(lisinoprilRecord), isTrue);
      expect(cardiology.matchesRecord(htCondition), isTrue);

      expect(cardiology.matchesRecord(metforminRecord), isFalse);
      expect(cardiology.matchesRecord(t2dCondition), isFalse);
    });

    test('Endocrinology correctly matches endocrine observations', () {
      final endocrinology = DoctorVisitSpecialty.endocrinology;
      expect(endocrinology.matchesRecord(glucoseRecord), isTrue);
      expect(endocrinology.matchesRecord(hba1cRecord), isTrue);
      expect(endocrinology.matchesRecord(metforminRecord), isTrue);
      expect(endocrinology.matchesRecord(t2dCondition), isTrue);

      expect(endocrinology.matchesRecord(ldlRecord), isFalse);
      expect(endocrinology.matchesRecord(lisinoprilRecord), isFalse);
    });

    test('Annual Wellness matches general vitals, labs, and medications', () {
      final annual = DoctorVisitSpecialty.annualWellness;
      expect(annual.matchesRecord(bpRecord), isTrue);
      expect(annual.matchesRecord(ldlRecord), isTrue);
      expect(annual.matchesRecord(glucoseRecord), isTrue);
      expect(annual.matchesRecord(hba1cRecord), isTrue);
      expect(annual.matchesRecord(lisinoprilRecord), isTrue);
      expect(annual.matchesRecord(metforminRecord), isTrue);
    });

    test('matchesTrendSeries filters trend series accurately', () {
      final seriesList = buildHealthTrendSeries([
        bpRecord,
        ldlRecord,
        glucoseRecord,
      ]);
      final bpSeries = seriesList.firstWhere(
        (s) => s.name.contains('Blood Pressure'),
      );
      final ldlSeries = seriesList.firstWhere(
        (s) => s.name.contains('Cholesterol'),
      );
      final glucoseSeries = seriesList.firstWhere(
        (s) => s.name.contains('Glucose'),
      );

      expect(
        DoctorVisitSpecialty.cardiology.matchesTrendSeries(bpSeries),
        isTrue,
      );
      expect(
        DoctorVisitSpecialty.cardiology.matchesTrendSeries(ldlSeries),
        isTrue,
      );
      expect(
        DoctorVisitSpecialty.cardiology.matchesTrendSeries(glucoseSeries),
        isFalse,
      );

      expect(
        DoctorVisitSpecialty.endocrinology.matchesTrendSeries(glucoseSeries),
        isTrue,
      );
      expect(
        DoctorVisitSpecialty.endocrinology.matchesTrendSeries(ldlSeries),
        isFalse,
      );
    });
  });

  group('RecordsPage Specialty Filtering UI', () {
    final records = [
      HealthRecord(
        id: 'rec-1',
        name: 'Systolic Blood Pressure',
        value: '130',
        unit: 'mmHg',
        recordedAt: DateTime.utc(2026, 10, 10),
        category: RecordCategory.vital,
        source: 'Vitals Monitor',
      ),
      HealthRecord(
        id: 'rec-2',
        name: 'LDL Cholesterol',
        value: '140',
        unit: 'mg/dL',
        recordedAt: DateTime.utc(2026, 10, 10),
        category: RecordCategory.lab,
        source: 'Lab',
      ),
      HealthRecord(
        id: 'rec-3',
        name: 'Hemoglobin A1c',
        value: '7.2',
        unit: '%',
        recordedAt: DateTime.utc(2026, 10, 10),
        category: RecordCategory.lab,
        source: 'Lab',
      ),
    ];

    testWidgets('renders specialty filter chips and filters observations', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RecordsPage(
              records: records,
              onRefresh: () async {},
              onLogRecord: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check chips exist
      expect(
        find.byKey(const ValueKey('records-specialty-all')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('records-specialty-cardiology')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('records-specialty-endocrinology')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('records-specialty-annual_wellness')),
        findsOneWidget,
      );

      // Initially all 3 records are visible
      expect(find.text('Systolic Blood Pressure'), findsOneWidget);
      expect(find.text('LDL Cholesterol'), findsOneWidget);
      expect(find.text('Hemoglobin A1c'), findsOneWidget);

      // Tap Endocrinology chip
      final endoChip = find.byKey(
        const ValueKey('records-specialty-endocrinology'),
      );
      await tester.ensureVisible(endoChip);
      await tester.tap(endoChip);
      await tester.pumpAndSettle();

      // Only Hemoglobin A1c should be visible, others hidden
      expect(find.text('Hemoglobin A1c'), findsOneWidget);
      expect(find.text('LDL Cholesterol'), findsNothing);

      // Tap Cardiology chip
      final cardioChip = find.byKey(
        const ValueKey('records-specialty-cardiology'),
      );
      await tester.ensureVisible(cardioChip);
      await tester.tap(cardioChip);
      await tester.pumpAndSettle();

      // LDL and BP should be visible, Hemoglobin A1c hidden
      expect(find.text('Systolic Blood Pressure'), findsOneWidget);
      expect(find.text('LDL Cholesterol'), findsOneWidget);
      expect(find.text('Hemoglobin A1c'), findsNothing);

      // Tap All specialties chip
      final allChip = find.byKey(const ValueKey('records-specialty-all'));
      await tester.ensureVisible(allChip);
      await tester.tap(allChip);
      await tester.pumpAndSettle();

      // All 3 back
      expect(find.text('Systolic Blood Pressure'), findsOneWidget);
      expect(find.text('LDL Cholesterol'), findsOneWidget);
      expect(find.text('Hemoglobin A1c'), findsOneWidget);
    });

    testWidgets('initialSpecialty preselects the specialty filter', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RecordsPage(
              records: records,
              initialSpecialty: DoctorVisitSpecialty.endocrinology,
              onRefresh: () async {},
              onLogRecord: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Only Hemoglobin A1c visible initially
      expect(find.text('Hemoglobin A1c'), findsOneWidget);
      expect(find.text('LDL Cholesterol'), findsNothing);
    });
  });

  group('HealthTrendsPage Specialty Filtering UI', () {
    final records = [
      HealthRecord(
        id: 'rec-1',
        name: 'Heart Rate',
        value: '72',
        unit: 'bpm',
        recordedAt: DateTime.utc(2026, 10, 10),
        category: RecordCategory.vital,
        source: 'Vitals Monitor',
      ),
      HealthRecord(
        id: 'rec-2',
        name: 'Fasting Blood Glucose',
        value: '105',
        unit: 'mg/dL',
        recordedAt: DateTime.utc(2026, 10, 10),
        category: RecordCategory.lab,
        source: 'Lab',
      ),
    ];

    testWidgets('renders specialty choice chips and filters trend series', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: HealthTrendsPage(records: records)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('trend-specialty-all')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('trend-specialty-cardiology')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('trend-specialty-endocrinology')),
        findsOneWidget,
      );

      // Tap Endocrinology chip
      final endoChip = find.byKey(
        const ValueKey('trend-specialty-endocrinology'),
      );
      await tester.ensureVisible(endoChip);
      await tester.tap(endoChip);
      await tester.pumpAndSettle();

      expect(find.text('Fasting Blood Glucose'), findsOneWidget);
      expect(find.text('Heart Rate'), findsNothing);

      // Tap Cardiology chip
      final cardioChip = find.byKey(
        const ValueKey('trend-specialty-cardiology'),
      );
      await tester.ensureVisible(cardioChip);
      await tester.tap(cardioChip);
      await tester.pumpAndSettle();

      expect(find.text('Heart Rate'), findsOneWidget);
      expect(find.text('Fasting Blood Glucose'), findsNothing);
    });
  });

  group('OverviewPage Clinical Specialties Section', () {
    final records = [
      HealthRecord(
        id: 'rec-1',
        name: 'Heart Rate',
        value: '72',
        unit: 'bpm',
        recordedAt: DateTime.utc(2026, 10, 10),
        category: RecordCategory.vital,
        source: 'Vitals Monitor',
      ),
      HealthRecord(
        id: 'rec-2',
        name: 'Fasting Blood Glucose',
        value: '105',
        unit: 'mg/dL',
        recordedAt: DateTime.utc(2026, 10, 10),
        category: RecordCategory.lab,
        source: 'Lab',
      ),
    ];

    testWidgets('renders specialty breakdown and triggers onSelectSpecialty', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      DoctorVisitSpecialty? selectedSpecialty;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OverviewPage(
              records: records,
              loading: false,
              error: null,
              onConnect: () {},
              onSeeAll: () {},
              onRetry: () {},
              onSelectSpecialty: (spec) => selectedSpecialty = spec,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Clinical Specialties'), findsOneWidget);
      final cardFinder = find.byKey(
        const ValueKey('overview-specialty-cardiology'),
      );
      expect(cardFinder, findsOneWidget);

      await tester.tap(cardFinder);
      await tester.pumpAndSettle();

      expect(selectedSpecialty, equals(DoctorVisitSpecialty.cardiology));
    });
  });
}
