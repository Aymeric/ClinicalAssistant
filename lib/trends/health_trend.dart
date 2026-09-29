import '../models/health_record.dart';

class HealthTrendPoint {
  const HealthTrendPoint({required this.record, required this.value});

  final HealthRecord record;
  final double value;
}

class HealthReferenceRange {
  const HealthReferenceRange({
    required this.lowerBound,
    required this.upperBound,
    required this.sourceText,
  });

  final double? lowerBound;
  final double? upperBound;
  final String sourceText;

  static HealthReferenceRange? tryParse(
    String? raw, {
    String expectedUnit = '',
  }) => parseHealthReferenceRange(raw, expectedUnit: expectedUnit);

  HealthReferenceStatus evaluate(double value) {
    if (upperBound != null && value > upperBound!) {
      return HealthReferenceStatus.above;
    }
    if (lowerBound != null && value < lowerBound!) {
      return HealthReferenceStatus.below;
    }
    if (lowerBound != null || upperBound != null) {
      return HealthReferenceStatus.within;
    }
    return HealthReferenceStatus.unspecified;
  }
}

class HealthTrendReferenceMark {
  const HealthTrendReferenceMark({required this.index, required this.range});

  final int index;
  final HealthReferenceRange range;
}

class HealthTrendSeries {
  const HealthTrendSeries({
    required this.id,
    required this.name,
    required this.unit,
    required this.category,
    required this.points,
  });

  final String id;
  final String name;
  final String unit;
  final RecordCategory category;
  final List<HealthTrendPoint> points;

  String get label => unit.isEmpty ? name : '$name ($unit)';
}

class HealthTrendSummary {
  const HealthTrendSummary({
    required this.latest,
    required this.previous,
    required this.average,
    required this.minimum,
    required this.maximum,
  });

  final HealthTrendPoint latest;
  final HealthTrendPoint? previous;
  final double average;
  final double minimum;
  final double maximum;

  double? get change =>
      previous == null ? null : latest.value - previous!.value;

  double? get percentChange {
    final previousValue = previous?.value;
    if (previousValue == null || previousValue == 0) return null;
    return (latest.value - previousValue) / previousValue.abs() * 100;
  }
}

String healthTrendSeriesId(HealthRecord record) => [
  record.category.name,
  record.name.trim().toLowerCase(),
  record.unit,
].join('\u0000');

List<HealthTrendSeries> buildHealthTrendSeries(Iterable<HealthRecord> records) {
  final groups = <String, List<HealthRecord>>{};
  for (final record in records) {
    if (parseHealthRecordValue(record.value) == null) continue;
    final key = healthTrendSeriesId(record);
    groups.putIfAbsent(key, () => []).add(record);
  }

  final series = <HealthTrendSeries>[];
  for (final entry in groups.entries) {
    final records = entry.value
      ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
    final first = records.first;
    series.add(
      HealthTrendSeries(
        id: entry.key,
        name: first.name,
        unit: first.unit,
        category: first.category,
        points: [
          for (final record in records)
            HealthTrendPoint(
              record: record,
              value: parseHealthRecordValue(record.value)!,
            ),
        ],
      ),
    );
  }
  series.sort((a, b) {
    final categoryOrder = a.category.index.compareTo(b.category.index);
    return categoryOrder != 0 ? categoryOrder : a.name.compareTo(b.name);
  });
  return series;
}

HealthReferenceRange? parseHealthReferenceRange(
  String? sourceText, {
  String expectedUnit = '',
}) {
  if (sourceText == null || sourceText.trim().isEmpty) return null;
  final text = sourceText.trim();
  const number = r'[+-]?(?:\d{1,3}(?:,\d{3})+|\d+)(?:\.\d+)?(?:[eE][+-]?\d+)?';
  final range = RegExp(
    '^\\s*(?<lower>$number|[—–])\\s*(?:–|—|-|to)\\s*'
    '(?<upper>$number|[—–])\\s*(?<unit>.*?)\\s*\$',
    caseSensitive: false,
  ).firstMatch(text);
  if (range != null) {
    final unit = range.namedGroup('unit')!.trim();
    if (!_referenceUnitsMatch(unit, expectedUnit)) return null;
    final lowerText = range.namedGroup('lower')!;
    final upperText = range.namedGroup('upper')!;
    final lower = lowerText == '—' || lowerText == '–'
        ? null
        : parseHealthRecordValue(lowerText);
    final upper = upperText == '—' || upperText == '–'
        ? null
        : parseHealthRecordValue(upperText);
    if ((lower == null && lowerText != '—' && lowerText != '–') ||
        (upper == null && upperText != '—' && upperText != '–') ||
        (lower == null && upper == null) ||
        (lower != null && upper != null && lower > upper)) {
      return null;
    }
    return HealthReferenceRange(
      lowerBound: lower,
      upperBound: upper,
      sourceText: text,
    );
  }

  final threshold = RegExp(
    '^\\s*(?<operator><=|>=|<|>)\\s*(?<value>$number)\\s*'
    '(?<unit>.*?)\\s*\$',
  ).firstMatch(text);
  if (threshold == null ||
      !_referenceUnitsMatch(
        threshold.namedGroup('unit')!.trim(),
        expectedUnit,
      )) {
    return null;
  }
  final value = parseHealthRecordValue(threshold.namedGroup('value')!);
  if (value == null) return null;
  final operator = threshold.namedGroup('operator');
  return HealthReferenceRange(
    lowerBound: operator == '>' || operator == '>=' ? value : null,
    upperBound: operator == '<' || operator == '<=' ? value : null,
    sourceText: text,
  );
}

