import '../models/health_record.dart';
import '../trends/health_trend.dart';

/// Clinical unit systems supported across Clinical Assistant for laboratory analytes.
enum ClinicalUnitSystem {
  usConventional('US Conventional', 'mg/dL, g/dL, mEq/L'),
  internationalSi('International SI', 'mmol/L, µmol/L, g/L');

  const ClinicalUnitSystem(this.label, this.description);

  final String label;
  final String description;

  String get shortLabel => switch (this) {
    ClinicalUnitSystem.usConventional => 'US',
    ClinicalUnitSystem.internationalSi => 'SI',
  };
}

/// Metadata and conversion rules for a specific laboratory analyte.
class ClinicalAnalyteConversion {
  const ClinicalAnalyteConversion({
    required this.id,
    required this.displayName,
    required this.loincCodes,
    required this.nameKeywords,
    required this.usUnit,
    required this.siUnit,
    required this.toSiMultiplier,
    this.usDecimals = 1,
    this.siDecimals = 1,
    this.alternativeUsUnits = const [],
    this.alternativeSiUnits = const [],
  });

  final String id;
  final String displayName;
  final List<String> loincCodes;
  final List<String> nameKeywords;
  final String usUnit;
  final String siUnit;
  final double toSiMultiplier;
  final int usDecimals;
  final int siDecimals;
  final List<String> alternativeUsUnits;
  final List<String> alternativeSiUnits;

  /// Returns true if [unit] matches either the US Conventional unit or any supported alias.
  bool isUsUnit(String unit) {
    final norm = _normalizeUnit(unit);
    if (norm == _normalizeUnit(usUnit)) return true;
    return alternativeUsUnits.any((u) => _normalizeUnit(u) == norm);
  }

  /// Returns true if [unit] matches either the International SI unit or any supported alias.
  bool isSiUnit(String unit) {
    final norm = _normalizeUnit(unit);
    if (norm == _normalizeUnit(siUnit)) return true;
    return alternativeSiUnits.any((u) => _normalizeUnit(u) == norm);
  }

  /// Returns true if [unit] is a recognized compatible unit for this analyte.
  bool isCompatibleUnit(String unit) => isUsUnit(unit) || isSiUnit(unit);

  /// Target unit for the specified [system].
  String unitForSystem(ClinicalUnitSystem system) => switch (system) {
    ClinicalUnitSystem.usConventional => usUnit,
    ClinicalUnitSystem.internationalSi => siUnit,
  };

  /// Decimal precision for the specified [system].
  int decimalsForSystem(ClinicalUnitSystem system) => switch (system) {
    ClinicalUnitSystem.usConventional => usDecimals,
    ClinicalUnitSystem.internationalSi => siDecimals,
  };

  /// Converts a numeric value from [fromUnit] to [toUnit].
  double? convert(
    double value, {
    required String fromUnit,
    required String toUnit,
  }) {
    final normFrom = _normalizeUnit(fromUnit);
    final normTo = _normalizeUnit(toUnit);
    if (normFrom == normTo) return value;

    if (isUsUnit(fromUnit) && isSiUnit(toUnit)) {
      return value * toSiMultiplier;
    }
    if (isSiUnit(fromUnit) && isUsUnit(toUnit)) {
      return value / toSiMultiplier;
    }
    return null;
  }

  /// Formats a value converted to the opposite unit system.
  String? formatSecondaryValue(double value, String fromUnit) {
    if (isUsUnit(fromUnit)) {
      final converted = convert(value, fromUnit: fromUnit, toUnit: siUnit);
      if (converted == null) return null;
      return '${_formatNumber(converted, siDecimals)} $siUnit';
    }
    if (isSiUnit(fromUnit)) {
      final converted = convert(value, fromUnit: fromUnit, toUnit: usUnit);
      if (converted == null) return null;
      return '${_formatNumber(converted, usDecimals)} $usUnit';
    }
    return null;
  }
}

/// Offline clinical UCUM unit conversion and dual-unit normalization engine.
///
/// Converts between US Conventional and International SI units for standard
/// laboratory analytes, unifies disjointed series, and produces descriptive
/// dual-unit strings while preserving raw underlying records.
class ClinicalUnitConverter {
  const ClinicalUnitConverter._();

