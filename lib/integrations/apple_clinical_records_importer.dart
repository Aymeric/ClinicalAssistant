import 'dart:async';

import 'package:flutter/services.dart';

import '../models/health_record.dart';
import 'fhir_observation_parser.dart';

class AppleClinicalRecordsImporter {
  AppleClinicalRecordsImporter({
    MethodChannel? channel,
    FhirObservationParser? parser,
  }) : _channel =
           channel ??
           const MethodChannel('clinical_assistant/apple_clinical_records'),
       _parser = parser ?? const FhirObservationParser();

  final MethodChannel _channel;
  final FhirObservationParser _parser;

  Future<List<HealthRecord>> importLabRecords({
    required DateTime since,
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final List<Object?>? response;
    try {
      response = await _channel
          .invokeListMethod<Object?>('importLabRecords')
          .timeout(timeout);
    } on TimeoutException {
      return const [];
    } on PlatformException {
      return const [];
    } on MissingPluginException {
      return const [];
    }
    if (response == null) return const [];

    final records = <HealthRecord>[];
    for (final item in response) {
      if (item is! Map) {
        throw const FormatException(
          'Apple Health returned a malformed clinical record.',
        );
      }
      final sourceId = item['sourceId'];
      final resource = item['resource'];
      if (sourceId is! String ||
          sourceId.isEmpty ||
          resource is! Map ||
          resource.keys.any((key) => key is! String)) {
        throw const FormatException(
          'Apple Health returned a clinical record without valid provenance or FHIR data.',
        );
      }
      final fhirResource = Map<String, dynamic>.from(resource);
      final sourceName = item['sourceName'];
      final source = sourceName is String && sourceName.trim().isNotEmpty
          ? 'Apple Health (${sourceName.trim()})'
          : 'Apple Health';
      final parsed = _parser.parseBundle(
        {
          'resourceType': 'Bundle',
          'entry': [
            {'resource': fhirResource},
          ],
        },
        source: source,
        sourceId: sourceId,
        idPrefix: 'health-clinical',
      );
      records.addAll(
        parsed.where((record) => !record.recordedAt.isBefore(since.toUtc())),
      );
    }
    return records;
  }
}
