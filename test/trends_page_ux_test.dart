import 'package:clinical_assistant/models/doctor_visit_preparation.dart';
import 'package:clinical_assistant/models/health_record.dart';
import 'package:clinical_assistant/trends/health_trends_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HealthTrendsPage UX & Accessibility', () {
    final sampleRecord = HealthRecord(
      id: 'vital-1',
      name: 'Heart Rate',
      category: RecordCategory.vital,
      value: '72',
      unit: 'bpm',
      recordedAt: DateTime.utc(2026, 10, 1),
      source: 'Apple Health',
    );

    testWidgets(
      'HealthTrendsPage trend range choice chips display accessible tooltips',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1200, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: HealthTrendsPage(records: [sampleRecord])),
          ),
        );
        await tester.pumpAndSettle();

        final days30Chip = tester.widget<ChoiceChip>(
          find.byKey(const ValueKey('trend-range-days30')),
        );
        expect(
          days30Chip.tooltip,
          equals('Filter trend data from last 30 days'),
        );

        final days90Chip = tester.widget<ChoiceChip>(
          find.byKey(const ValueKey('trend-range-days90')),
        );
        expect(
          days90Chip.tooltip,
          equals('Filter trend data from last 90 days'),
        );

        final yearChip = tester.widget<ChoiceChip>(
          find.byKey(const ValueKey('trend-range-year')),
        );
        expect(yearChip.tooltip, equals('Filter trend data from last 1 year'));

        final allChip = tester.widget<ChoiceChip>(
          find.byKey(const ValueKey('trend-range-all')),
        );
        expect(allChip.tooltip, equals('Filter trend data from all time'));
      },
    );

    testWidgets(
      'HealthTrendsPage specialty choice chips display accessible tooltips',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1200, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: HealthTrendsPage(records: [sampleRecord])),
          ),
        );
        await tester.pumpAndSettle();

        final allSpecialtiesChip = tester.widget<ChoiceChip>(
          find.byKey(const ValueKey('trend-specialty-all')),
        );
        expect(
          allSpecialtiesChip.tooltip,
          equals('Filter trends across all specialties'),
        );

        for (final spec in DoctorVisitSpecialty.values) {
          final chip = tester.widget<ChoiceChip>(
            find.byKey(ValueKey('trend-specialty-${spec.id}')),
          );
          expect(chip.tooltip, equals('Filter trends by ${spec.shortLabel}'));
        }
      },
    );
  });
}
