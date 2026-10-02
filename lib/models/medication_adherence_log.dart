class MedicationAdherenceLog {
  const MedicationAdherenceLog({
    required this.id,
    required this.medicationId,
    required this.medicationName,
    required this.takenAt,
    this.notes,
  });

  final String id;
  final String medicationId;
  final String medicationName;
  final DateTime takenAt;
  final String? notes;

  Map<String, Object?> toJson() => {
    'id': id,
    'medicationId': medicationId,
    'medicationName': medicationName,
    'takenAt': takenAt.toIso8601String(),
    if (notes != null && notes!.isNotEmpty) 'notes': notes,
  };

  factory MedicationAdherenceLog.fromJson(Map<String, Object?> json) {
    return MedicationAdherenceLog(
      id: json['id'] as String? ?? '',
      medicationId: json['medicationId'] as String? ?? '',
      medicationName: json['medicationName'] as String? ?? '',
      takenAt:
          DateTime.tryParse(json['takenAt'] as String? ?? '') ?? DateTime.now(),
      notes: json['notes'] as String?,
    );
  }
}
