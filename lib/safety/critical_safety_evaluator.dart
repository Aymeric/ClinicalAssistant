import '../models/health_record.dart';

/// Categories of acute clinical critical thresholds.
enum CriticalSafetyType {
  hypertensiveCrisis(
    title: 'Hypertensive Crisis Range',
    emergencySummary:
        'A blood pressure reading of 180/120 mmHg or higher requires immediate medical evaluation. If you have chest pain, shortness of breath, back/abdominal pain, numbness, weakness, or changes in vision or speech, call emergency services (such as 911 or 112) immediately.',
  ),
  severeHypoglycemia(
    title: 'Severe Hypoglycemia',
    emergencySummary:
        'A blood glucose level below 54 mg/dL (3.0 mmol/L) is dangerously low. If conscious, consume 15–20g of fast-acting carbohydrates immediately (such as glucose tablets, fruit juice, or regular soda) and recheck in 15 minutes. If symptoms persist or confusion occurs, seek emergency medical assistance or administer prescribed emergency glucagon.',
  ),
  severeHypoxemia(
    title: 'Severe Hypoxemia',
    emergencySummary:
        'An oxygen saturation level below 88% indicates critically reduced blood oxygenation. Seek immediate emergency medical care or call emergency services (such as 911 or 112).',
  ),
  severeArrhythmia(
    title: 'Critical Heart Rate',
    emergencySummary:
        'A resting heart rate below 35 bpm or above 140 bpm requires urgent medical evaluation. If accompanied by chest discomfort, dizziness, shortness of breath, or lightheadedness, call emergency services (such as 911 or 112) immediately.',
  );

  const CriticalSafetyType({
    required this.title,
    required this.emergencySummary,
  });

  final String title;
  final String emergencySummary;
}

/// A structured red-flag safety alert triggered when a vital sign or lab result
/// crosses consensus emergency thresholds.
class CriticalSafetyAlert {
  const CriticalSafetyAlert({
    required this.type,
    required this.record,
    required this.readingSummary,
    this.pairedRecord,
    this.customEmergencyGuidance,
  });

  final CriticalSafetyType type;
  final HealthRecord record;
  final String readingSummary;
  final HealthRecord? pairedRecord;
  final String? customEmergencyGuidance;

  String get title => type.title;
  String get emergencyGuidance =>
      customEmergencyGuidance ?? type.emergencySummary;

  static const String clinicalDisclaimer =
      'Descriptive safety notice based on standard clinical consensus thresholds. Clinical Assistant provides informational guidance only and does not provide automated clinical diagnosis or triage.';
}

/// Evaluates health observations against published clinical critical red-flag thresholds.
class CriticalSafetyEvaluator {
  const CriticalSafetyEvaluator._();

  static const double kSystolicCritical = 180.0;
  static const double kDiastolicCritical = 120.0;
  static const double kGlucoseCriticalMgDl = 54.0;
  static const double kGlucoseCriticalMmolL = 3.0;
  static const double kOxygenCriticalPercent = 88.0;

  /// Clinical threshold constants for resting bradycardia:
  /// - Standard non-athletic adult threshold (< 40 bpm)
  /// - Athletic / Active baseline calibrated emergency threshold (< 35 bpm)
  /// - Elite endurance baseline threshold (< 30 bpm)
  static const double kHeartRateCriticalLowStandard = 40.0;
  static const double kHeartRateCriticalLowAthletic = 35.0;
  static const double kHeartRateCriticalLowElite = 30.0;

  /// Default clinical critical resting bradycardia threshold (calibrated to < 35 bpm).
  static const double kHeartRateCriticalLowDefault =
      kHeartRateCriticalLowAthletic;
  static const double kHeartRateCriticalLow = kHeartRateCriticalLowDefault;
  static const double kHeartRateCriticalHigh = 140.0;

