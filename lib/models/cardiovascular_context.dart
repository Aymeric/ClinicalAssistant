import 'package:flutter/material.dart';

import 'health_record.dart';

/// Descriptive clinical staging for blood pressure according to the 2017
/// ACC/AHA High Blood Pressure Clinical Practice Guidelines.
///
/// NOTE: Provided as descriptive observational context only and does not
/// constitute algorithmic medical diagnosis or automated clinical triage.
enum BloodPressureStaging {
  normal(
    label: 'Normal',
    description: 'Systolic < 120 mmHg and diastolic < 80 mmHg',
    shortGuidance: 'Within standard normal parameters',
    color: Color(0xFF2E7D32), // Green
  ),
  elevated(
    label: 'Elevated',
    description: 'Systolic 120–129 mmHg and diastolic < 80 mmHg',
    shortGuidance: 'Lifestyle modifications recommended',
    color: Color(0xFFF57F17), // Amber
  ),
  stage1(
    label: 'Stage 1 Hypertension',
    description: 'Systolic 130–139 mmHg or diastolic 80–89 mmHg',
    shortGuidance: 'Discuss with your healthcare provider',
    color: Color(0xFFE65100), // Dark Amber / Orange
  ),
  stage2(
    label: 'Stage 2 Hypertension',
    description: 'Systolic 140–179 mmHg or diastolic 90–119 mmHg',
    shortGuidance: 'Clinical evaluation and management recommended',
    color: Color(0xFFC62828), // Red
  ),
  hypertensiveCrisis(
    label: 'Hypertensive Crisis Range',
    description: 'Systolic ≥ 180 mmHg and/or diastolic ≥ 120 mmHg',
    shortGuidance:
        'Prompt medical attention required if sustained or symptomatic',
    color: Color(0xFF880E4F), // Deep Maroon / Magenta
  );

  const BloodPressureStaging({
    required this.label,
    required this.description,
    required this.shortGuidance,
    required this.color,
  });

  final String label;
  final String description;
  final String shortGuidance;
  final Color color;

  /// Classifies a paired systolic and diastolic reading according to 2017 ACC/AHA guidelines.
  static BloodPressureStaging classify({
    required double systolic,
    required double diastolic,
  }) {
    if (systolic >= 180 || diastolic >= 120) {
      return BloodPressureStaging.hypertensiveCrisis;
    }
    if (systolic >= 140 || diastolic >= 90) {
      return BloodPressureStaging.stage2;
    }
    if (systolic >= 130 || diastolic >= 80) {
      return BloodPressureStaging.stage1;
    }
    if (systolic >= 120 && diastolic < 80) {
      return BloodPressureStaging.elevated;
    }
    return BloodPressureStaging.normal;
  }
}

/// Physical measurement posture during blood pressure assessment.
enum BloodPressurePosture {
  sitting('Sitting'),
  standing('Standing'),
  supine('Supine / Lying down');

  const BloodPressurePosture(this.label);
  final String label;

  static BloodPressurePosture? fromString(String? val) {
    if (val == null) return null;
    return BloodPressurePosture.values.cast<BloodPressurePosture?>().firstWhere(
      (p) =>
          p?.name.toLowerCase() == val.toLowerCase() ||
          p?.label.toLowerCase() == val.toLowerCase(),
      orElse: () => null,
    );
  }
}

/// Arm used for blood pressure measurement.
enum BloodPressureArm {
  left('Left arm'),
  right('Right arm');

  const BloodPressureArm(this.label);
  final String label;

  static BloodPressureArm? fromString(String? val) {
    if (val == null) return null;
    return BloodPressureArm.values.cast<BloodPressureArm?>().firstWhere(
      (a) =>
          a?.name.toLowerCase() == val.toLowerCase() ||
          a?.label.toLowerCase() == val.toLowerCase(),
      orElse: () => null,
    );
  }
}

/// Sphygmomanometer cuff size used during measurement.
enum BloodPressureCuff {
  regularAdult('Adult Regular (27–34 cm)'),
  largeAdult('Adult Large (35–44 cm)'),
  smallAdult('Adult Small (22–26 cm)'),
  thigh('Thigh / Extra Large (45–52 cm)'),
  wrist('Wrist monitor');

  const BloodPressureCuff(this.label);
  final String label;

