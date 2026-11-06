import '../models/health_record.dart';
import 'clinical_unit_converter.dart';

/// Represents a standardized offline LOINC concept entry with clear
/// patient-facing nomenclature, clinical descriptions, and unit conversion metadata.
class LoincConcept {
  const LoincConcept({
    required this.code,
    required this.patientFriendlyName,
    required this.formalName,
    required this.category,
    required this.description,
    required this.standardUcumUnit,
    this.alternateCodes = const [],
    this.equivalentUnits = const [],
  });

  /// Standard LOINC identifier (e.g. '2345-7').
  final String code;

  /// Clear, approachable test name for patients (e.g. 'Fasting Blood Glucose').
  final String patientFriendlyName;

  /// Formal LOINC component name (e.g. 'Glucose [Mass/volume] in Serum or Plasma').
  final String formalName;

  /// High-level clinical category (e.g. 'Metabolic', 'Lipids', 'Renal', 'Hematology').
  final String category;

  /// Plain-language clinical explanation of what this test measures and why it is tracked.
  final String description;

  /// Canonical UCUM unit for this test (e.g. 'mg/dL' or 'mmol/L').
  final String standardUcumUnit;

  /// Alternative or related LOINC codes representing equivalent measurements.
  final List<String> alternateCodes;

  /// Equivalent supported units for descriptive conversion (e.g. ['mmol/L', 'mg/dL']).
  final List<String> equivalentUnits;
}

/// Offline dictionary providing patient-friendly terminology mapping,
/// clinical explanations, and descriptive UCUM unit conversions for common laboratory analytes.
class LoincDictionary {
  const LoincDictionary._();