  /// Evaluates a single record for critical thresholds.
  /// If the record is part of a paired measurement (such as systolic with diastolic),
  /// pass [pairedRecord] for a combined alert.
  /// [heartRateCriticalLow] sets the critical resting bradycardia threshold (defaults to [kHeartRateCriticalLowDefault]).
  static CriticalSafetyAlert? evaluate(
    HealthRecord record, {
    HealthRecord? pairedRecord,
    double heartRateCriticalLow = kHeartRateCriticalLowDefault,
  }) {
    if (record.category != RecordCategory.vital &&
        record.category != RecordCategory.lab) {
      return null;
    }

    final lowerName = record.name.toLowerCase();
    final code = record.code?.trim();

    // 1. Blood Pressure: Systolic
    if (_isSystolic(lowerName, code)) {
      final sysVal = parseHealthRecordValue(record.value);
      double? diaVal;
      if (pairedRecord != null &&
          _isDiastolic(
            pairedRecord.name.toLowerCase(),
            pairedRecord.code?.trim(),
          )) {
        diaVal = parseHealthRecordValue(pairedRecord.value);
      }

      final isSysCrit = sysVal != null && sysVal >= kSystolicCritical;
      final isDiaCrit = diaVal != null && diaVal >= kDiastolicCritical;

      if (isSysCrit || isDiaCrit) {
        final summary = diaVal != null
            ? '${sysVal?.round() ?? '—'}/${diaVal.round()} mmHg'
            : record.displayValue;
        return CriticalSafetyAlert(
          type: CriticalSafetyType.hypertensiveCrisis,
          record: record,
          readingSummary: summary,
          pairedRecord: pairedRecord,
        );
      }
      return null;
    }

    // 2. Blood Pressure: Diastolic standalone check
    if (_isDiastolic(lowerName, code)) {
      final diaVal = parseHealthRecordValue(record.value);
      double? sysVal;
      if (pairedRecord != null &&
          _isSystolic(
            pairedRecord.name.toLowerCase(),
            pairedRecord.code?.trim(),
          )) {
        sysVal = parseHealthRecordValue(pairedRecord.value);
      }

      final isDiaCrit = diaVal != null && diaVal >= kDiastolicCritical;
      final isSysCrit = sysVal != null && sysVal >= kSystolicCritical;

      if (isDiaCrit || isSysCrit) {
        final summary = sysVal != null
            ? '${sysVal.round()}/${diaVal?.round() ?? '—'} mmHg'
            : record.displayValue;
        return CriticalSafetyAlert(
          type: CriticalSafetyType.hypertensiveCrisis,
          record: record,
          readingSummary: summary,
          pairedRecord: pairedRecord,
        );
      }
      return null;
    }

    // 3. Combined Blood Pressure in a single record (e.g. "185/125")
    if (_isCombinedBp(lowerName, code)) {
      final parts = record.value.split('/');
      if (parts.length == 2) {
        final sys = double.tryParse(parts[0].trim());
        final dia = double.tryParse(parts[1].trim());
        if ((sys != null && sys >= kSystolicCritical) ||
            (dia != null && dia >= kDiastolicCritical)) {
          return CriticalSafetyAlert(
            type: CriticalSafetyType.hypertensiveCrisis,
            record: record,
            readingSummary: record.displayValue,
          );
        }
      }
    }

    // 4. Blood Glucose
    if (_isGlucose(lowerName, code)) {
      final val = parseHealthRecordValue(record.value);
      if (val != null && val > 0) {
        final isMmol =
            record.unit.toLowerCase().contains('mmol') ||
            (record.referenceRange?.toLowerCase().contains('mmol') ?? false);
        final threshold = isMmol ? kGlucoseCriticalMmolL : kGlucoseCriticalMgDl;
        if (val < threshold) {
          return CriticalSafetyAlert(
            type: CriticalSafetyType.severeHypoglycemia,
            record: record,
            readingSummary: record.displayValue,
          );
        }
      }
      return null;
    }

    // 5. Oxygen Saturation (SpO2)
    if (_isOxygen(lowerName, code)) {
      final rawVal = parseHealthRecordValue(record.value);
      if (rawVal != null && rawVal > 0) {
        // Defensively normalize fraction values in (0, 1] (common in raw health
        // sources e.g. 0.98 for 98%) to standard 0–100 percentage.
        final val = rawVal <= 1.0 ? rawVal * 100 : rawVal;
        if (val < kOxygenCriticalPercent) {
          final summary = rawVal <= 1.0
              ? '${formatSensibleNumber(val)} ${record.unit.isEmpty ? '%' : record.unit}'
                    .trim()
              : record.displayValue;
          return CriticalSafetyAlert(
            type: CriticalSafetyType.severeHypoxemia,
            record: record,
            readingSummary: summary,
          );
        }
      }
      return null;
    }

    // 6. Heart Rate (Resting vs Active)
    final isResting = _isRestingHeartRate(lowerName, code);
    final isHeartRate = isResting || _isHeartRate(lowerName, code);

    if (isHeartRate) {
      final val = parseHealthRecordValue(record.value);
      if (val != null && val > 0) {
        // Clinically, heart rate is measured and evaluated in discrete integer beats
        // per minute (bpm). Wearables often report mathematical averages with fractional
        // decimals (e.g., 39.68 bpm from nocturnal sleep tracking, which rounds to 40 bpm).
        // Rounding to nearest integer bpm prevents fractional averaging noise from falsely breaching thresholds.
        final hrBpm = val.round();
        // High heart rate (> 140 bpm) is a critical threshold strictly for resting heart rate.
        // Continuous/active heart rate (type HEART_RATE) during exercise or physical activity
        // normally exceeds 140 bpm and must not be mis-classified as resting heart rate.
        final isCriticalHigh = isResting && hrBpm > kHeartRateCriticalHigh;
        // Severe bradycardia indicates profound hypoperfusion risk.
        final isCriticalLow = hrBpm < heartRateCriticalLow;

        if (isCriticalHigh || isCriticalLow) {
          final customGuidance =
              heartRateCriticalLow != kHeartRateCriticalLowDefault
              ? 'A resting heart rate below ${heartRateCriticalLow.round()} bpm or above 140 bpm requires urgent medical evaluation. If accompanied by chest discomfort, dizziness, shortness of breath, or lightheadedness, call emergency services (such as 911 or 112) immediately.'
              : null;
          return CriticalSafetyAlert(
            type: CriticalSafetyType.severeArrhythmia,
            record: record,
            readingSummary: record.displayValue,
            customEmergencyGuidance: customGuidance,
          );
        }
      }
      return null;
    }

    return null;
  }

