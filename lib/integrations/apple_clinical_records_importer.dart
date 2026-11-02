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
    Duration timeout = const Duration(seconds: 20),
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

    // Group clinical resources by source so related panels and observations
    // are parsed together in the same bundle context.
    final groupedBySource = <String, List<Map<String, dynamic>>>{};
    final sourceNames = <String, String>{};

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
      final sourceName = item['sourceName']?.toString().trim();
      if (sourceName != null && sourceName.isNotEmpty) {
        sourceNames[sourceId] = sourceName;
      }
      groupedBySource.putIfAbsent(sourceId, () => []).add(fhirResource);
    }

    final records = <HealthRecord>[];
    for (final entry in groupedBySource.entries) {
      final sourceId = entry.key;
      final resources = entry.value;
      final sourceName = sourceNames[sourceId];
      final source = sourceName != null && sourceName.isNotEmpty
          ? 'Apple Health ($sourceName)'
          : 'Apple Health';

      final bundleEntries = resources.map((res) => {'resource': res}).toList();

      final parsed = _parser.parseBundle(
        {'resourceType': 'Bundle', 'entry': bundleEntries},
        source: source,
        sourceId: sourceId,
        idPrefix: 'health-clinical',
      );
      records.addAll(parsed);
    }
    return records;
  }
}
