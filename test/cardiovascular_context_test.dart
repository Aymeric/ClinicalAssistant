import 'package:clinical_assistant/models/cardiovascular_context.dart';
import 'package:clinical_assistant/models/health_record.dart';
import 'package:clinical_assistant/trends/blood_pressure_context_card.dart';
import 'package:clinical_assistant/trends/health_trend.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BloodPressureStaging Classification (ACC/AHA 2017)', () {
    test('classifies Normal BP when systolic < 120 and diastolic < 80', () {
      final staging = BloodPressureStaging.classify(
        systolic: 118,
        diastolic: 78,
      );
      expect(staging, BloodPressureStaging.normal);
      expect(staging.label, 'Normal');
    });

    test('classifies Elevated BP when systolic 120-129 and diastolic < 80', () {
      final staging = BloodPressureStaging.classify(
        systolic: 124,
        diastolic: 76,
      );
      expect(staging, BloodPressureStaging.elevated);
      expect(staging.label, 'Elevated');
    });

    test(
      'classifies Stage 1 Hypertension when systolic 130-139 or diastolic 80-89',
      () {
        final s1 = BloodPressureStaging.classify(systolic: 134, diastolic: 75);
        expect(s1, BloodPressureStaging.stage1);

        final s2 = BloodPressureStaging.classify(systolic: 115, diastolic: 84);
        expect(s2, BloodPressureStaging.stage1);
      },
    );

    test(
      'classifies Stage 2 Hypertension when systolic 140-179 or diastolic 90-119',
      () {
        final s1 = BloodPressureStaging.classify(systolic: 144, diastolic: 88);
        expect(s1, BloodPressureStaging.stage2);

        final s2 = BloodPressureStaging.classify(systolic: 125, diastolic: 94);
        expect(s2, BloodPressureStaging.stage2);
      },
    );

    test(
      'classifies Hypertensive Crisis when systolic >= 180 or diastolic >= 120',
      () {
        final s1 = BloodPressureStaging.classify(systolic: 184, diastolic: 100);
        expect(s1, BloodPressureStaging.hypertensiveCrisis);

        final s2 = BloodPressureStaging.classify(systolic: 150, diastolic: 122);
        expect(s2, BloodPressureStaging.hypertensiveCrisis);
      },
    );
  });

  group('BloodPressureContext metadata & serialization', () {
    test('JSON round-trip preserves posture, arm, cuff, and resting period', () {
      const context = BloodPressureContext(
        posture: BloodPressurePosture.sitting,
        arm: BloodPressureArm.left,
        cuff: BloodPressureCuff.regularAdult,
        restingMinutes: 5,
      );

      final json = context.toJson();
      final restored = BloodPressureContext.fromJson(json);

      expect(restored.posture, BloodPressurePosture.sitting);
      expect(restored.arm, BloodPressureArm.left);
      expect(restored.cuff, BloodPressureCuff.regularAdult);
      expect(restored.restingMinutes, 5);
      expect(
        restored.formatSummary(),
        'Posture: Sitting · Arm: Left arm · Cuff: Adult Regular (27–34 cm) · Rested: 5m',
      );
    });

    test('parses context from notes string fallback', () {
      const notes =
          'Posture: Sitting · Arm: Right arm · Cuff: Wrist monitor · Rest: 10 mins';
      final parsed = BloodPressureContext.fromNotes(notes);
      expect(parsed, isNotNull);
      expect(parsed!.posture, BloodPressurePosture.sitting);
      expect(parsed.arm, BloodPressureArm.right);
      expect(parsed.cuff, BloodPressureCuff.wrist);
      expect(parsed.restingMinutes, 10);
    });
  });

  group('BloodPressureDiurnalPeriod', () {
    test(
      'classifies morning, midday, evening, and nocturnal periods correctly',
      () {
        expect(
          BloodPressureDiurnalPeriod.fromDateTime(DateTime(2026, 1, 1, 8, 30)),
          BloodPressureDiurnalPeriod.morning,
        );
        expect(
          BloodPressureDiurnalPeriod.fromDateTime(DateTime(2026, 1, 1, 14, 0)),
          BloodPressureDiurnalPeriod.midday,
        );
        expect(
          BloodPressureDiurnalPeriod.fromDateTime(DateTime(2026, 1, 1, 19, 45)),
          BloodPressureDiurnalPeriod.evening,
        );
        expect(
          BloodPressureDiurnalPeriod.fromDateTime(DateTime(2026, 1, 1, 2, 15)),
          BloodPressureDiurnalPeriod.nocturnal,
        );
      },
    );
  });

  group('BloodPressureContextCard Widget Test', () {
    testWidgets(
      'displays staging chip and diurnal morning vs evening comparisons',
      (tester) async {
        final morningRecordSys = HealthRecord(
          id: 'sys-m',
          name: 'Systolic Blood Pressure',
          value: '128',
          unit: 'mmHg',
          category: RecordCategory.vital,
          recordedAt: DateTime(2026, 1, 1, 8, 0),
          source: 'Manual Entry',
        );
        final morningRecordDia = HealthRecord(
          id: 'dia-m',
          name: 'Diastolic Blood Pressure',
          value: '78',
          unit: 'mmHg',
          category: RecordCategory.vital,
          recordedAt: DateTime(2026, 1, 1, 8, 0),
          source: 'Manual Entry',
        );

        final eveningRecordSys = HealthRecord(
          id: 'sys-e',
          name: 'Systolic Blood Pressure',
          value: '136',
          unit: 'mmHg',
          category: RecordCategory.vital,
          recordedAt: DateTime(2026, 1, 1, 20, 0),
          source: 'Manual Entry',
        );
        final eveningRecordDia = HealthRecord(
          id: 'dia-e',
          name: 'Diastolic Blood Pressure',
          value: '84',
          unit: 'mmHg',
          category: RecordCategory.vital,
          recordedAt: DateTime(2026, 1, 1, 20, 0),
          source: 'Manual Entry',
        );

        final sysPoints = [
          HealthTrendPoint(record: morningRecordSys, value: 128),
          HealthTrendPoint(record: eveningRecordSys, value: 136),
        ];
        final diaPoints = [
          HealthTrendPoint(record: morningRecordDia, value: 78),
          HealthTrendPoint(record: eveningRecordDia, value: 84),
        ];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: BloodPressureContextCard(
                  systolicPoints: sysPoints,
                  diastolicPoints: diaPoints,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('bp-cardiovascular-context-card')),
          findsOneWidget,
        );
        expect(find.text('Cardiovascular Context & Staging'), findsOneWidget);
        // Latest reading is 136/84 => Stage 1 Hypertension
        expect(find.text('Stage 1 Hypertension'), findsOneWidget);

        // Check diurnal summaries
        expect(find.text('Morning Average'), findsOneWidget);
        expect(find.text('Evening Average'), findsOneWidget);
        expect(find.text('128 / 78 mmHg'), findsOneWidget);
        expect(find.text('136 / 84 mmHg'), findsOneWidget);
      },
    );
  });
}
