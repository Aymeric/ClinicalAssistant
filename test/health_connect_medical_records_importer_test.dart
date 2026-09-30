import 'dart:convert';

import 'package:clinical_assistant/integrations/health_connect_medical_records_importer.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test/health_connect_medical_records');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('parses Health Connect lab records with source provenance', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'isMedicalRecordsAvailable':
        case 'requestLabReadPermission':
          return true;
        case 'readLabRecords':
          return [
            {
              'sourceId': 'health-connect-source-1',
              'sourceName': 'Example Clinic',
              'resourceId': 'observation-1',
              'resource': jsonEncode({
                'resourceType': 'Observation',
                'id': 'observation-1',
                'status': 'final',
                'code': {'text': 'Glucose'},
                'effectiveDateTime': '2026-03-10T14:30:00Z',
                'valueQuantity': {'value': 96, 'unit': 'mg/dL'},
              }),
            },
          ];
        default:
          fail('Unexpected method ${call.method}');
      }
    });

    final records = await HealthConnectMedicalRecordsImporter(channel: channel)
        .importLabRecords(since: DateTime.utc(2026, 1, 1));

    expect(records, hasLength(1));
    expect(
      records.single.id,
      'health-connect-clinical:health-connect-source-1:observation-1',
    );
    expect(records.single.name, 'Glucose');
    expect(records.single.displayValue, '96 mg/dL');
    expect(records.single.source, 'Health Connect (Example Clinic)');
    expect(records.single.sourceId, 'health-connect-source-1');
    expect(records.single.sourceData?['resourceType'], 'Observation');
  });

  test('filters observations to the requested start date', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'isMedicalRecordsAvailable':
        case 'requestLabReadPermission':
          return true;
        case 'readLabRecords':
          return [
            for (final date in ['2025-12-31', '2026-01-01'])
              {
                'sourceId': 'clinic',
                'resourceId': date,
                'resource': jsonEncode({
                  'resourceType': 'Observation',
                  'id': date,
                  'status': 'final',
                  'code': {'text': 'Glucose'},
                  'effectiveDateTime': '${date}T14:30:00Z',
                  'valueQuantity': {'value': 96, 'unit': 'mg/dL'},
                }),
              },
          ];
        default:
          fail('Unexpected method ${call.method}');
      }
    });

    final records = await HealthConnectMedicalRecordsImporter(channel: channel)
        .importLabRecords(since: DateTime.utc(2026, 1, 1));

    expect(records, hasLength(1));
    expect(records.single.sourceData?['id'], '2026-01-01');
  });

  test('does not read labs when Health Connect access is denied', () async {
    final methods = <String>[];
    final statuses = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      methods.add(call.method);
      return switch (call.method) {
        'isMedicalRecordsAvailable' => true,
        'requestLabReadPermission' => false,
        _ => fail('Unexpected method ${call.method}'),
      };
    });

    final records = await HealthConnectMedicalRecordsImporter(channel: channel)
        .importLabRecords(since: DateTime.utc(2026), onStatus: statuses.add);

    expect(records, isEmpty);
    expect(methods, ['isMedicalRecordsAvailable', 'requestLabReadPermission']);
    expect(statuses.last, 'Health Connect laboratory access was not granted.');
  });

  test('reports when Medical Records is not supported', () async {
    final methods = <String>[];
    final statuses = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      methods.add(call.method);
      return false;
    });

    final records = await HealthConnectMedicalRecordsImporter(channel: channel)
        .importLabRecords(since: DateTime.utc(2026), onStatus: statuses.add);

    expect(records, isEmpty);
    expect(methods, ['isMedicalRecordsAvailable']);
    expect(
      statuses.single,
      'Health Connect Medical Records is unavailable on this device.',
    );
  });

  test('rejects malformed native medical-record responses', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      return switch (call.method) {
        'isMedicalRecordsAvailable' || 'requestLabReadPermission' => true,
        'readLabRecords' => ['not a record'],
        _ => fail('Unexpected method ${call.method}'),
      };
    });

    await expectLater(
      HealthConnectMedicalRecordsImporter(channel: channel)
          .importLabRecords(since: DateTime.utc(2026)),
      throwsFormatException,
    );
  });
}
