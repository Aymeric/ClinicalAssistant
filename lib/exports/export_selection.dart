import 'package:flutter/material.dart';

import '../data/synthetic_demonstration_data.dart';
import '../models/health_record.dart';

/// Filters health records for export based on categories, date range, sources,
/// search query, and synthetic demonstration status.
List<HealthRecord> selectRecordsForExport(
  List<HealthRecord> records,
  Set<RecordCategory> categories, {
  DateTimeRange? dateRange,
  Set<String>? sources,
  String? searchQuery,
  bool includeSynthetic = true,
}) {
  final query = searchQuery?.trim().toLowerCase() ?? '';
  return records.where((record) {
    if (!includeSynthetic && isSyntheticRecord(record)) return false;
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

/// Redacts personal notes and raw source data payloads from exported records
/// without modifying records stored in the on-device vault.
List<HealthRecord> redactRecordsForExport(
  List<HealthRecord> records, {
  bool includeNotes = true,
  bool includeSourceData = true,
}) {
  if (includeNotes && includeSourceData) return records;
  return records.map((record) {
    return HealthRecord(
      id: record.id,
      name: record.name,
      value: record.value,
      unit: record.unit,
      recordedAt: record.recordedAt,
      category: record.category,
      source: record.source,
      sourceId: record.sourceId,
      code: record.code,
      referenceRange: record.referenceRange,
      status: record.status,
      sourceData: includeSourceData ? record.sourceData : null,
      notes: includeNotes ? record.notes : null,
    );
  }).toList();
}