  static const List<LoincConcept> concepts = [
    // --- Glycemic & Metabolic ---
    LoincConcept(
      code: '2345-7',
      patientFriendlyName: 'Blood Glucose',
      formalName: 'Glucose [Mass/volume] in Serum or Plasma',
      category: 'Metabolic',
      description:
          'Measures the concentration of sugar (glucose) in your blood, providing a key indicator of energy balance and diabetes management.',
      standardUcumUnit: 'mg/dL',
      alternateCodes: ['2339-0', '15074-8', '41653-7', '14749-6'],
      equivalentUnits: ['mg/dL', 'mmol/L'],
    ),
    LoincConcept(
      code: '4548-4',
      patientFriendlyName: 'Hemoglobin A1c',
      formalName: 'Hemoglobin A1c/Hemoglobin.total in Blood',
      category: 'Metabolic',
      description:
          'Reflects your average blood sugar level over the past 2 to 3 months by measuring the percentage of hemoglobin coated with sugar.',
      standardUcumUnit: '%',
      alternateCodes: ['17856-6', '4544-3'],
      equivalentUnits: ['%', 'mmol/mol'],
    ),

    // --- Lipids ---
    LoincConcept(
      code: '2093-3',
      patientFriendlyName: 'Total Cholesterol',
      formalName: 'Cholesterol [Mass/volume] in Serum or Plasma',
      category: 'Lipids',
      description:
          'Measures the total amount of cholesterol in your blood, including both HDL (good) and LDL (bad) cholesterol.',
      standardUcumUnit: 'mg/dL',
      alternateCodes: ['35200-5'],
      equivalentUnits: ['mg/dL', 'mmol/L'],
    ),
    LoincConcept(
      code: '2085-9',
      patientFriendlyName: 'HDL "Good" Cholesterol',
      formalName: 'Cholesterol in HDL [Mass/volume] in Serum or Plasma',
      category: 'Lipids',
      description:
          'High-Density Lipoprotein helps remove other forms of cholesterol from your bloodstream and is associated with cardiovascular protection.',
      standardUcumUnit: 'mg/dL',
      alternateCodes: ['14646-4'],
      equivalentUnits: ['mg/dL', 'mmol/L'],
    ),
    LoincConcept(
      code: '13457-7',
      patientFriendlyName: 'LDL "Bad" Cholesterol',
      formalName:
          'Cholesterol in LDL [Mass/volume] in Serum or Plasma by calculation',
      category: 'Lipids',
      description:
          'Low-Density Lipoprotein contributes to fatty buildups in arteries (atherosclerosis) when levels remain elevated.',
      standardUcumUnit: 'mg/dL',
      alternateCodes: ['18262-6', '2089-1'],
      equivalentUnits: ['mg/dL', 'mmol/L'],
    ),
    LoincConcept(
      code: '2571-8',
      patientFriendlyName: 'Triglycerides',
      formalName: 'Triglyceride [Mass/volume] in Serum or Plasma',
      category: 'Lipids',
      description:
          'A type of fat (lipid) found in your blood that stores unused calories and provides your body with energy.',
      standardUcumUnit: 'mg/dL',
      alternateCodes: ['3043-7'],
      equivalentUnits: ['mg/dL', 'mmol/L'],
    ),

    // --- Renal Function ---
    LoincConcept(
      code: '2160-0',
      patientFriendlyName: 'Serum Creatinine',
      formalName: 'Creatinine [Mass/volume] in Serum or Plasma',
      category: 'Renal',
      description:
          'A normal breakdown byproduct of muscle tissue that healthy kidneys filter out of the blood. Used to assess kidney filtration rate.',
      standardUcumUnit: 'mg/dL',
      alternateCodes: ['38483-4'],
      equivalentUnits: ['mg/dL', 'umol/L'],
    ),
    LoincConcept(
      code: '3094-0',
      patientFriendlyName: 'Blood Urea Nitrogen (BUN)',
      formalName: 'Urea nitrogen [Mass/volume] in Serum or Plasma',
      category: 'Renal',
      description:
          'Measures the amount of nitrogen in your blood that comes from the waste product urea, reflecting kidney function and hydration status.',
      standardUcumUnit: 'mg/dL',
      alternateCodes: ['6299-2'],
      equivalentUnits: ['mg/dL', 'mmol/L'],
    ),
    LoincConcept(
      code: '33914-3',
      patientFriendlyName: 'eGFR (Kidney Filtration Rate)',
      formalName: 'Glomerular filtration rate/1.73 sq M.predicted',
      category: 'Renal',
      description:
          'Estimated Glomerular Filtration Rate estimates how efficiently your kidneys filter blood based on your serum creatinine level.',
      standardUcumUnit: 'mL/min/1.73m2',
      alternateCodes: ['48642-3', '48643-1', '62238-1'],
    ),
    LoincConcept(
      code: '14959-1',
      patientFriendlyName: 'Urine Albumin-to-Creatinine Ratio (uACR)',
      formalName: 'Microalbumin/Creatinine [Mass Ratio] in Urine',
      category: 'Renal',
      description:
          'Checks for early signs of kidney damage by measuring microscopic amounts of protein (albumin) in the urine compared to creatinine.',
      standardUcumUnit: 'mg/g',
      alternateCodes: ['32294-1', '9318-7'],
    ),

    // --- Electrolytes ---
    LoincConcept(
      code: '2951-2',
      patientFriendlyName: 'Sodium',
      formalName: 'Sodium [Moles/volume] in Serum or Plasma',
      category: 'Electrolytes',
      description:
          'An essential electrolyte that helps maintain normal fluid balance, nerve transmission, and muscle contractions.',
      standardUcumUnit: 'mmol/L',
      alternateCodes: ['2947-0'],
      equivalentUnits: ['mmol/L', 'mEq/L'],
    ),
    LoincConcept(
      code: '2823-3',
      patientFriendlyName: 'Potassium',
      formalName: 'Potassium [Moles/volume] in Serum or Plasma',
      category: 'Electrolytes',
      description:
          'A critical electrolyte that regulates heart rhythm, nerve signals, and fluid balance across cells.',
      standardUcumUnit: 'mmol/L',
      alternateCodes: ['6298-4'],
      equivalentUnits: ['mmol/L', 'mEq/L'],
    ),
    LoincConcept(
      code: '2075-0',
      patientFriendlyName: 'Chloride',
      formalName: 'Chloride [Moles/volume] in Serum or Plasma',
      category: 'Electrolytes',
      description:
          'Works closely with sodium and potassium to maintain electrical neutrality and blood pressure.',
      standardUcumUnit: 'mmol/L',
      alternateCodes: ['2069-3'],
      equivalentUnits: ['mmol/L', 'mEq/L'],
    ),
    LoincConcept(
      code: '2028-9',
      patientFriendlyName: 'Carbon Dioxide (CO2 / Bicarbonate)',
      formalName: 'Carbon dioxide, total [Moles/volume] in Serum or Plasma',
      category: 'Electrolytes',
      description:
          'Measures total bicarbonate in blood, reflecting your body’s acid-base (pH) balance and respiratory status.',
      standardUcumUnit: 'mmol/L',
      alternateCodes: ['1959-6', '1963-8'],
      equivalentUnits: ['mmol/L', 'mEq/L'],
    ),
    LoincConcept(
      code: '17861-6',
      patientFriendlyName: 'Total Calcium',
      formalName: 'Calcium [Mass/volume] in Serum or Plasma',
      category: 'Electrolytes',
      description:
          'Essential mineral for strong bones, healthy teeth, proper blood clotting, and nerve and muscle signaling.',
      standardUcumUnit: 'mg/dL',
      alternateCodes: ['49765-1', '17862-4'],
      equivalentUnits: ['mg/dL', 'mmol/L'],
    ),

    // --- Hepatic / Liver ---
    LoincConcept(
      code: '1742-6',
      patientFriendlyName: 'ALT (Liver Enzyme)',
      formalName:
          'Alanine aminotransferase [Enzymatic activity/volume] in Serum or Plasma',
      category: 'Hepatic',
      description:
          'Alanine Aminotransferase is an enzyme primarily found inside liver cells. Released into the bloodstream when liver cells are stressed.',
      standardUcumUnit: 'U/L',
      alternateCodes: ['1743-4'],
    ),
    LoincConcept(
      code: '1920-8',
      patientFriendlyName: 'AST (Liver/Heart Enzyme)',
      formalName:
          'Aspartate aminotransferase [Enzymatic activity/volume] in Serum or Plasma',
      category: 'Hepatic',
      description:
          'Aspartate Aminotransferase is an enzyme found in liver, heart, and muscle tissue. Evaluated alongside ALT for liver assessment.',
      standardUcumUnit: 'U/L',
      alternateCodes: ['1921-6'],
    ),
    LoincConcept(
      code: '6768-6',
      patientFriendlyName: 'Alkaline Phosphatase (ALP)',
      formalName:
          'Alkaline phosphatase [Enzymatic activity/volume] in Serum or Plasma',
      category: 'Hepatic',
      description:
          'Enzyme related to the bile ducts in the liver and bone remodeling activity.',
      standardUcumUnit: 'U/L',
      alternateCodes: ['17756-6'],
    ),
    LoincConcept(
      code: '1975-2',
      patientFriendlyName: 'Total Bilirubin',
      formalName: 'Bilirubin.total [Mass/volume] in Serum or Plasma',
      category: 'Hepatic',
      description:
          'Yellow pigment produced during the normal breakdown of red blood cells; cleared by the liver into bile.',
      standardUcumUnit: 'mg/dL',
      alternateCodes: ['1971-1'],
      equivalentUnits: ['mg/dL', 'umol/L'],
    ),
    LoincConcept(
      code: '1751-7',
      patientFriendlyName: 'Albumin',
      formalName: 'Albumin [Mass/volume] in Serum or Plasma',
      category: 'Hepatic',
      description:
          'The main protein produced by your liver that keeps fluid from leaking out of blood vessels and transports vitamins and hormones.',
      standardUcumUnit: 'g/dL',
      alternateCodes: ['2862-1'],
      equivalentUnits: ['g/dL', 'g/L'],
    ),

    // --- Hematology / Complete Blood Count ---
    LoincConcept(
      code: '6690-2',
      patientFriendlyName: 'White Blood Cell Count (WBC)',
      formalName: 'Leukocytes [#/volume] in Blood by Automated count',
      category: 'Hematology',
      description:
          'Measures the number of infection-fighting white blood cells in your immune system.',
      standardUcumUnit: '10*3/uL',
      alternateCodes: ['26464-8'],
    ),
    LoincConcept(
      code: '789-8',
      patientFriendlyName: 'Red Blood Cell Count (RBC)',
      formalName: 'Erythrocytes [#/volume] in Blood by Automated count',
      category: 'Hematology',
      description:
          'Measures the number of oxygen-carrying red blood cells circulating in your body.',
      standardUcumUnit: '10*6/uL',
      alternateCodes: ['26453-1'],
    ),
    LoincConcept(
      code: '718-7',
      patientFriendlyName: 'Hemoglobin',
      formalName: 'Hemoglobin [Mass/volume] in Blood',
      category: 'Hematology',
      description:
          'The iron-rich protein in red blood cells that binds oxygen in the lungs and delivers it to tissues throughout your body.',
      standardUcumUnit: 'g/dL',
      alternateCodes: ['30313-1', '20509-6'],
      equivalentUnits: ['g/dL', 'g/L', 'mmol/L'],
    ),
    LoincConcept(
      code: '4544-3',
      patientFriendlyName: 'Hematocrit',
      formalName: 'Hematocrit [Volume Fraction] of Blood by Automated count',
      category: 'Hematology',
      description:
          'The proportion of your total blood volume that consists of red blood cells.',
      standardUcumUnit: '%',
      alternateCodes: ['20570-8'],
    ),
    LoincConcept(
      code: '777-3',
      patientFriendlyName: 'Platelets',
      formalName: 'Platelets [#/volume] in Blood by Automated count',
      category: 'Hematology',
      description:
          'Tiny blood cell fragments essential for healthy blood clotting and wound healing.',
      standardUcumUnit: '10*3/uL',
      alternateCodes: ['26515-7'],
    ),

    // --- Endocrine & Thyroid ---
    LoincConcept(
      code: '3016-3',
      patientFriendlyName: 'TSH (Thyroid Stimulating Hormone)',
      formalName: 'Thyrotropin [Units/volume] in Serum or Plasma',
      category: 'Endocrine',
      description:
          'Pituitary hormone that stimulates the thyroid gland to produce thyroxine (T4) and triiodothyronine (T3). Primary screening test for thyroid disorders.',
      standardUcumUnit: 'mIU/L',
      alternateCodes: ['11580-8'],
      equivalentUnits: ['mIU/L', 'uIU/mL'],
    ),
    LoincConcept(
      code: '3024-7',
      patientFriendlyName: 'Free T4 (Thyroxine)',
      formalName: 'Thyroxine (T4) free [Mass/volume] in Serum or Plasma',
      category: 'Endocrine',
      description:
          'Active, unbound thyroid hormone responsible for regulating energy metabolism.',
      standardUcumUnit: 'ng/dL',
      alternateCodes: ['3026-2'],
      equivalentUnits: ['ng/dL', 'pmol/L'],
    ),
    LoincConcept(
      code: '1988-5',
      patientFriendlyName: 'C-Reactive Protein (CRP)',
      formalName: 'C reactive protein [Mass/volume] in Serum or Plasma',
      category: 'Inflammation',
      description:
          'Protein produced by the liver that rises in response to systemic inflammation or infection.',
      standardUcumUnit: 'mg/L',
      alternateCodes: ['30522-7', '76485-2'],
      equivalentUnits: ['mg/L', 'mg/dL'],
    ),
  ];