  static const List<ClinicalAnalyteConversion> conversions = [
    // Blood Glucose: 1 mmol/L = 18.0182 mg/dL
    // Multiplier from mg/dL to mmol/L = 1 / 18.0182 = 0.0555005
    ClinicalAnalyteConversion(
      id: 'glucose',
      displayName: 'Blood Glucose',
      loincCodes: ['2345-7', '2339-0', '15074-8', '41653-7', '14749-6'],
      nameKeywords: [
        'glucose',
        'blood sugar',
        'fasting blood sugar',
        'fasting glucose',
        'random glucose',
      ],
      usUnit: 'mg/dL',
      siUnit: 'mmol/L',
      toSiMultiplier: 1.0 / 18.0182,
      usDecimals: 0,
      siDecimals: 1,
    ),

    // Total Cholesterol: 1 mmol/L = 38.67 mg/dL
    ClinicalAnalyteConversion(
      id: 'cholesterol_total',
      displayName: 'Total Cholesterol',
      loincCodes: ['2093-3', '35200-5'],
      nameKeywords: [
        'total cholesterol',
        'cholesterol, total',
        'cholesterol total',
      ],
      usUnit: 'mg/dL',
      siUnit: 'mmol/L',
      toSiMultiplier: 1.0 / 38.67,
      usDecimals: 0,
      siDecimals: 2,
    ),

    // HDL Cholesterol: 1 mmol/L = 38.67 mg/dL
    ClinicalAnalyteConversion(
      id: 'cholesterol_hdl',
      displayName: 'HDL Cholesterol',
      loincCodes: ['2085-9', '14646-4'],
      nameKeywords: ['hdl', 'high density lipoprotein', 'good cholesterol'],
      usUnit: 'mg/dL',
      siUnit: 'mmol/L',
      toSiMultiplier: 1.0 / 38.67,
      usDecimals: 0,
      siDecimals: 2,
    ),

    // LDL Cholesterol: 1 mmol/L = 38.67 mg/dL
    ClinicalAnalyteConversion(
      id: 'cholesterol_ldl',
      displayName: 'LDL Cholesterol',
      loincCodes: ['13457-7', '18262-6', '2089-1'],
      nameKeywords: ['ldl', 'low density lipoprotein', 'bad cholesterol'],
      usUnit: 'mg/dL',
      siUnit: 'mmol/L',
      toSiMultiplier: 1.0 / 38.67,
      usDecimals: 0,
      siDecimals: 2,
    ),

    // Triglycerides: 1 mmol/L = 88.57 mg/dL
    ClinicalAnalyteConversion(
      id: 'triglycerides',
      displayName: 'Triglycerides',
      loincCodes: ['2571-8', '3043-7'],
      nameKeywords: ['triglyceride', 'triglycerides', 'serum triglycerides'],
      usUnit: 'mg/dL',
      siUnit: 'mmol/L',
      toSiMultiplier: 1.0 / 88.57,
      usDecimals: 0,
      siDecimals: 2,
    ),

    // Serum Creatinine: 1 mg/dL = 88.4 umol/L
    ClinicalAnalyteConversion(
      id: 'creatinine',
      displayName: 'Serum Creatinine',
      loincCodes: ['2160-0', '38483-4'],
      nameKeywords: ['creatinine', 'serum creatinine'],
      usUnit: 'mg/dL',
      siUnit: 'µmol/L',
      alternativeSiUnits: ['umol/L', 'micromol/L'],
      toSiMultiplier: 88.4,
      usDecimals: 2,
      siDecimals: 0,
    ),

    // Total Bilirubin: 1 mg/dL = 17.104 umol/L
    ClinicalAnalyteConversion(
      id: 'bilirubin_total',
      displayName: 'Total Bilirubin',
      loincCodes: ['1975-2', '1971-1'],
      nameKeywords: [
        'bilirubin, total',
        'total bilirubin',
        'serum bilirubin',
        'bilirubin',
      ],
      usUnit: 'mg/dL',
      siUnit: 'µmol/L',
      alternativeSiUnits: ['umol/L', 'micromol/L'],
      toSiMultiplier: 17.104,
      usDecimals: 2,
      siDecimals: 1,
    ),

    // Total Calcium: 1 mmol/L = 4.008 mg/dL (1 mg/dL = 0.2495 mmol/L)
    ClinicalAnalyteConversion(
      id: 'calcium_total',
      displayName: 'Total Calcium',
      loincCodes: ['17861-6', '49765-1', '17862-4'],
      nameKeywords: [
        'calcium, total',
        'total calcium',
        'serum calcium',
        'calcium',
      ],
      usUnit: 'mg/dL',
      siUnit: 'mmol/L',
      toSiMultiplier: 0.2495,
      usDecimals: 1,
      siDecimals: 2,
    ),

    // Blood Urea Nitrogen (BUN) / Urea: 1 mmol/L urea = 2.801 mg/dL BUN (1 mg/dL BUN = 0.357 mmol/L urea)
    ClinicalAnalyteConversion(
      id: 'urea_nitrogen',
      displayName: 'Blood Urea Nitrogen (BUN)',
      loincCodes: ['3094-0', '6299-2'],
      nameKeywords: [
        'urea nitrogen',
        'blood urea nitrogen',
        'bun',
        'serum urea',
      ],
      usUnit: 'mg/dL',
      siUnit: 'mmol/L',
      toSiMultiplier: 0.357,
      usDecimals: 0,
      siDecimals: 1,
    ),

    // Albumin: 1 g/dL = 10 g/L
    ClinicalAnalyteConversion(
      id: 'albumin',
      displayName: 'Albumin',
      loincCodes: ['1751-7', '2862-1'],
      nameKeywords: ['albumin', 'serum albumin'],
      usUnit: 'g/dL',
      siUnit: 'g/L',
      toSiMultiplier: 10.0,
      usDecimals: 1,
      siDecimals: 0,
    ),

    // Total Protein: 1 g/dL = 10 g/L
    ClinicalAnalyteConversion(
      id: 'total_protein',
      displayName: 'Total Protein',
      loincCodes: ['2885-2'],
      nameKeywords: ['total protein', 'serum total protein', 'protein, total'],
      usUnit: 'g/dL',
      siUnit: 'g/L',
      toSiMultiplier: 10.0,
      usDecimals: 1,
      siDecimals: 0,
    ),

    // Hemoglobin: 1 g/dL = 10 g/L
    ClinicalAnalyteConversion(
      id: 'hemoglobin',
      displayName: 'Hemoglobin',
      loincCodes: ['718-7', '30313-1', '20509-6'],
      nameKeywords: ['hemoglobin', 'hgb', 'blood hemoglobin'],
      usUnit: 'g/dL',
      siUnit: 'g/L',
      toSiMultiplier: 10.0,
      usDecimals: 1,
      siDecimals: 0,
    ),

    // Sodium: 1 mEq/L = 1 mmol/L
    ClinicalAnalyteConversion(
      id: 'sodium',
      displayName: 'Sodium',
      loincCodes: ['2951-2', '2947-0'],
      nameKeywords: ['sodium', 'serum sodium', 'na'],
      usUnit: 'mEq/L',
      siUnit: 'mmol/L',
      toSiMultiplier: 1.0,
      usDecimals: 0,
      siDecimals: 0,
    ),

    // Potassium: 1 mEq/L = 1 mmol/L
    ClinicalAnalyteConversion(
      id: 'potassium',
      displayName: 'Potassium',
      loincCodes: ['2823-3', '6298-4'],
      nameKeywords: ['potassium', 'serum potassium', 'k'],
      usUnit: 'mEq/L',
      siUnit: 'mmol/L',
      toSiMultiplier: 1.0,
      usDecimals: 1,
      siDecimals: 1,
    ),

    // Chloride: 1 mEq/L = 1 mmol/L
    ClinicalAnalyteConversion(
      id: 'chloride',
      displayName: 'Chloride',
      loincCodes: ['2075-0', '2069-3'],
      nameKeywords: ['chloride', 'serum chloride', 'cl'],
      usUnit: 'mEq/L',
      siUnit: 'mmol/L',
      toSiMultiplier: 1.0,
      usDecimals: 0,
      siDecimals: 0,
    ),

    // Carbon Dioxide / Bicarbonate: 1 mEq/L = 1 mmol/L
    ClinicalAnalyteConversion(
      id: 'bicarbonate',
      displayName: 'Carbon Dioxide (CO2 / Bicarbonate)',
      loincCodes: ['2028-9', '1959-6', '1963-8'],
      nameKeywords: ['bicarbonate', 'carbon dioxide', 'co2', 'total co2'],
      usUnit: 'mEq/L',
      siUnit: 'mmol/L',
      toSiMultiplier: 1.0,
      usDecimals: 0,
      siDecimals: 0,
    ),
  ];

