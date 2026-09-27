enum RecordCategory { lab, vital, activity, sleep, nutrition, cycleTracking }

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

  String get displayValue => unit.isEmpty ? value : '$value $unit';

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
    );
  }
}
