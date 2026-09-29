import 'package:flutter/material.dart';

import '../models/health_record.dart';

List<HealthRecord> selectRecordsForExport(
  List<HealthRecord> records,
  Set<RecordCategory> categories, {
  DateTimeRange? dateRange,
  Set<String>? sources,
  String? searchQuery,
}) {
  final query = searchQuery?.trim().toLowerCase() ?? '';
  return records.where((record) {
    if (!categories.contains(record.category)) return false;
    if (sources != null && !sources.contains(record.source)) return false;
    if (dateRange != null) {
      final date = DateUtils.dateOnly(record.recordedAt.toLocal());
      if (date.isBefore(dateRange.start) || date.isAfter(dateRange.end)) {
        return false;
      }
    }
    if (query.isNotEmpty) {
      final searchable =
          '${record.name} ${record.displayValue} ${record.source} ${record.code ?? ''}'
              .toLowerCase();
      if (!searchable.contains(query)) return false;
    }
    return true;
  }).toList();
}
