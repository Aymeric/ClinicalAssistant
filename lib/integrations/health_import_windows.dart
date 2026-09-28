class HealthImportWindow {
  const HealthImportWindow(this.start, this.end);

  final DateTime start;
  final DateTime end;
}

List<HealthImportWindow> buildHealthImportWindows({
  required DateTime since,
  required DateTime until,
  required int batchYears,
}) {
  if (batchYears <= 0) {
    throw ArgumentError.value(batchYears, 'batchYears', 'Must be positive.');
  }

  final windows = <HealthImportWindow>[];
  var start = DateTime(since.year, since.month, since.day);
  while (start.isBefore(until)) {
    final next = DateTime(start.year + batchYears, start.month, start.day);
    final end = next.isBefore(until) ? next : until;
    windows.add(HealthImportWindow(start, end));
    start = end;
  }
  return windows;
}