  static BloodPressureCuff? fromString(String? val) {
    if (val == null) return null;
    return BloodPressureCuff.values.cast<BloodPressureCuff?>().firstWhere(
      (c) =>
          c?.name.toLowerCase() == val.toLowerCase() ||
          c?.label.toLowerCase() == val.toLowerCase(),
      orElse: () => null,
    );
  }
}

/// Diurnal classification for blood pressure readings based on local time.
enum BloodPressureDiurnalPeriod {
  morning('Morning (06:00 – 11:59)'),
  midday('Midday (12:00 – 17:59)'),
  evening('Evening (18:00 – 23:59)'),
  nocturnal('Night / Early Morning (00:00 – 05:59)');

  const BloodPressureDiurnalPeriod(this.label);
  final String label;

  static BloodPressureDiurnalPeriod fromDateTime(DateTime localDateTime) {
    final hour = localDateTime.hour;
    if (hour >= 6 && hour < 12) {
      return BloodPressureDiurnalPeriod.morning;
    } else if (hour >= 12 && hour < 18) {
      return BloodPressureDiurnalPeriod.midday;
    } else if (hour >= 18 && hour <= 23) {
      return BloodPressureDiurnalPeriod.evening;
    } else {
      return BloodPressureDiurnalPeriod.nocturnal;
    }
  }
}

/// Comprehensive contextual metadata accompanying a blood pressure reading.
class BloodPressureContext {
  const BloodPressureContext({
    this.posture,
    this.arm,
    this.cuff,
    this.restingMinutes,
  });

  static const sourceDataKey = 'bloodPressureContext';

  final BloodPressurePosture? posture;
  final BloodPressureArm? arm;
  final BloodPressureCuff? cuff;
  final int? restingMinutes;

  Map<String, Object?> toJson() => {
    if (posture != null) 'posture': posture!.name,
    if (arm != null) 'arm': arm!.name,
    if (cuff != null) 'cuff': cuff!.name,
    if (restingMinutes != null) 'restingMinutes': restingMinutes,
  };

  factory BloodPressureContext.fromJson(Map<String, Object?> json) {
    return BloodPressureContext(
      posture: BloodPressurePosture.fromString(json['posture']?.toString()),
      arm: BloodPressureArm.fromString(json['arm']?.toString()),
      cuff: BloodPressureCuff.fromString(json['cuff']?.toString()),
      restingMinutes:
          json['restingMinutes'] as int? ??
          int.tryParse(json['restingMinutes']?.toString() ?? ''),
    );
  }

  static BloodPressureContext? fromRecord(HealthRecord record) {
    final raw = record.sourceData?[sourceDataKey];
    if (raw is Map) {
      return BloodPressureContext.fromJson(Map<String, Object?>.from(raw));
    }
    // Also parse from notes if structured tags exist
    if (record.notes != null && record.notes!.isNotEmpty) {
      return fromNotes(record.notes!);
    }
    return null;
  }

  static BloodPressureContext? fromNotes(String notes) {
    BloodPressurePosture? posture;
    BloodPressureArm? arm;
    BloodPressureCuff? cuff;
    int? resting;

    final parts = notes.split('·').map((p) => p.trim());
    for (final part in parts) {
      if (part.toLowerCase().startsWith('posture:')) {
        posture = BloodPressurePosture.fromString(part.substring(8).trim());
      } else if (part.toLowerCase().startsWith('arm:')) {
        arm = BloodPressureArm.fromString(part.substring(4).trim());
      } else if (part.toLowerCase().startsWith('cuff:')) {
        cuff = BloodPressureCuff.fromString(part.substring(5).trim());
      } else if (part.toLowerCase().startsWith('rest:')) {
        final restDigits = RegExp(r'\d+').firstMatch(part);
        if (restDigits != null) {
          resting = int.tryParse(restDigits.group(0)!);
        }
      }
    }

    if (posture != null || arm != null || cuff != null || resting != null) {
      return BloodPressureContext(
        posture: posture,
        arm: arm,
        cuff: cuff,
        restingMinutes: resting,
      );
    }
    return null;
  }

  Map<String, Object?> withSourceData(
    Map<String, Object?>? existingSourceData,
  ) {
    return {...?existingSourceData, sourceDataKey: toJson()};
  }

  String formatSummary() {
    final items = <String>[];
    if (posture != null) items.add('Posture: ${posture!.label}');
    if (arm != null) items.add('Arm: ${arm!.label}');
    if (cuff != null) items.add('Cuff: ${cuff!.label}');
    if (restingMinutes != null) items.add('Rested: ${restingMinutes}m');
    return items.join(' · ');
  }
}