  static final Map<String, LoincConcept> _byCode = () {
    final map = <String, LoincConcept>{};
    for (final concept in concepts) {
      map[concept.code] = concept;
      for (final alt in concept.alternateCodes) {
        map[alt] = concept;
      }
    }
    return map;
  }();

  /// Normalizes a given LOINC code by stripping system prefixes and leading zeros.
  static String normalizeCode(String code) {
    var c = code.trim().toLowerCase();
    if (c.startsWith('http://loinc.org|') ||
        c.startsWith('https://loinc.org|')) {
      c = c.substring(c.indexOf('|') + 1);
    } else if (c.startsWith('http://loinc.org/') ||
        c.startsWith('https://loinc.org/')) {
      c = c.substring(c.lastIndexOf('/') + 1);
    } else if (c.startsWith('loinc:')) {
      c = c.substring('loinc:'.length);
    }
    return c.trim();
  }

  /// Looks up a [LoincConcept] by code.
  static LoincConcept? lookup(String? rawCode) {
    if (rawCode == null || rawCode.trim().isEmpty) return null;
    final normalized = normalizeCode(rawCode);
    return _byCode[normalized];
  }

  /// Resolves the patient-friendly name for a given [HealthRecord].
  ///
  /// If the record's code matches a known LOINC concept, returns its patient-facing title;
  /// otherwise returns the original [record.name] unaltered.
  static String resolvePatientFriendlyName(HealthRecord record) {
    final concept = lookup(record.code);
    if (concept != null) {
      return concept.patientFriendlyName;
    }
    return record.name;
  }

  /// Calculates a descriptive equivalent value when converting between compatible
  /// clinical units (e.g. blood glucose mg/dL to mmol/L, or cholesterol mg/dL to mmol/L).
  ///
  /// Returns null if the conversion is unknown, incompatible, or not applicable.
  /// Original source records are NEVER modified.
  static String? computeDescriptiveEquivalent({
    required double value,
    required String fromUnit,
    required String? code,
  }) {
    final formatted = ClinicalUnitConverter.formatDualUnitEquivalent(
      value: value,
      fromUnit: fromUnit,
      code: code,
    );
    if (formatted != null && code != null) {
      final concept = lookup(code);
      if (concept != null) {
        for (final eq in concept.equivalentUnits) {
          if (eq.toLowerCase() == 'umol/l' && formatted.endsWith('µmol/L')) {
            return formatted.replaceAll('µmol/L', eq);
          }
        }
      }
    }
    return formatted;
  }
}
