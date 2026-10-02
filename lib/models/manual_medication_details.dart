import 'health_record.dart';
import 'medication_adherence_log.dart';

class ManualMedicationDetails {
  const ManualMedicationDetails({
    required this.frequency,
    this.route,
    this.endDate,
    this.adherenceLogs = const [],
  });

  static const sourceDataKey = 'manualMedication';

  final String frequency;
  final String? route;
  final DateTime? endDate;
  final List<MedicationAdherenceLog> adherenceLogs;

  factory ManualMedicationDetails.fromRecord(HealthRecord record) {
    final raw = record.sourceData?[sourceDataKey];
    if (raw is! Map) {
      return const ManualMedicationDetails(frequency: '');
    }

    final frequency = raw['frequency'];
    final route = raw['route'];
    final endDate = raw['endDate'];
    final rawLogs = raw['adherenceLogs'];
    final logs = <MedicationAdherenceLog>[];
    if (rawLogs is List) {
      for (final item in rawLogs) {
        if (item is Map) {
          logs.add(
            MedicationAdherenceLog.fromJson(Map<String, Object?>.from(item)),
          );
        }
      }
    }

    return ManualMedicationDetails(
      frequency: frequency is String ? frequency : '',
      route: route is String && route.isNotEmpty ? route : null,
      endDate: endDate is String
          ? DateTime.tryParse(
              RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(endDate)
                  ? '${endDate}T00:00:00'
                  : endDate,
            )
          : null,
      adherenceLogs: logs,
    );
  }

  ManualMedicationDetails withAddedLog(MedicationAdherenceLog log) {
    return ManualMedicationDetails(
      frequency: frequency,
      route: route,
      endDate: endDate,
      adherenceLogs: [...adherenceLogs, log],
    );
  }

  Map<String, Object?> withSourceData(Map<String, Object?>? sourceData) {
    final end = endDate;
    return {
      ...?sourceData,
      sourceDataKey: {
        'frequency': frequency,
        if (route != null && route!.isNotEmpty) 'route': route,
        if (end != null)
          'endDate':
              '${end.year.toString().padLeft(4, '0')}-${end.month.toString().padLeft(2, '0')}-${end.day.toString().padLeft(2, '0')}',
        if (adherenceLogs.isNotEmpty)
          'adherenceLogs': adherenceLogs.map((l) => l.toJson()).toList(),
      },
    };
  }
}
