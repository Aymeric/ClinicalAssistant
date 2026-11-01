import 'package:flutter/material.dart';

import '../trends/health_trend.dart';
import 'clinical_panel.dart';
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

  String get shortLabel => switch (this) {
    DoctorVisitSpecialty.annualWellness => 'Annual Wellness',
    DoctorVisitSpecialty.cardiology => 'Cardiology',
    DoctorVisitSpecialty.endocrinology => 'Endocrinology',
  };

  /// Returns whether a health observation belongs to this clinical specialty domain.
  bool matchesRecord(HealthRecord record) {
    switch (this) {
      case DoctorVisitSpecialty.cardiology:
        return _matchesCardiology(record);
      case DoctorVisitSpecialty.endocrinology:
        return _matchesEndocrinology(record);
      case DoctorVisitSpecialty.annualWellness:
        return _matchesAnnualWellness(record);
    }
  }

  /// Returns whether a numeric trend series matches this clinical specialty domain.
  bool matchesTrendSeries(HealthTrendSeries series) {
    if (series.points.isEmpty) return false;
    return matchesRecord(series.points.first.record);
  }
}

bool _matchesCardiology(HealthRecord record) {
  final name = record.name.toLowerCase();
  final code = record.code?.toLowerCase().trim() ?? '';
  final panel = extractRecordPanelInfo(record)?.name.toLowerCase() ?? '';

  // Vitals
  if (record.category == RecordCategory.vital) {
    return name.contains('blood pressure') ||
        name.contains('systolic') ||
        name.contains('diastolic') ||
        name.contains('bp') ||
        name.contains('heart rate') ||
        name.contains('pulse') ||
        name.contains('oxygen') ||
        name.contains('spo2') ||
        name.contains('weight') ||
        name.contains('bmi') ||
        const {
          '85354-9',
          '8480-6',
          '8462-4',
          '55284-4',
          '8867-4',
          '59408-5',
          '2708-6',
          '29463-7',
          '39156-5',
          'BLOOD_OXYGEN',
        }.contains(code);
  }

  // Labs
  if (record.category == RecordCategory.lab) {
    if (panel.contains('lipid') || code == '24331-1') return true;
    return name.contains('cholesterol') ||
        name.contains('ldl') ||
        name.contains('hdl') ||
        name.contains('triglyceride') ||
        name.contains('lipid') ||
        name.contains('vldl') ||
        name.contains('apob') ||
        name.contains('apolipoprotein') ||
        name.contains('troponin') ||
        name.contains('bnp') ||
        name.contains('crp') ||
        name.contains('ck-mb') ||
        name.contains('potassium') ||
        name.contains('magnesium') ||
        name.contains('sodium');
  }

  // Medications
  if (record.category == RecordCategory.medication) {
    const cardiacMeds = [
      'lisinopril',
      'losartan',
      'amlodipine',
      'metoprolol',
      'carvedilol',
      'atenolol',
      'propranolol',
      'hydrochlorothiazide',
      'hctz',
      'furosemide',
      'lasix',
      'spironolactone',
      'valsartan',
      'olmesartan',
      'diltiazem',
      'verapamil',
      'clonidine',
      'hydralazine',
      'atorvastatin',
      'rosuvastatin',
      'simvastatin',
      'pravastatin',
      'ezetimibe',
      'fenofibrate',
      'aspirin',
      'clopidogrel',
      'plavix',
      'warfarin',
      'coumadin',
      'eliquis',
      'apixaban',
      'xarelto',
      'rivaroxaban',
      'brilinta',
      'ticagrelor',
      'nitroglycerin',
      'amiodarone',
      'digoxin',
      'isosorbide',
    ];
    return cardiacMeds.any((med) => name.contains(med));
  }

  // Conditions
  if (record.category == RecordCategory.condition) {
    const cardiacConditions = [
      'hypertension',
      'blood pressure',
      'htn',
      'hyperlipidemia',
      'cholesterol',
      'dyslipidemia',
      'coronary',
      'cad',
      'heart failure',
      'chf',
      'atrial fib',
      'afib',
      'a-fib',
      'arrhythmia',
      'myocardial',
      'angina',
      'atherosclerosis',
      'tachycardia',
      'bradycardia',
      'cardiomyopathy',
    ];
    return cardiacConditions.any((cond) => name.contains(cond));
  }

  return false;
}

