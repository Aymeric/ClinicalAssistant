import 'dart:convert';

class ResultNotificationPreferences {
  const ResultNotificationPreferences({
    this.enabled = false,
    this.newLabResults = true,
    this.newMeasurements = true,
    this.trends = true,
    this.patterns = true,
    this.trendThresholdPercent = 10,
  }) : assert(
          trendThresholdPercent == 5 ||
              trendThresholdPercent == 10 ||
              trendThresholdPercent == 20 ||
              trendThresholdPercent == 50,
        );

  static const trendThresholdOptions = [5, 10, 20, 50];

  final bool enabled;
  final bool newLabResults;
  final bool newMeasurements;
  final bool trends;
  final bool patterns;
  final int trendThresholdPercent;

  ResultNotificationPreferences copyWith({
    bool? enabled,
    bool? newLabResults,
    bool? newMeasurements,
    bool? trends,
    bool? patterns,
    int? trendThresholdPercent,
  }) {
    return ResultNotificationPreferences(
      enabled: enabled ?? this.enabled,
      newLabResults: newLabResults ?? this.newLabResults,
      newMeasurements: newMeasurements ?? this.newMeasurements,
      trends: trends ?? this.trends,
      patterns: patterns ?? this.patterns,
      trendThresholdPercent:
          trendThresholdPercent ?? this.trendThresholdPercent,
    );
  }

  String toJson() => jsonEncode({
        'enabled': enabled,
        'newLabResults': newLabResults,
        'newMeasurements': newMeasurements,
        'trends': trends,
        'patterns': patterns,
        'trendThresholdPercent': trendThresholdPercent,
      });

  factory ResultNotificationPreferences.fromJson(String json) {
    final Object? decoded = jsonDecode(json);
    if (decoded is! Map) {
      throw const FormatException('Notification settings must be an object.');
    }

    bool readBoolean(String key, bool fallback) {
      final value = decoded[key];
      if (value == null) return fallback;
      if (value is bool) return value;
      throw FormatException('Notification setting "$key" must be a boolean.');
    }

    final threshold = decoded['trendThresholdPercent'];
    final normalizedThreshold = threshold ?? 10;
    if (normalizedThreshold is! int ||
        !trendThresholdOptions.contains(normalizedThreshold)) {
      throw const FormatException('The trend threshold is not supported.');
    }

    return ResultNotificationPreferences(
      enabled: readBoolean('enabled', false),
      newLabResults: readBoolean('newLabResults', true),
      newMeasurements: readBoolean('newMeasurements', true),
      trends: readBoolean('trends', true),
      patterns: readBoolean('patterns', true),
      trendThresholdPercent: normalizedThreshold,
    );
  }
}
