import 'package:clinical_assistant/models/doctor_visit_preparation.dart';
import 'package:clinical_assistant/models/health_record.dart';
import 'package:clinical_assistant/ui/export/doctor_visit_wizard_sheet.dart';
import 'package:clinical_assistant/ui/export/export_page.dart';
import 'package:clinical_assistant/ui/overview/overview_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final testRecords = [
    HealthRecord(
      id: 'vital-bp',
      name: 'Systolic Blood Pressure',
      value: '142',
      unit: 'mmHg',
      recordedAt: DateTime.utc(2026, 10, 15),
      category: RecordCategory.vital,
      source: 'Omron Connect',
      referenceRange: '< 120 mmHg',
    ),
    HealthRecord(
      id: 'lab-chol',
      name: 'Total Cholesterol',
      value: '235',
      unit: 'mg/dL',
      recordedAt: DateTime.utc(2026, 10, 10),
      category: RecordCategory.lab,
      source: 'Quest Diagnostics',
      referenceRange: '< 200 mg/dL',
    ),
    HealthRecord(
      id: 'med-1',
      name: 'Lisinopril',
      value: '10 mg',
      unit: 'tablet',
      recordedAt: DateTime.utc(2026, 10, 1),
      category: RecordCategory.medication,
      source: 'Care Portal',
    ),
  ];

  testWidgets('DoctorVisitWizardSheet completes 5-step preparation flow', (
    tester,
  ) async {
    DoctorVisitPreparationConfig? generatedConfig;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DoctorVisitWizardSheet(
            records: testRecords,
            onGenerate: (config) {
              generatedConfig = config;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Step 0: Specialty & Appointment
    expect(
      find.byKey(const ValueKey('doctor-visit-wizard-sheet')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('wizard-step-0')), findsOneWidget);
    expect(find.text('Doctor Visit Preparation Wizard'), findsOneWidget);
    expect(find.text('Step 1 of 5: Specialty & Appointment'), findsOneWidget);

    // Verify accessible tooltips and semantics on specialty option tiles
    final annualWellnessFinder = find.byKey(
      const ValueKey('specialty-option-annual_wellness'),
    );
    final cardiologyFinder = find.byKey(
      const ValueKey('specialty-option-cardiology'),
    );

    final annualTooltip = tester.widget<Tooltip>(
      find.descendant(of: annualWellnessFinder, matching: find.byType(Tooltip)),
    );
    expect(
      annualTooltip.message,
      equals('Annual Wellness & General template (selected)'),
    );

    final cardioTooltip = tester.widget<Tooltip>(
      find.descendant(of: cardiologyFinder, matching: find.byType(Tooltip)),
    );
    expect(
      cardioTooltip.message,
      equals('Select Cardiology Consultation template'),
    );

    final annualSemantics = tester
        .widgetList<Semantics>(
          find.descendant(
            of: annualWellnessFinder,
            matching: find.byType(Semantics),
          ),
        )
        .firstWhere((s) => s.properties.inMutuallyExclusiveGroup == true);
    expect(annualSemantics.properties.button, isTrue);
    expect(annualSemantics.properties.selected, isTrue);
    expect(annualSemantics.properties.inMutuallyExclusiveGroup, isTrue);
    expect(
      annualSemantics.properties.label,
      equals(
        'Annual Wellness & General: Comprehensive checkup covering overall health, preventive care, vitals, and general labs.',
      ),
    );
    expect(annualSemantics.excludeSemantics, isTrue);

    // Select Cardiology template
    await tester.tap(find.byKey(const ValueKey('specialty-option-cardiology')));
    await tester.pumpAndSettle();

    // Enter clinician & facility
    await tester.enterText(
      find.byKey(const ValueKey('wizard-clinician-name-input')),
      'Dr. Sarah Chen',
    );
    await tester.enterText(
      find.byKey(const ValueKey('wizard-facility-name-input')),
      'Metro Heart Clinic',
    );
    await tester.pumpAndSettle();

    // Navigate to Step 1: Vitals
    await tester.tap(find.byKey(const ValueKey('wizard-next-btn')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('wizard-step-1')), findsOneWidget);
    expect(find.text('Step 2 of 5: Vitals & Trends'), findsOneWidget);
    expect(find.text('Systolic Blood Pressure'), findsOneWidget);

    // Navigate to Step 2: Labs
    await tester.tap(find.byKey(const ValueKey('wizard-next-btn')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('wizard-step-2')), findsOneWidget);
    expect(find.text('Step 3 of 5: Lab Results'), findsOneWidget);
    expect(find.text('Total Cholesterol'), findsOneWidget);
    expect(find.text('HIGH'), findsOneWidget);

    // Navigate to Step 3: Medications
    await tester.tap(find.byKey(const ValueKey('wizard-next-btn')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('wizard-step-3')), findsOneWidget);
    expect(find.text('Step 4 of 5: Medications & Questions'), findsOneWidget);
    expect(find.text('Lisinopril'), findsOneWidget);

    // Enter medication note
    await tester.enterText(
      find.byKey(const ValueKey('wizard-med-note-input-Lisinopril')),
      'Inquire about dry cough side effect',
    );
    await tester.pumpAndSettle();

    // Navigate to Step 4: Agenda
    await tester.tap(find.byKey(const ValueKey('wizard-next-btn')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('wizard-step-4')), findsOneWidget);
    expect(find.text('Step 5 of 5: Visit Agenda & Questions'), findsOneWidget);

    // Add custom agenda item using onSubmitted
    final inputFinder = find.byKey(const ValueKey('wizard-agenda-input'));
    await tester.ensureVisible(inputFinder);
    await tester.enterText(inputFinder, 'Review dietary sodium limits');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.text('Review dietary sodium limits'), findsOneWidget);

    // Finish wizard
    final generateBtn = find.byKey(const ValueKey('wizard-generate-btn'));
    await tester.ensureVisible(generateBtn);
    await tester.tap(generateBtn);
    await tester.pumpAndSettle();

    expect(generatedConfig, isNotNull);
    expect(generatedConfig!.specialty, DoctorVisitSpecialty.cardiology);
    expect(generatedConfig!.clinicianName, 'Dr. Sarah Chen');
    expect(generatedConfig!.facilityName, 'Metro Heart Clinic');
    expect(
      generatedConfig!.medicationNotes['Lisinopril'],
      'Inquire about dry cough side effect',
    );
    expect(
      generatedConfig!.agendaItems.contains('Review dietary sodium limits'),
      isTrue,
    );
  });

  testWidgets(
    'OverviewPage displays upcoming doctor visit banner and triggers callback',
    (tester) async {
      var bannerTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OverviewPage(
              records: testRecords,
              loading: false,
              error: null,
              onConnect: () {},
              onSeeAll: () {},
              onRetry: () {},
              onPrepareDoctorVisit: () => bannerTapped = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final banner = find.byKey(const ValueKey('overview-doctor-visit-banner'));
      await tester.scrollUntilVisible(
        banner,
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(banner, findsOneWidget);
      expect(find.text('Upcoming Doctor Visit?'), findsOneWidget);

      await tester.tap(banner);
      await tester.pumpAndSettle();
      expect(bannerTapped, isTrue);
    },
  );

  testWidgets('ExportPage provides Launch Wizard action and opens wizard', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ExportPage(
            records: testRecords,
            exporting: false,
            onPdf: (_) {},
            onFhir: (_) {},
            onCsv: (_) {},
            onDoctorVisitWizard: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final wizardAction = find.byKey(
      const ValueKey('export-action-doctor-visit-wizard'),
    );
    await tester.scrollUntilVisible(
      wizardAction,
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(wizardAction, findsOneWidget);
    expect(find.text('Doctor Visit Preparation Wizard'), findsOneWidget);

    final btnFinder = find.widgetWithText(OutlinedButton, 'Launch Wizard');
    await tester.scrollUntilVisible(
      btnFinder,
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(btnFinder);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('doctor-visit-wizard-sheet')),
      findsOneWidget,
    );
  });
}