List<HealthTrendReferenceMark> buildHealthTrendReferenceMarks(
  List<HealthTrendPoint> points, {
  required String unit,
}) {
  final marks = <HealthTrendReferenceMark>[];
  for (var index = 0; index < points.length; index++) {
    final range = parseHealthReferenceRange(
      points[index].record.referenceRange,
      expectedUnit: unit,
    );
    if (range != null) {
      marks.add(HealthTrendReferenceMark(index: index, range: range));
    }
  }
  return marks;
}

bool _referenceUnitsMatch(String rangeUnit, String expectedUnit) {
  if (expectedUnit.isEmpty || rangeUnit.isEmpty) return true;
  String normalize(String unit) => unit.trim().replaceAll(RegExp(r'\s+'), ' ');
  return normalize(rangeUnit) == normalize(expectedUnit);
}

List<HealthTrendPoint> pointsWithinRange(
  Iterable<HealthTrendPoint> points, {
  required DateTime now,
  required int? days,
}) {
  if (days == null) return points.toList();
  final start = now.subtract(Duration(days: days));
  return points
      .where((point) => !point.record.recordedAt.isBefore(start))
      .toList();
}

HealthTrendSummary summarizeHealthTrend(List<HealthTrendPoint> points) {
  if (points.isEmpty) {
    throw ArgumentError.value(points, 'points', 'Must not be empty.');
  }
  final ordered = [...points]
    ..sort((a, b) => a.record.recordedAt.compareTo(b.record.recordedAt));
  var sum = 0.0;
  var minimum = ordered.first.value;
  var maximum = ordered.first.value;
  for (final point in ordered) {
    sum += point.value;
    if (point.value < minimum) minimum = point.value;
    if (point.value > maximum) maximum = point.value;
  }
  return HealthTrendSummary(
    latest: ordered.last,
    previous: ordered.length < 2 ? null : ordered[ordered.length - 2],
    average: sum / ordered.length,
    minimum: minimum,
    maximum: maximum,
  );
}

List<double> movingAverageValues(
  List<HealthTrendPoint> points, {
  int period = 3,
}) {
  if (period < 1) {
    throw ArgumentError.value(period, 'period', 'Must be greater than zero.');
  }
  if (points.length < period) return const [];
  var sum = 0.0;
  final averages = <double>[];
  for (var index = 0; index < points.length; index++) {
    sum += points[index].value;
    if (index >= period) sum -= points[index - period].value;
    if (index >= period - 1) averages.add(sum / period);
  }
  return averages;
}

List<int> sampleHealthTrendIndexes(
  List<HealthTrendPoint> points, {
  int maximumPoints = 120,
}) {
  if (maximumPoints < 2) {
    throw ArgumentError.value(
      maximumPoints,
      'maximumPoints',
      'Must be at least two.',
    );
  }
  if (points.length <= maximumPoints) {
    return [for (var index = 0; index < points.length; index++) index];
  }
  if (maximumPoints < 4) {
    return [
      for (var index = 0; index < maximumPoints; index++)
        (index * (points.length - 1) / (maximumPoints - 1)).round(),
    ];
  }

  final innerLength = points.length - 2;
  final bucketCount = (maximumPoints - 2) ~/ 2;
  final indexes = <int>[0];
  for (var bucket = 0; bucket < bucketCount; bucket++) {
    final start = 1 + (bucket * innerLength / bucketCount).floor();
    final end = 1 + ((bucket + 1) * innerLength / bucketCount).floor();
    var minimumIndex = start;
    var maximumIndex = start;
    for (var index = start + 1; index < end; index++) {
      if (points[index].value < points[minimumIndex].value) {
        minimumIndex = index;
      }
      if (points[index].value > points[maximumIndex].value) {
        maximumIndex = index;
      }
    }
    if (minimumIndex < maximumIndex) {
      indexes
        ..add(minimumIndex)
        ..add(maximumIndex);
    } else if (maximumIndex < minimumIndex) {
      indexes
        ..add(maximumIndex)
        ..add(minimumIndex);
    } else {
      indexes.add(minimumIndex);
    }
  }
  indexes.add(points.length - 1);
  return indexes;
}
