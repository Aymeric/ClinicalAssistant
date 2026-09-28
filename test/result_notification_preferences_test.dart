import 'package:clinical_assistant/notifications/result_notification_preferences.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('defaults to opt-in with alert rules and a 10% threshold', () {
    const preferences = ResultNotificationPreferences();

    expect(preferences.enabled, isFalse);
    expect(preferences.newLabResults, isTrue);
    expect(preferences.newMeasurements, isTrue);
    expect(preferences.trends, isTrue);
    expect(preferences.patterns, isTrue);
    expect(preferences.trendThresholdPercent, 10);
  });

  test('round-trips saved notification preferences', () {
    const preferences = ResultNotificationPreferences(
      enabled: true,
      newLabResults: false,
      trends: false,
      trendThresholdPercent: 20,
    );

    expect(
      ResultNotificationPreferences.fromJson(preferences.toJson()).toJson(),
      preferences.toJson(),
    );
  });

  test('rejects unsupported trend thresholds', () {
    expect(
      () =>
          ResultNotificationPreferences.fromJson('{"trendThresholdPercent":7}'),
      throwsFormatException,
    );
  });
}
