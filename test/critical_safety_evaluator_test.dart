import 'package:clinical_assistant/models/health_record.dart';
import 'package:clinical_assistant/safety/critical_safety_evaluator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 10, 26, 12, 0);

  group('CriticalSafetyEvaluator - Blood Pressure', () {
    test('detects Hypertensive Crisis when Systolic >= 180 mmHg', () {
      final record = HealthRecord(
        id: 'bp-sys-1',
        name: 'Systolic Blood Pressure',
        value: '185',
        unit: 'mmHg',
        recordedAt: now,
        category: RecordCategory.vital,
        source: 'Home Cuff',
      );

      final alert = CriticalSafetyEvaluator.evaluate(record);
      expect(alert, isNotNull);
      expect(alert!.type, CriticalSafetyType.hypertensiveCrisis);
      expect(alert.title, 'Hypertensive Crisis Range');
      expect(alert.readingSummary, '185 mmHg');
      expect(alert.emergencyGuidance, contains('180/120 mmHg'));
    });

    test('detects Hypertensive Crisis when Diastolic >= 120 mmHg', () {
      final record = HealthRecord(
        id: 'bp-dia-1',
        name: 'Diastolic Blood Pressure',
        value: '124',
        unit: 'mmHg',
        recordedAt: now,
        category: RecordCategory.vital,
        source: 'Home Cuff',
      );

      final alert = CriticalSafetyEvaluator.evaluate(record);
      expect(alert, isNotNull);
      expect(alert!.type, CriticalSafetyType.hypertensiveCrisis);
      expect(alert.readingSummary, '124 mmHg');
    });

    test(
      'pairs systolic and diastolic records accurately for combined summary',
      () {
        final sys = HealthRecord(
          id: 'bp-sys-2',
          name: 'Systolic Blood Pressure',
          value: '190',
          unit: 'mmHg',
          recordedAt: now,
          category: RecordCategory.vital,
          source: 'Clinic',
        );
        final dia = HealthRecord(
          id: 'bp-dia-2',
          name: 'Diastolic Blood Pressure',
          value: '122',
          unit: 'mmHg',
          recordedAt: now,
          category: RecordCategory.vital,
          source: 'Clinic',
        );

        final alert = CriticalSafetyEvaluator.evaluate(sys, pairedRecord: dia);
        expect(alert, isNotNull);
        expect(alert!.readingSummary, '190/122 mmHg');
      },
    );

    test(
      'detects critical threshold from combined blood pressure format (185/125)',
      () {
        final combined = HealthRecord(
          id: 'bp-comb-1',
          name: 'Blood Pressure',
          value: '185/125',
          unit: 'mmHg',
          recordedAt: now,
          category: RecordCategory.vital,
          source: 'Cuff',
        );

        final alert = CriticalSafetyEvaluator.evaluate(combined);
        expect(alert, isNotNull);
        expect(alert!.type, CriticalSafetyType.hypertensiveCrisis);
      },
    );

    test(
      'does not trigger on elevated but non-crisis blood pressure (e.g. 175/115)',
      () {
        final sys = HealthRecord(
          id: 'bp-sys-norm',
          name: 'Systolic Blood Pressure',
          value: '175',
          unit: 'mmHg',
          recordedAt: now,
          category: RecordCategory.vital,
          source: 'Home Cuff',
        );
        final dia = HealthRecord(
          id: 'bp-dia-norm',
          name: 'Diastolic Blood Pressure',
          value: '115',
          unit: 'mmHg',
          recordedAt: now,
          category: RecordCategory.vital,
          source: 'Home Cuff',
        );

        expect(
          CriticalSafetyEvaluator.evaluate(sys, pairedRecord: dia),
          isNull,
        );
      },
    );
  });

  group('CriticalSafetyEvaluator - Blood Glucose', () {
    test('detects Severe Hypoglycemia when glucose < 54 mg/dL', () {
      final record = HealthRecord(
        id: 'glu-low',
        name: 'Blood Glucose',
        value: '48',
        unit: 'mg/dL',
        recordedAt: now,
        category: RecordCategory.lab,
        source: 'CGM',
      );

      final alert = CriticalSafetyEvaluator.evaluate(record);
      expect(alert, isNotNull);
      expect(alert!.type, CriticalSafetyType.severeHypoglycemia);
      expect(alert.title, 'Severe Hypoglycemia');
      expect(alert.emergencyGuidance, contains('fast-acting carbohydrates'));
    });

    test('detects Severe Hypoglycemia when glucose < 3.0 mmol/L', () {
      final record = HealthRecord(
        id: 'glu-low-mmol',
        name: 'Fasting Blood Glucose',
        value: '2.8',
        unit: 'mmol/L',
        recordedAt: now,
        category: RecordCategory.lab,
        source: 'LabCorp',
      );

      final alert = CriticalSafetyEvaluator.evaluate(record);
      expect(alert, isNotNull);
      expect(alert!.type, CriticalSafetyType.severeHypoglycemia);
    });

    test(
      'does not trigger on normal or moderate glucose levels (e.g. 72 mg/dL)',
      () {
        final record = HealthRecord(
          id: 'glu-normal',
          name: 'Blood Glucose',
          value: '72',
          unit: 'mg/dL',
          recordedAt: now,
          category: RecordCategory.lab,
          source: 'Meter',
        );

        expect(CriticalSafetyEvaluator.evaluate(record), isNull);
      },
    );
  });

  group('CriticalSafetyEvaluator - Oxygen Saturation (SpO2)', () {
    test('detects Severe Hypoxemia when SpO2 < 88%', () {
      final record = HealthRecord(
        id: 'spo2-low',
        name: 'Oxygen (SpO2)',
        value: '84',
        unit: '%',
        recordedAt: now,
        category: RecordCategory.vital,
        source: 'Pulse Oximeter',
      );

      final alert = CriticalSafetyEvaluator.evaluate(record);
      expect(alert, isNotNull);
      expect(alert!.type, CriticalSafetyType.severeHypoxemia);
      expect(alert.title, 'Severe Hypoxemia');
      expect(alert.emergencyGuidance, contains('emergency medical care'));
    });

    test('does not trigger on normal oxygen levels (e.g. 96%)', () {
      final record = HealthRecord(
        id: 'spo2-normal',
        name: 'Oxygen (SpO2)',
        value: '96',
        unit: '%',
        recordedAt: now,
        category: RecordCategory.vital,
        source: 'Pulse Oximeter',
      );

      expect(CriticalSafetyEvaluator.evaluate(record), isNull);
    });

    test(
      'does not trigger false critical alert on raw decimal fraction SpO2 (e.g. 0.98)',
      () {
        final record = HealthRecord(
          id: 'spo2-raw-fraction',
          name: 'Blood oxygen',
          value: '0.98',
          unit: '%',
          recordedAt: now,
          category: RecordCategory.vital,
          source: 'Apple Health',
          code: 'BLOOD_OXYGEN',
        );

        expect(CriticalSafetyEvaluator.evaluate(record), isNull);
      },
    );

    test(
      'detects Severe Hypoxemia from raw decimal fraction SpO2 (e.g. 0.84)',
      () {
        final record = HealthRecord(
          id: 'spo2-raw-critical',
          name: 'Blood oxygen',
          value: '0.84',
          unit: '%',
          recordedAt: now,
          category: RecordCategory.vital,
          source: 'Apple Health',
          code: 'BLOOD_OXYGEN',
        );

        final alert = CriticalSafetyEvaluator.evaluate(record);
        expect(alert, isNotNull);
        expect(alert!.type, CriticalSafetyType.severeHypoxemia);
        expect(alert.readingSummary, '84 %');
      },
    );
  });

  group('CriticalSafetyEvaluator - Heart Rate', () {
    test(
      'detects Critical Heart Rate on resting HR when below threshold or > 140 bpm',
      () {
        final lowHr = HealthRecord(
          id: 'hr-low',
          name: 'Resting Heart Rate',
          value: '33',
          unit: 'bpm',
          recordedAt: now,
          category: RecordCategory.vital,
          source: 'Watch',
          code: 'RESTING_HEART_RATE',
        );

        final highHr = HealthRecord(
          id: 'hr-high',
          name: 'Resting Heart Rate',
          value: '155',
          unit: 'bpm',
          recordedAt: now,
          category: RecordCategory.vital,
          source: 'Watch',
          code: 'RESTING_HEART_RATE',
        );

        expect(
          CriticalSafetyEvaluator.evaluate(lowHr)?.type,
          CriticalSafetyType.severeArrhythmia,
        );
        expect(
          CriticalSafetyEvaluator.evaluate(highHr)?.type,
          CriticalSafetyType.severeArrhythmia,
        );
      },
    );

    test(
      'does not trigger false critical alert on continuous active HEART_RATE > 140 bpm (e.g. 155 bpm during exercise)',
      () {
        final exerciseHr = HealthRecord(
          id: 'hr-exercise',
          name: 'Heart rate',
          value: '155',
          unit: 'bpm',
          recordedAt: now,
          category: RecordCategory.vital,
          source: 'Apple Health',
          code: 'HEART_RATE',
        );

        expect(CriticalSafetyEvaluator.evaluate(exerciseHr), isNull);
      },
    );

    test(
      'triggers Critical Heart Rate when continuous HEART_RATE has severe bradycardia (< 35 bpm default)',
      () {
        final bradyHr = HealthRecord(
          id: 'hr-brady',
          name: 'Heart rate',
          value: '33',
          unit: 'bpm',
          recordedAt: now,
          category: RecordCategory.vital,
          source: 'Apple Health',
          code: 'HEART_RATE',
        );

        final alert = CriticalSafetyEvaluator.evaluate(bradyHr);
        expect(alert, isNotNull);
        expect(alert!.type, CriticalSafetyType.severeArrhythmia);
      },
    );

    test(
      'does not trigger false critical alert on physiological athlete resting HR of 39.68 bpm or 39.39 bpm on default 35 bpm threshold',
      () {
        final rhr1 = HealthRecord(
          id: 'hr-39-68',
          name: 'Resting Heart Rate',
          value: '39.68',
          unit: 'bpm',
          recordedAt: now,
          category: RecordCategory.vital,
          source: 'Tracker',
          code: 'RESTING_HEART_RATE',
        );

        final rhr2 = HealthRecord(
          id: 'hr-39-39',
          name: 'Resting Heart Rate',
          value: '39.39',
          unit: 'bpm',
          recordedAt: now,
          category: RecordCategory.vital,
          source: 'Tracker',
          code: 'RESTING_HEART_RATE',
        );

        expect(CriticalSafetyEvaluator.evaluate(rhr1), isNull);
        expect(CriticalSafetyEvaluator.evaluate(rhr2), isNull);
      },
    );

    test(
      'respects custom heartRateCriticalLow threshold for standard adult (40 bpm) vs elite athlete (30 bpm)',
      () {
        final rhr = HealthRecord(
          id: 'hr-36',
          name: 'Resting Heart Rate',
          value: '36',
          unit: 'bpm',
          recordedAt: now,
          category: RecordCategory.vital,
          source: 'Tracker',
          code: 'RESTING_HEART_RATE',
        );

        // On default athletic profile (<35 bpm), 36 bpm is NOT critical:
        expect(
          CriticalSafetyEvaluator.evaluate(
            rhr,
            heartRateCriticalLow:
                CriticalSafetyEvaluator.kHeartRateCriticalLowDefault,
          ),
          isNull,
        );

        // On standard adult profile (<40 bpm), 36 bpm IS critical:
        final standardAlert = CriticalSafetyEvaluator.evaluate(
          rhr,
          heartRateCriticalLow:
              CriticalSafetyEvaluator.kHeartRateCriticalLowStandard,
        );
        expect(standardAlert, isNotNull);
        expect(standardAlert!.type, CriticalSafetyType.severeArrhythmia);

        // On elite endurance profile (<30 bpm), 32 bpm is NOT critical:
        final rhr32 = HealthRecord(
          id: 'hr-32',
          name: 'Resting Heart Rate',
          value: '32',
          unit: 'bpm',
          recordedAt: now,
          category: RecordCategory.vital,
          source: 'Tracker',
          code: 'RESTING_HEART_RATE',
        );
        expect(
          CriticalSafetyEvaluator.evaluate(
            rhr32,
            heartRateCriticalLow:
                CriticalSafetyEvaluator.kHeartRateCriticalLowElite,
          ),
          isNull,
        );
      },
    );
  });

  group('CriticalSafetyEvaluator - evaluateAll', () {
    test(
      'pairs BP readings, identifies multiple alerts, and sorts newest first',
      () {
        final records = [
          HealthRecord(
            id: 'hr-1',
            name: 'Heart Rate',
            value: '72',
            unit: 'bpm',
            recordedAt: now.subtract(const Duration(hours: 3)),
            category: RecordCategory.vital,
            source: 'Watch',
          ),
          HealthRecord(
            id: 'spo2-crit',
            name: 'Oxygen (SpO2)',
            value: '82',
            unit: '%',
            recordedAt: now.subtract(const Duration(hours: 2)),
            category: RecordCategory.vital,
            source: 'Pulse Ox',
          ),
          HealthRecord(
            id: 'sys-crit',
            name: 'Systolic Blood Pressure',
            value: '192',
            unit: 'mmHg',
            recordedAt: now.subtract(const Duration(hours: 1)),
            category: RecordCategory.vital,
            source: 'Cuff',
          ),
          HealthRecord(
            id: 'dia-crit',
            name: 'Diastolic Blood Pressure',
            value: '124',
            unit: 'mmHg',
            recordedAt: now.subtract(const Duration(hours: 1)),
            category: RecordCategory.vital,
            source: 'Cuff',
          ),
        ];

        final alerts = CriticalSafetyEvaluator.evaluateAll(records);
        expect(alerts.length, 2);

        // Newest first: BP (1h ago) before SpO2 (2h ago)
        expect(alerts[0].type, CriticalSafetyType.hypertensiveCrisis);
        expect(alerts[0].readingSummary, '192/124 mmHg');
        expect(alerts[1].type, CriticalSafetyType.severeHypoxemia);
        expect(alerts[1].readingSummary, '82 %');
      },
    );

    test('ignores non-vital and non-lab records', () {
      final record = HealthRecord(
        id: 'med-1',
        name: 'Blood Pressure Medication',
        value: '180 mg',
        unit: '',
        recordedAt: now,
        category: RecordCategory.medication,
        source: 'Manual Entry',
      );

      expect(CriticalSafetyEvaluator.evaluateAll([record]), isEmpty);
    });
  });
}
