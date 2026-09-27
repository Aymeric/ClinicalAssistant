import '../models/health_record.dart';

List<HealthRecord> selectRecordsForExport(
  List<HealthRecord> records,
  Set<RecordCategory> categories,
) {
  return records
      .where((record) => categories.contains(record.category))
      .toList();
}
