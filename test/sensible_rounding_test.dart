import 'package:clinical_assistant/integrations/fhir_observation_parser.dart';
import 'package:clinical_assistant/integrations/health_data_record_mapper.dart';
import 'package:clinical_assistant/models/health_record.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';

void main() {
  group('formatSensibleNumber', () {
    test('formats integers cleanly without decimals', () {
      expect(formatSensibleNumber(0), '0');
      expect(formatSensibleNumber(72), '72');
      expect(formatSensibleNumber(10000), '10000');
      expect(formatSensibleNumber(-5), '-5');
    });

    test('avoids scientific notation for large clinical/activity counts', () {
      expect(formatSensibleNumber(12345), '12345');
      expect(formatSensibleNumber(85000), '85000');
      expect(formatSensibleNumber(2500.0), '2500');
    });

    test('rounds whole numbers with floating point noise to clean integers', () {
      expect(formatSensibleNumber(72.0), '72');
      expect(formatSensibleNumber(14.999999999999998), '15');
      expect(formatSensibleNumber(72.00000000001), '72');
      expect(formatSensibleNumber(100.000000000), '100');
    });

    test('limits standard decimals to 2 places and trims trailing zeros', () {
      expect(formatSensibleNumber(98.60000000000001), '98.6');
      expect(formatSensibleNumber(4.1000000000000005), '4.1');
      expect(formatSensibleNumber(120.25), '120.25');
      expect(formatSensibleNumber(18.333333333333332), '18.33');
      expect(formatSensibleNumber(16.250000000), '16.25');
      expect(formatSensibleNumber(6.1), '6.1');
    });

    test('preserves precision for small fractions without rounding to zero', () {
      expect(formatSensibleNumber(0.05), '0.05');
      expect(formatSensibleNumber(0.005), '0.005');
      expect(formatSensibleNumber(0.0004), '0.0004');
      expect(formatSensibleNumber(0.025), '0.025');
    });

    test('handles negative values and prevents negative zero', () {
      expect(formatSensibleNumber(-1.50000001), '-1.5');
      expect(formatSensibleNumber(-0.333333), '-0.33');
      expect(formatSensibleNumber(-0.00000000001), '0');
    });

    test('handles non-finite values safely', () {
      expect(formatSensibleNumber(double.infinity), 'Infinity');
      expect(formatSensibleNumber(double.negativeInfinity), '-Infinity');
      expect(formatSensibleNumber(double.nan), 'NaN');
    });
  });

  group('formatSensibleValue', () {
    test('formats numeric strings and preserves non-numeric strings', () {
      expect(formatSensibleValue('98.60000000000001'), '98.6');
      expect(formatSensibleValue('72.000'), '72');
      expect(formatSensibleValue('4.1000005'), '4.1');
      expect(formatSensibleValue('Negative'), 'Negative');
      expect(formatSensibleValue('Yes'), 'Yes');
      expect(formatSensibleValue('Normal'), 'Normal');
      expect(formatSensibleValue(''), '');
    });
  });

  group('HealthRecord displayValue and formattedValue', () {
    test('formats displayValue with clean decimal limits', () {
      final record = HealthRecord(
        id: 'vital:temp',
        name: 'Body temperature',
        value: '98.60000000000001',
        unit: '°F',
        recordedAt: DateTime.utc(2026, 1, 1),
        category: RecordCategory.vital,
        source: 'Apple Health',
      );

      expect(record.formattedValue, '98.6');
      expect(record.displayValue, '98.6 °F');
    });

    test('preserves non-numeric display values unchanged', () {
      final record = HealthRecord(
        id: 'lab:urine',
        name: 'Urine glucose',
        value: 'Negative',
        unit: '',
        recordedAt: DateTime.utc(2026, 1, 1),
        category: RecordCategory.lab,
        source: 'Hospital Lab',
      );

      expect(record.formattedValue, 'Negative');
      expect(record.displayValue, 'Negative');
    });
  });

  group('HealthDataRecordMapper sensible rounding', () {
    const mapper = HealthDataRecordMapper();

    test('eliminates float noise from platform numeric health values', () {
      final point = HealthDataPoint(
        uuid: 'test-point-1',
        value: NumericHealthValue(numericValue: 98.60000000000001),
        type: HealthDataType.BODY_TEMPERATURE,
        unit: HealthDataUnit.DEGREE_FAHRENHEIT,
        dateFrom: DateTime.utc(2026, 1, 1),
        dateTo: DateTime.utc(2026, 1, 1),
        sourcePlatform: HealthPlatformType.appleHealth,
        sourceDeviceId: 'dev-1',
        sourceId: 'src-1',
        sourceName: 'Apple Health',
      );

      final record = mapper.mapPoint(point, fallbackSource: 'Apple Health');
      expect(record.value, '98.6');
      expect(record.displayValue, '98.6 °F');
    });

    test('rounds whole float platform values to clean integers', () {
      final point = HealthDataPoint(
        uuid: 'test-point-2',
        value: NumericHealthValue(numericValue: 72.0000000001),
        type: HealthDataType.HEART_RATE,
        unit: HealthDataUnit.BEATS_PER_MINUTE,
        dateFrom: DateTime.utc(2026, 1, 1),
        dateTo: DateTime.utc(2026, 1, 1),
        sourcePlatform: HealthPlatformType.googleHealthConnect,
        sourceDeviceId: 'dev-1',
        sourceId: 'src-1',
        sourceName: 'Health Connect',
      );

      final record = mapper.mapPoint(point, fallbackSource: 'Health Connect');
      expect(record.value, '72');
      expect(record.displayValue, '72 bpm');
    });
  });

  group('FhirObservationParser sensible rounding', () {
    const parser = FhirObservationParser();

    test('sensibly formats observation quantities and reference ranges', () {
      final records = parser.parseBundle({
        'resourceType': 'Bundle',
        'entry': [
          {
            'resource': {
              'resourceType': 'Observation',
              'id': 'potassium-noisy',
              'status': 'final',
              'code': {'text': 'Serum Potassium'},
              'effectiveDateTime': '2026-09-20T14:30:00Z',
              'valueQuantity': {
                'value': 4.1000000000000005,
                'unit': 'mmol/L',
              },
              'referenceRange': [
                {
                  'low': {'value': 3.50000000001, 'unit': 'mmol/L'},
                  'high': {'value': 5.0000000000, 'unit': 'mmol/L'},
                },
              ],
            },
          },
        ],
      }, source: 'portal.example');

      expect(records, hasLength(1));
      expect(records.first.value, '4.1');
      expect(records.first.displayValue, '4.1 mmol/L');
      expect(records.first.referenceRange, '3.5–5 mmol/L');
    });
  });
}
