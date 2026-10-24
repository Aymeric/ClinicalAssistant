import 'package:clinical_assistant/models/health_record.dart';
import 'package:clinical_assistant/trends/health_trend.dart';
import 'package:clinical_assistant/trends/measurement_picker_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MeasurementSelector UX & Accessibility', () {
    testWidgets('displays tooltip and semantics when series is selected', (
      tester,
    ) async {
      final record = HealthRecord(
        id: '1',
        name: 'Heart Rate',
        value: '72',
        unit: 'bpm',
        recordedAt: DateTime.utc(2025, 6, 1),
        category: RecordCategory.vital,
        source: 'Manual',
      );

      final series = HealthTrendSeries(
        id: 'hr',
        name: 'Heart Rate',
        unit: 'bpm',
        category: RecordCategory.vital,
        points: [HealthTrendPoint(record: record, value: 72)],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MeasurementSelector(selected: series, onPressed: () {}),
          ),
        ),
      );

      // Verify Tooltip presence
      expect(find.widgetWithText(Tooltip, 'Heart Rate (bpm)'), findsOneWidget);
      final tooltipWidget = tester.widget<Tooltip>(find.byType(Tooltip));
      expect(tooltipWidget.message, 'Choose a measurement to view trends');

      // Find the explicit Semantics widget created by MeasurementSelector
      final semanticsFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label != null &&
            widget.properties.label!.contains(
              'Selected measurement: Heart Rate (bpm)',
            ),
      );
      expect(semanticsFinder, findsOneWidget);

      final semanticsWidget = tester.widget<Semantics>(semanticsFinder);
      expect(semanticsWidget.properties.button, true);
      expect(semanticsWidget.properties.enabled, true);
      expect(
        semanticsWidget.properties.label,
        contains('Selected measurement: Heart Rate (bpm)'),
      );
      expect(semanticsWidget.properties.label, contains('Vitals'));
      expect(
        semanticsWidget.properties.label,
        contains('latest reading 72 bpm'),
      );
    });

    testWidgets(
      'displays fallback tooltip and semantics when disabled/null state',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: MeasurementSelector(selected: null, onPressed: null),
            ),
          ),
        );

        expect(find.text('No measurements available'), findsOneWidget);

        final tooltipWidget = tester.widget<Tooltip>(find.byType(Tooltip));
        expect(tooltipWidget.message, 'Measurement selector');

        final semanticsFinder = find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label == 'No measurements available.',
        );
        expect(semanticsFinder, findsOneWidget);

        final semanticsWidget = tester.widget<Semantics>(semanticsFinder);
        expect(semanticsWidget.properties.button, false);
        expect(semanticsWidget.properties.enabled, false);
        expect(semanticsWidget.properties.label, 'No measurements available.');
      },
    );
  });
}