  /// Finds the matching analyte conversion rules for the given [record], [code], [name], or [unit].
  static ClinicalAnalyteConversion? findConversion({
    String? code,
    String? name,
    String? unit,
  }) {
    final cleanCode = code?.trim();
    if (cleanCode != null && cleanCode.isNotEmpty) {
      for (final conv in conversions) {
        if (conv.loincCodes.contains(cleanCode)) return conv;
      }
    }

    final cleanName = name?.trim().toLowerCase();
    if (cleanName != null && cleanName.isNotEmpty) {
      for (final conv in conversions) {
        for (final kw in conv.nameKeywords) {
          if (cleanName == kw ||
              cleanName.contains(kw) ||
              (kw.length > 3 && cleanName.startsWith(kw))) {
            if (unit == null || unit.isEmpty || conv.isCompatibleUnit(unit)) {
              return conv;
            }
          }
        }
      }
    }

    return null;
  }

  /// Returns true if [unitA] and [unitB] are compatible convertible units for the specified analyte.
  static bool areUnitsCompatible(
    String unitA,
    String unitB, {
    String? code,
    String? name,
  }) {
    if (_normalizeUnit(unitA) == _normalizeUnit(unitB)) return true;
    final conv = findConversion(code: code, name: name, unit: unitA);
    if (conv == null) return false;
    return conv.isCompatibleUnit(unitA) && conv.isCompatibleUnit(unitB);
  }