  /// Scans [records], automatically pairing systolic and diastolic blood pressure
  /// records matching timestamp and source, and returns all active critical alerts
  /// sorted newest first.
  /// [heartRateCriticalLow] sets the critical resting bradycardia threshold (defaults to [kHeartRateCriticalLowDefault]).
  static List<CriticalSafetyAlert> evaluateAll(
    List<HealthRecord> records, {
    double heartRateCriticalLow = kHeartRateCriticalLowDefault,
  }) {
    if (records.isEmpty) return const [];

    final alerts = <CriticalSafetyAlert>[];
    final pairedIds = <String>{};

    // First map BP pairs by source + timestamp
    final bpBySourceTime = <String, Map<String, HealthRecord>>{};
    for (final r in records) {
      if (r.category != RecordCategory.vital) continue;
      final lower = r.name.toLowerCase();
      final code = r.code?.trim();
      final key = '${r.source}_${r.recordedAt.millisecondsSinceEpoch}';

      if (_isSystolic(lower, code)) {
        bpBySourceTime.putIfAbsent(key, () => {})['sys'] = r;
      } else if (_isDiastolic(lower, code)) {
        bpBySourceTime.putIfAbsent(key, () => {})['dia'] = r;
      }
    }

    for (final record in records) {
      if (pairedIds.contains(record.id)) continue;

      final lower = record.name.toLowerCase();
      final code = record.code?.trim();

      if (_isSystolic(lower, code) || _isDiastolic(lower, code)) {
        final key =
            '${record.source}_${record.recordedAt.millisecondsSinceEpoch}';
        final pair = bpBySourceTime[key];
        final sys = pair?['sys'];
        final dia = pair?['dia'];

        if (sys != null && dia != null) {
          pairedIds.add(sys.id);
          pairedIds.add(dia.id);
          final alert = evaluate(
            sys,
            pairedRecord: dia,
            heartRateCriticalLow: heartRateCriticalLow,
          );
          if (alert != null) {
            alerts.add(alert);
          }
          continue;
        }
      }

      final alert = evaluate(
        record,
        heartRateCriticalLow: heartRateCriticalLow,
      );
      if (alert != null) {
        alerts.add(alert);
      }
    }

    alerts.sort((a, b) => b.record.recordedAt.compareTo(a.record.recordedAt));
    return alerts;
  }

  static bool _isSystolic(String name, String? code) {
    if (code == '8480-6') return true;
    return name.contains('systolic');
  }

  static bool _isDiastolic(String name, String? code) {
    if (code == '8462-4') return true;
    return name.contains('diastolic');
  }

  static bool _isCombinedBp(String name, String? code) {
    if (code == '85354-9' || code == '55284-4') return true;
    return name == 'blood pressure' || name.startsWith('blood pressure');
  }

  static bool _isGlucose(String name, String? code) {
    if (code == '2345-7' ||
        code == '2339-0' ||
        code == '15074-8' ||
        code == '41653-7' ||
        code == '14749-6') {
      return true;
    }
    return name.contains('glucose') || name.contains('blood sugar');
  }

  static bool _isOxygen(String name, String? code) {
    final lowerCode = code?.toLowerCase();
    if (code == '59408-5' ||
        code == '2708-6' ||
        code == '2710-2' ||
        lowerCode == 'blood_oxygen') {
      return true;
    }
    return name.contains('spo2') ||
        name.contains('oxygen') ||
        name.contains('oximetry');
  }

  static bool _isRestingHeartRate(String name, String? code) {
    final lowerCode = code?.toLowerCase();
    if (lowerCode == 'resting_heart_rate' || code == '40443-4') {
      return true;
    }
    if (lowerCode == 'heart_rate' || lowerCode == '8867-4') {
      return false;
    }
    return name.contains('resting heart rate') ||
        name.contains('resting pulse') ||
        name.contains('resting hr') ||
        name.startsWith('resting');
  }

  static bool _isHeartRate(String name, String? code) {
    final lowerCode = code?.toLowerCase();
    if (lowerCode == 'heart_rate' ||
        lowerCode == 'resting_heart_rate' ||
        code == '8867-4' ||
        code == '40443-4') {
      return true;
    }
    return name.contains('heart rate') || name.contains('pulse');
  }
}
