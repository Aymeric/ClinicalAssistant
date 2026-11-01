import 'package:flutter/material.dart';

import '../models/health_record.dart';

/// Standard severity levels for clinical symptoms.
enum SymptomSeverity {
  mild('Mild', 1, Color(0xFF00796B)),
  moderate('Moderate', 2, Color(0xFFD97706)),
  severe('Severe', 3, Color(0xFFDC2626));

  const SymptomSeverity(this.label, this.level, this.color);
  final String label;
  final int level;
  final Color color;

  static SymptomSeverity fromString(String? raw) {
    if (raw == null) return SymptomSeverity.moderate;
    final clean = raw.toLowerCase().trim();
    if (clean.contains('mild') || clean == '1') return SymptomSeverity.mild;
    if (clean.contains('severe') || clean == '3') return SymptomSeverity.severe;
    return SymptomSeverity.moderate;
  }
}

/// Standard anatomical or physiologic symptom system categories.
enum SymptomCategory {
  cardiorespiratory('Cardiorespiratory', Icons.air),
  neurological('Neurological', Icons.psychology),
  gastrointestinal('Gastrointestinal', Icons.fastfood_outlined),
  pain('Pain & Musculoskeletal', Icons.healing),
  general('General & Systemic', Icons.sentiment_dissatisfied);

  const SymptomCategory(this.label, this.icon);
  final String label;
  final IconData icon;

  static SymptomCategory fromString(String? raw) {
    if (raw == null) return SymptomCategory.general;
    final clean = raw.toLowerCase().trim();
    if (clean.contains('cardio') || clean.contains('respir')) {
      return SymptomCategory.cardiorespiratory;
    }
    if (clean.contains('neuro') || clean.contains('head')) {
      return SymptomCategory.neurological;
    }
    if (clean.contains('gastro') ||
        clean.contains('stomach') ||
        clean.contains('digest')) {
      return SymptomCategory.gastrointestinal;
    }
    if (clean.contains('pain') ||
        clean.contains('muscle') ||
        clean.contains('joint')) {
      return SymptomCategory.pain;
    }
    return SymptomCategory.general;
  }
}

/// Structured details for a patient-reported or platform-ingested symptom record.
class SymptomDetails {
  const SymptomDetails({
    required this.name,
    required this.severity,
    this.category = SymptomCategory.general,
    this.notes,
  });

  static const sourceDataKey = 'symptomDetails';

  final String name;
  final SymptomSeverity severity;
  final SymptomCategory category;
  final String? notes;

  Map<String, Object?> toJson() => {
    'name': name,
    'severity': severity.name,
    'category': category.name,
    if (notes != null && notes!.isNotEmpty) 'notes': notes,
  };

  factory SymptomDetails.fromRecord(HealthRecord record) {
    final raw = record.sourceData?[sourceDataKey];
    if (raw is Map) {
      return SymptomDetails(
        name: raw['name']?.toString() ?? record.name,
        severity: SymptomSeverity.fromString(
          raw['severity']?.toString() ?? record.value,
        ),
        category: SymptomCategory.fromString(raw['category']?.toString()),
        notes: raw['notes']?.toString() ?? record.notes,
      );
    }

    return SymptomDetails(
      name: record.name,
      severity: SymptomSeverity.fromString(record.value),
      category: SymptomCategory.fromString(record.name),
      notes: record.notes,
    );
  }

  Map<String, Object?> withSourceData(Map<String, Object?>? sourceData) => {
    ...?sourceData,
    sourceDataKey: toJson(),
  };
}

/// A symptom event positioned within a trend chart's time window.
class SymptomChartEvent {
  const SymptomChartEvent({
    required this.record,
    required this.date,
    required this.name,
    required this.severity,
    this.notes,
  });

  final HealthRecord record;
  final DateTime date;
  final String name;
  final SymptomSeverity severity;
  final String? notes;

  /// Extracts chronological symptom records within the inclusive range `[start, end]`.
  static List<SymptomChartEvent> extractEvents(
    List<HealthRecord> records, {
    required DateTime start,
    required DateTime end,
  }) {
    final events = <SymptomChartEvent>[];
    final startMs = start.millisecondsSinceEpoch;
    final endMs = end.millisecondsSinceEpoch;

    for (final record in records) {
      if (record.category != RecordCategory.symptom) continue;

      final recordedMs = record.recordedAt.millisecondsSinceEpoch;
      if (recordedMs >= startMs && recordedMs <= endMs) {
        final details = SymptomDetails.fromRecord(record);
        events.add(
          SymptomChartEvent(
            record: record,
            date: record.recordedAt,
            name: details.name,
            severity: details.severity,
            notes: details.notes,
          ),
        );
      }
    }

    events.sort((a, b) => a.date.compareTo(b.date));
    return events;
  }
}
