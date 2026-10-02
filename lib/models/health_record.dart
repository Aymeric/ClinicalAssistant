enum RecordCategory {
  lab,
  vital,
  activity,
  sleep,
  nutrition,
  cycleTracking,
  medication,
  condition,
  allergy,
  immunization,
}

/// Formats a numeric value with sensible rounding and decimal limits for health data.
///
/// - Integers / whole numbers are formatted without decimal points (e.g. `72`, `10000`).
/// - Standard numbers use at most [maxDecimals] decimal places (default 2, e.g. `98.6`, `120.25`).
/// - Small decimal values (< 0.1) allow up to 3 or 4 decimals so values like `0.005` aren't rounded to 0.
/// - Trailing zeros after the decimal point are trimmed (e.g. `4.10` -> `4.1`).
final _trailingZerosPattern = RegExp(r'0+$');
final _trailingDotPattern = RegExp(r'\.$');
final _groupedNumberPattern = RegExp(
  r'^[+-]?\d{1,3}(,\d{3})+(?:\.\d+)?(?:[eE][+-]?\d+)?$',
);

/// - Floating-point noise like `98.60000000000001` or `72.00000000001` is eliminated.
String formatSensibleNumber(num value, {int maxDecimals = 2}) {
  if (!value.isFinite) return value.toString();
  if (value == 0) return '0';

  final rounded = value.roundToDouble();
  if ((value - rounded).abs() < 1e-9) {
    return rounded.toInt().toString();
  }

  final absVal = value.abs();
  final decimals = absVal < 0.01 ? 4 : (absVal < 0.1 ? 3 : maxDecimals);

  var fixed = value.toStringAsFixed(decimals);
  if (fixed.contains('.')) {
    fixed = fixed
        .replaceFirst(_trailingZerosPattern, '')
        .replaceFirst(_trailingDotPattern, '');
  }

  if (fixed == '-0') return '0';
  return fixed;
}

/// Parses a numeric string value, safely handling commas in grouped numbers
/// (e.g. "10,000") and scientific notation. Returns null if non-numeric or non-finite.
double? parseHealthRecordValue(String value) {
  final trimmed = value.trim();
  final isGroupedNumber = _groupedNumberPattern.hasMatch(trimmed);
  final parsed = double.tryParse(
    isGroupedNumber ? trimmed.replaceAll(',', '') : trimmed,
  );
  return parsed != null && parsed.isFinite ? parsed : null;
}

/// Evaluates whether a measurement value is within, above, or below a reference range.
enum HealthReferenceStatus {
  within('Within reference range'),
  above('Above reference range'),
  below('Below reference range'),
  unspecified('Reference range unspecified');

  const HealthReferenceStatus(this.label);
  final String label;
}

/// Formats a raw record value string with sensible rounding if it represents a numeric value.
/// If non-numeric (e.g. "Negative", "Yes", "Normal"), the original string is returned.
String formatSensibleValue(String rawValue, {int maxDecimals = 2}) {
  final trimmed = rawValue.trim();
  if (trimmed.isEmpty) return trimmed;
  final numVal = parseHealthRecordValue(trimmed);
  if (numVal != null && numVal.isFinite) {
    return formatSensibleNumber(numVal, maxDecimals: maxDecimals);
  }
  return trimmed;
}

class HealthRecord {
  const HealthRecord({
    required this.id,
    required this.name,
    required this.value,
    required this.unit,
    required this.recordedAt,
    required this.category,
    required this.source,
    this.sourceId,
    this.code,
    this.referenceRange,
    this.status,
    this.sourceData,
    this.notes,
  });

  final String id;
  final String name;
  final String value;
  final String unit;
  final DateTime recordedAt;
  final RecordCategory category;
  final String source;
  final String? sourceId;
  final String? code;
  final String? referenceRange;
  final String? status;
  final Map<String, Object?>? sourceData;
  final String? notes;

  bool get isManual => source == 'Manual Entry';

  String get formattedValue => formatSensibleValue(value);

  String get displayValue {
    final formatted = formattedValue;
    return unit.isEmpty ? formatted : '$formatted $unit';
  }

  HealthRecord copyWith({
    String? id,
    String? name,
    String? value,
    String? unit,
    DateTime? recordedAt,
    RecordCategory? category,
    String? source,
    String? sourceId,
    String? code,
    String? referenceRange,
    String? status,
    Map<String, Object?>? sourceData,
    String? notes,
  }) {
    return HealthRecord(
      id: id ?? this.id,
      name: name ?? this.name,
      value: value ?? this.value,
      unit: unit ?? this.unit,
      recordedAt: recordedAt ?? this.recordedAt,
      category: category ?? this.category,
      source: source ?? this.source,
      sourceId: sourceId ?? this.sourceId,
      code: code ?? this.code,
      referenceRange: referenceRange ?? this.referenceRange,
      status: status ?? this.status,
      sourceData: sourceData ?? this.sourceData,
      notes: notes ?? this.notes,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'value': value,
    'unit': unit,
    'recordedAt': recordedAt.toUtc().toIso8601String(),
    'category': category.name,
    'source': source,
    'sourceId': sourceId,
    'code': code,
    'referenceRange': referenceRange,
    'status': status,
    'sourceData': sourceData,
    if (notes != null) 'notes': notes,
  };

  factory HealthRecord.fromJson(Map<String, Object?> json) {
    return HealthRecord(
      id: json['id']! as String,
      name: json['name']! as String,
      value: json['value']! as String,
      unit: json['unit']! as String,
      recordedAt: DateTime.parse(json['recordedAt']! as String).toUtc(),
      category: RecordCategory.values.byName(json['category']! as String),
      source: json['source']! as String,
      sourceId: json['sourceId'] as String?,
      code: json['code'] as String?,
      referenceRange: json['referenceRange'] as String?,
      status: json['status'] as String?,
      sourceData: (json['sourceData'] as Map?)?.cast<String, Object?>(),
      notes: json['notes'] as String?,
    );
  }
}
