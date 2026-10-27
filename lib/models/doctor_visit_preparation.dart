import 'package:flutter/material.dart';

import 'health_record.dart';

/// Available specialty templates for clinical consultation preparation.
enum DoctorVisitSpecialty {
  annualWellness(
    id: 'annual_wellness',
    title: 'Annual Wellness & General',
    subtitle:
        'Comprehensive checkup covering overall health, preventive care, vitals, and general labs.',
    icon: Icons.health_and_safety_outlined,
  ),
  cardiology(
    id: 'cardiology',
    title: 'Cardiology Consultation',
    subtitle:
        'Focused on blood pressure control, heart rate/rhythm, lipid panels, and cardiac medications.',
    icon: Icons.favorite_outline,
  ),
  endocrinology(
    id: 'endocrinology',
    title: 'Endocrinology & Diabetes',
    subtitle:
        'Focused on glycemic control (fasting/post-meal glucose, HbA1c), metabolic labs, and endocrine regimens.',
    icon: Icons.water_drop_outlined,
  );

  const DoctorVisitSpecialty({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
}

/// Holds all patient-configured selections and notes for an upcoming doctor visit.
class DoctorVisitPreparationConfig {
  DoctorVisitPreparationConfig({
    this.specialty = DoctorVisitSpecialty.annualWellness,
    DateTime? visitDate,
    this.clinicianName,
    this.facilityName,
    Set<String>? selectedRecordIds,
    Map<String, String>? medicationNotes,
    List<String>? agendaItems,
    this.dateRange,
    this.includeVitals = true,
    this.includeLabs = true,
    this.includeMedications = true,
    this.includeConditions = true,
    this.includeAllergies = true,
  })  : visitDate = visitDate ?? DateTime.now(),
        selectedRecordIds = selectedRecordIds ?? <String>{},
        medicationNotes = medicationNotes ?? <String, String>{},
        agendaItems = agendaItems ?? <String>[];

  final DoctorVisitSpecialty specialty;
  final DateTime visitDate;
  final String? clinicianName;
  final String? facilityName;
  final Set<String> selectedRecordIds;
  final Map<String, String> medicationNotes;
  final List<String> agendaItems;
  final DateTimeRange? dateRange;
  final bool includeVitals;
  final bool includeLabs;
  final bool includeMedications;
  final bool includeConditions;
  final bool includeAllergies;

  /// Creates a copy of this configuration with updated fields.
  DoctorVisitPreparationConfig copyWith({
    DoctorVisitSpecialty? specialty,
    DateTime? visitDate,
    String? clinicianName,
    String? facilityName,
    Set<String>? selectedRecordIds,
    Map<String, String>? medicationNotes,
    List<String>? agendaItems,
    DateTimeRange? dateRange,
    bool? includeVitals,
    bool? includeLabs,
    bool? includeMedications,
    bool? includeConditions,
    bool? includeAllergies,
  }) {
    return DoctorVisitPreparationConfig(
      specialty: specialty ?? this.specialty,
      visitDate: visitDate ?? this.visitDate,
      clinicianName: clinicianName ?? this.clinicianName,
      facilityName: facilityName ?? this.facilityName,
      selectedRecordIds: selectedRecordIds != null
          ? Set<String>.from(selectedRecordIds)
          : Set<String>.from(this.selectedRecordIds),
      medicationNotes: medicationNotes != null
          ? Map<String, String>.from(medicationNotes)
          : Map<String, String>.from(this.medicationNotes),
      agendaItems: agendaItems != null
          ? List<String>.from(agendaItems)
          : List<String>.from(this.agendaItems),
      dateRange: dateRange ?? this.dateRange,
      includeVitals: includeVitals ?? this.includeVitals,
      includeLabs: includeLabs ?? this.includeLabs,
      includeMedications: includeMedications ?? this.includeMedications,
      includeConditions: includeConditions ?? this.includeConditions,
      includeAllergies: includeAllergies ?? this.includeAllergies,
    );
  }

  /// Generates helpful, evidence-informed agenda discussion suggestions
  /// based on out-of-range observations, critical alerts, and selected specialty.
  static List<String> generateSmartSuggestions({
    required List<HealthRecord> records,
    required DoctorVisitSpecialty specialty,
  }) {
    final suggestions = <String>[];
    final seenTopics = <String>{};

    void addSuggestion(String key, String text) {
      if (seenTopics.add(key)) {
        suggestions.add(text);
      }
    }

    // 1. Specialty-specific default agenda items
    switch (specialty) {
      case DoctorVisitSpecialty.cardiology:
        addSuggestion(
          'bp_review',
          'Review recent home blood pressure averages and discuss current target goals.',
        );
        addSuggestion(
          'cardio_symptoms',
          'Discuss any episodes of chest discomfort, shortness of breath, or palpitations.',
        );
        break;
      case DoctorVisitSpecialty.endocrinology:
        addSuggestion(
          'glycemic_goals',
          'Review fasting vs. post-meal glucose logs and discuss current HbA1c targets.',
        );
        addSuggestion(
          'hypo_episodes',
          'Report any symptoms of low blood sugar (dizziness, shakiness, sweating) and treatment steps.',
        );
        break;
      case DoctorVisitSpecialty.annualWellness:
        addSuggestion(
          'preventive_screenings',
          'Review recommended age- and risk-appropriate preventive screenings and immunizations.',
        );
        break;
    }

    // 2. Scan records for out-of-range labs
    for (final r in records) {
      if (r.category == RecordCategory.lab &&
          r.referenceRange != null &&
          r.referenceRange!.isNotEmpty) {
        final range = HealthReferenceRange.tryParse(r.referenceRange);
        final numVal = parseHealthRecordValue(r.value);
        if (range != null && numVal != null) {
          final status = range.evaluate(numVal);
          if (status == HealthReferenceStatus.above) {
            addSuggestion(
              'lab_above_${r.name.toLowerCase()}',
              'Review elevated ${r.name} (${r.displayValue}, target ${r.referenceRange}).',
            );
          } else if (status == HealthReferenceStatus.below) {
            addSuggestion(
              'lab_below_${r.name.toLowerCase()}',
              'Review low ${r.name} (${r.displayValue}, target ${r.referenceRange}).',
            );
          }
        }
      }

      // Check for elevated blood pressure vitals
      final nameLower = r.name.toLowerCase();
      if ((nameLower.contains('systolic') || nameLower.contains('blood pressure')) &&
          r.category == RecordCategory.vital) {
        final val = parseHealthRecordValue(r.value);
        if (val != null && val >= 140) {
          addSuggestion(
            'bp_elevated',
            'Discuss blood pressure readings exceeding 140 mmHg (${r.displayValue}).',
          );
        }
      }

      // Check for elevated blood glucose
      if (nameLower.contains('glucose') &&
          (r.category == RecordCategory.vital || r.category == RecordCategory.lab)) {
        final val = parseHealthRecordValue(r.value);
        if (val != null && val >= 180) {
          addSuggestion(
            'glucose_elevated',
            'Discuss elevated glucose readings above 180 mg/dL (${r.displayValue}).',
          );
        }
      }
    }

    // 3. General medication discussion suggestion if medications exist
    final hasMedications = records.any((r) => r.category == RecordCategory.medication);
    if (hasMedications) {
      addSuggestion(
        'medication_review',
        'Review current prescription dosages, potential side effects, and refill needs.',
      );
    }

    return suggestions;
  }
}