  /// Converts a numeric [value] from [fromUnit] to [toUnit].
  static double? convertValue(
    double value, {
    required String fromUnit,
    required String toUnit,
    String? code,
    String? name,
  }) {
    final conv = findConversion(code: code, name: name, unit: fromUnit);
    if (conv == null) return null;
    return conv.convert(value, fromUnit: fromUnit, toUnit: toUnit);
  }

  /// Formats a descriptive dual-unit string for display (e.g. "99 mg/dL (5.5 mmol/L)").
  static String? formatDualUnitEquivalent({
    required double value,
    required String fromUnit,
    String? code,
    String? name,
  }) {
    final conv = findConversion(code: code, name: name, unit: fromUnit);
    if (conv == null) return null;
    return conv.formatSecondaryValue(value, fromUnit);
  }

  /// Converts a [HealthReferenceRange] to a [targetUnit] if compatible.
  static HealthReferenceRange? convertReferenceRange(
    HealthReferenceRange range, {
    required String fromUnit,
    required String targetUnit,
    String? code,
    String? name,
  }) {
    if (_normalizeUnit(fromUnit) == _normalizeUnit(targetUnit)) return range;
    final conv = findConversion(code: code, name: name, unit: fromUnit);
    if (conv == null || !conv.isCompatibleUnit(targetUnit)) return null;

    final lower = range.lowerBound != null
        ? conv.convert(
            range.lowerBound!,
            fromUnit: fromUnit,
            toUnit: targetUnit,
          )
        : null;
    final upper = range.upperBound != null
        ? conv.convert(
            range.upperBound!,
            fromUnit: fromUnit,
            toUnit: targetUnit,
          )
        : null;

    final decimals = conv.isUsUnit(targetUnit)
        ? conv.usDecimals
        : conv.siDecimals;
    final sourceBuffer = StringBuffer();
    if (lower != null && upper != null) {
      sourceBuffer.write(
        '${_formatNumber(lower, decimals)} – ${_formatNumber(upper, decimals)} $targetUnit',
      );
    } else if (lower != null) {
      sourceBuffer.write('>= ${_formatNumber(lower, decimals)} $targetUnit');
    } else if (upper != null) {
      sourceBuffer.write('<= ${_formatNumber(upper, decimals)} $targetUnit');
    } else {
      return null;
    }

    return HealthReferenceRange(
      lowerBound: lower,
      upperBound: upper,
      sourceText: sourceBuffer.toString(),
    );
  }

  /// Computes a canonical trend series ID for grouping compatible multi-unit records.
  ///
  /// If the record belongs to a known convertible clinical lab analyte, returns
  /// a stable ID like `lab:glucose` or `lab:cholesterol_total` regardless of whether
  /// the source recorded `mg/dL` or `mmol/L`.
  static String canonicalSeriesId(HealthRecord record) {
    if (record.category != RecordCategory.lab) {
      return '${record.category.name}\u0000${record.name.trim().toLowerCase()}\u0000${record.unit}';
    }

    final conv = findConversion(
      code: record.code,
      name: record.name,
      unit: record.unit,
    );
    if (conv != null && conv.isCompatibleUnit(record.unit)) {
      return 'lab:${conv.id}';
    }

    return '${record.category.name}\u0000${record.name.trim().toLowerCase()}\u0000${record.unit}';
  }
}

String _normalizeUnit(String unit) {
  return unit
      .trim()
      .toLowerCase()
      .replaceAll('µ', 'u')
      .replaceAll(' ', '')
      .replaceAll('/', '/');
}

String _formatNumber(double value, int decimals) {
  if (decimals <= 0) return value.round().toString();
  return value.toStringAsFixed(decimals);
}