bool _matchesEndocrinology(HealthRecord record) {
  final name = record.name.toLowerCase();
  final code = record.code?.toLowerCase().trim() ?? '';
  final panel = extractRecordPanelInfo(record)?.name.toLowerCase() ?? '';

  // Vitals
  if (record.category == RecordCategory.vital) {
    return name.contains('glucose') ||
        name.contains('blood sugar') ||
        name.contains('weight') ||
        name.contains('bmi') ||
        name.contains('blood pressure') ||
        name.contains('systolic') ||
        name.contains('diastolic') ||
        const {
          '2339-0',
          '2345-7',
          '15074-8',
          '29463-7',
          '39156-5',
        }.contains(code);
  }

  // Labs
  if (record.category == RecordCategory.lab) {
    if (panel.contains('metabolic') ||
        panel.contains('bmp') ||
        panel.contains('cmp') ||
        panel.contains('thyroid') ||
        code == '24321-2' ||
        code == '24323-8') {
      return true;
    }
    return name.contains('glucose') ||
        name.contains('sugar') ||
        name.contains('hba1c') ||
        name.contains('a1c') ||
        name.contains('insulin') ||
        name.contains('c-peptide') ||
        name.contains('fructosamine') ||
        name.contains('ketone') ||
        name.contains('tsh') ||
        name.contains('thyroid') ||
        name.contains('free t4') ||
        name.contains('free t3') ||
        name.contains('tpo') ||
        name.contains('creatinine') ||
        name.contains('egfr') ||
        name.contains('bun') ||
        name.contains('urea') ||
        name.contains('albumin') ||
        name.contains('uacr') ||
        name.contains('calcium') ||
        name.contains('vitamin d') ||
        name.contains('cortisol') ||
        name.contains('acth') ||
        name.contains('testosterone') ||
        name.contains('estrogen') ||
        name.contains('prolactin');
  }

  // Medications
  if (record.category == RecordCategory.medication) {
    const endoMeds = [
      'insulin',
      'metformin',
      'glipizide',
      'glimepiride',
      'glyburide',
      'januvia',
      'sitagliptin',
      'jardiance',
      'empagliflozin',
      'farxiga',
      'dapagliflozin',
      'ozempic',
      'semaglutide',
      'mounjaro',
      'tirzepatide',
      'victoza',
      'liraglutide',
      'trulicity',
      'dulaglutide',
      'pioglitazone',
      'levothyroxine',
      'synthroid',
      'armour',
      'liothyronine',
      'methimazole',
      'hydrocortisone',
      'prednisone',
      'fludrocortisone',
      'testosterone',
      'estrogen',
      'estradiol',
      'progesterone',
    ];
    return endoMeds.any((med) => name.contains(med));
  }

  // Conditions
  if (record.category == RecordCategory.condition) {
    const endoConditions = [
      'diabetes',
      't1d',
      't2d',
      'prediabetes',
      'hyperglycemia',
      'hypoglycemia',
      'hypothyroid',
      'hyperthyroid',
      'hashimoto',
      'graves',
      'goiter',
      'thyroid',
      'metabolic syndrome',
      'pcos',
      'polycystic',
      'osteoporosis',
      'osteopenia',
      'cushing',
      'addison',
      'adrenal',
      'pituitary',
      'vitamin d',
    ];
    return endoConditions.any((cond) => name.contains(cond));
  }

  return false;
}

bool _matchesAnnualWellness(HealthRecord record) {
  if (record.category == RecordCategory.vital) return true;
  if (record.category == RecordCategory.immunization) return true;
  if (record.category == RecordCategory.condition) return true;
  if (record.category == RecordCategory.allergy) return true;

  if (record.category == RecordCategory.lab) {
    final name = record.name.toLowerCase();
    final panel = extractRecordPanelInfo(record)?.name.toLowerCase() ?? '';
    return panel.isNotEmpty ||
        name.contains('cbc') ||
        name.contains('blood count') ||
        name.contains('metabolic') ||
        name.contains('lipid') ||
        name.contains('cholesterol') ||
        name.contains('glucose') ||
        name.contains('creatinine') ||
        name.contains('tsh') ||
        name.contains('vitamin d') ||
        name.contains('urinalysis') ||
        name.contains('hemoglobin') ||
        name.contains('hematocrit') ||
        name.contains('white blood') ||
        name.contains('platelet') ||
        name.contains('psa');
  }

  if (record.category == RecordCategory.medication) return true;

  return true;
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
  }) : visitDate = visitDate ?? DateTime.now(),
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
      if ((nameLower.contains('systolic') ||
              nameLower.contains('blood pressure')) &&
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
          (r.category == RecordCategory.vital ||
              r.category == RecordCategory.lab)) {
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
    final hasMedications = records.any(
      (r) => r.category == RecordCategory.medication,
    );
    if (hasMedications) {
      addSuggestion(
        'medication_review',
        'Review current prescription dosages, potential side effects, and refill needs.',
      );
    }

    return suggestions;
  }
}
