import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/health_record.dart';
import 'fhir_observation_parser.dart';

typedef HealthConnectMedicalRecordsStatusCallback =
    void Function(String message);

class HealthConnectMedicalRecordsImporter {
  HealthConnectMedicalRecordsImporter({
    MethodChannel? channel,
    FhirObservationParser? parser,
  }) : _channel =
           channel ??
           const MethodChannel(
             'clinical_assistant/health_connect_medical_records',
           ),
       _parser = parser ?? const FhirObservationParser();

  final MethodChannel _channel;
  final FhirObservationParser _parser;

  Future<List<HealthRecord>> importLabRecords({
    required DateTime since,
    HealthConnectMedicalRecordsStatusCallback? onStatus,
  }) async {
    if (!await _invokeBoolean('isMedicalRecordsAvailable')) {
      onStatus?.call(
        'Health Connect Medical Records is unavailable on this device.',
      );
      return const [];
    }

    onStatus?.call('Requesting Health Connect laboratory access');
    if (!await _invokeBoolean('requestLabReadPermission')) {
      onStatus?.call('Health Connect laboratory access was not granted.');
      return const [];
    }

    final response = await _channel.invokeListMethod<Object?>('readLabRecords');
    if (response == null) {
      throw const FormatException(
        'Health Connect returned no laboratory-record response.',
      );
    }

    final records = <HealthRecord>[];
    for (final item in response) {
      if (item is! Map || item.keys.any((key) => key is! String)) {
        throw const FormatException(
          'Health Connect returned a malformed medical record.',
        );
      }
      final sourceId = item['sourceId'];
      final resourceId = item['resourceId'];
      final resourceJson = item['resource'];
      final sourceName = item['sourceName'];
      if (sourceId is! String ||
          sourceId.isEmpty ||
          resourceId is! String ||
          resourceId.isEmpty ||
          resourceJson is! String) {
        throw const FormatException(
          'Health Connect returned a laboratory record without valid provenance or FHIR data.',
        );
      }

      final decodedResource = jsonDecode(resourceJson);
      if (decodedResource is! Map ||
          decodedResource.keys.any((key) => key is! String)) {
        throw const FormatException(
          'Health Connect returned invalid FHIR laboratory data.',
        );
      }
      final resource = Map<String, dynamic>.from(decodedResource);
      if (resource['resourceType'] != 'Observation') {
        throw const FormatException(
          'Health Connect returned a non-Observation laboratory resource.',
        );
      }
      resource['id'] ??= resourceId;

      final displayName = sourceName is String && sourceName.trim().isNotEmpty
          ? sourceName.trim()
          : 'Health Connect';
      final parsed = _parser.parseBundle(
        {
          'resourceType': 'Bundle',
          'entry': [
            {'resource': resource},
          ],
        },
        source: displayName == 'Health Connect'
            ? displayName
            : 'Health Connect ($displayName)',
        sourceId: sourceId,
        idPrefix: 'health-connect-clinical',
      );
      records.addAll(
        parsed.where((record) => !record.recordedAt.isBefore(since.toUtc())),
      );
    }
    return records;
  }

  Future<bool> _invokeBoolean(String method) async {
    final value = await _channel.invokeMethod<Object?>(method);
    if (value is! bool) {
      throw FormatException(
        'Health Connect returned an invalid response for $method.',
      );
    }
    return value;
  }
}
