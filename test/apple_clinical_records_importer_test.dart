import 'package:clinical_assistant/integrations/apple_clinical_records_importer.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test/apple_clinical_records');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
    'parses HealthKit lab resources and preserves clinical provenance',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'importLabRecords');
        return [
          {
            'sourceId': 'org.example.hospital',
            'sourceName': 'Example Hospital',
            'resource': {
              'resourceType': 'Observation',
              'id': 'lab-1',
              'status': 'final',
              'code': {'text': 'Glucose'},
              'effectiveDateTime': '2026-09-20T14:30:00Z',
              'valueQuantity': {'value': 96, 'unit': 'mg/dL'},
            },
          },
        ];
      });

      final records = await AppleClinicalRecordsImporter(channel: channel)
          .importLabRecords(since: DateTime.utc(2026, 1, 1));

      expect(records, hasLength(1));
      expect(records.single.id, 'health-clinical:org.example.hospital:lab-1');
      expect(records.single.name, 'Glucose');
      expect(records.single.displayValue, '96 mg/dL');
      expect(records.single.source, 'Apple Health (Example Hospital)');
      expect(records.single.sourceId, 'org.example.hospital');
      expect(records.single.sourceData?['resourceType'], 'Observation');
    },
  );

  test('applies the requested range to the observation date', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      return [
        for (final date in ['2025-12-31', '2026-01-01'])
          {
            'sourceId': 'org.example.hospital',
            'sourceName': 'Example Hospital',
            'resource': {
              'resourceType': 'Observation',
              'id': date,
              'status': 'final',
              'code': {'text': 'Glucose'},
              'effectiveDateTime': '${date}T14:30:00Z',
              'valueQuantity': {'value': 96, 'unit': 'mg/dL'},
            },
          },
      ];
    });

    final records = await AppleClinicalRecordsImporter(channel: channel)
        .importLabRecords(since: DateTime.utc(2026, 1, 1));

    expect(records, hasLength(1));
    expect(records.single.sourceData?['id'], '2026-01-01');
  });

  test(
    'rejects malformed native responses instead of silently dropping data',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async => ['not a record']);

      await expectLater(
        AppleClinicalRecordsImporter(channel: channel)
            .importLabRecords(since: DateTime.utc(2026)),
        throwsFormatException,
      );
    },
  );
}
