import 'dart:convert';

import '../models/health_record.dart';

class FhirObservationParser {
  const FhirObservationParser();

  /// Parses a FHIR JSON string representing either a FHIR Bundle, an Observation,
  /// or a list of Observations.
  List<HealthRecord> parseJson(
    String jsonString, {
    String source = 'FHIR File',
    String? sourceId,
    String idPrefix = 'fhir-file',
  }) {
    final dynamic decoded = jsonDecode(jsonString);
    if (decoded is Map) {
      final map = Map<String, dynamic>.from(decoded);
      if (map['resourceType'] == 'Bundle') {
        return parseBundle(
          map,
          source: source,
          sourceId: sourceId,
          idPrefix: idPrefix,
        );
      } else if (map['resourceType'] == 'Observation') {
        final record = _parseObservation(
          map,
          source: source,
          sourceId: sourceId ?? source,
          idPrefix: idPrefix,
        );
        return record == null ? const [] : [record];
      }
    } else if (decoded is List) {
      final records = <HealthRecord>[];
      for (final item in decoded) {
        if (item is Map) {
          final map = Map<String, dynamic>.from(item);
          if (map['resourceType'] == 'Observation') {
            final record = _parseObservation(
              map,
              source: source,
              sourceId: sourceId ?? source,
              idPrefix: idPrefix,
            );
            if (record != null) records.add(record);
          }
        }
      }
      return records;
    }
    throw const FormatException(
      'The provided JSON is not a recognized FHIR Bundle or Observation.',
    );
  }

  List<HealthRecord> parseBundle(
    Map<String, dynamic> bundle, {
    required String source,
    String? sourceId,
    String idPrefix = 'fhir',
  }) {
    if (bundle['resourceType'] != 'Bundle') {
      throw const FormatException('The provider did not return a FHIR Bundle.');
    }
    final entries = bundle['entry'];
    if (entries is! List) return const [];

    final records = <HealthRecord>[];
    for (final entry in entries) {
      if (entry is! Map || entry['resource'] is! Map) continue;
      final resource = Map<String, dynamic>.from(entry['resource'] as Map);
      if (resource['resourceType'] != 'Observation') continue;
      final record = _parseObservation(
        resource,
        source: source,
        sourceId: sourceId ?? source,
        idPrefix: idPrefix,
      );
      if (record != null) records.add(record);

      final components = resource['component'];
      if (components is List) {
        for (var index = 0; index < components.length; index++) {
          final component = components[index];
          if (component is! Map) continue;
          final componentRecord = _parseObservation(
            {
              ...resource,
              'id': '${resource['id'] ?? 'observation'}-component-$index',
              'code': component['code'],
              'valueQuantity': component['valueQuantity'],
              'valueString': component['valueString'],
              'valueCodeableConcept': component['valueCodeableConcept'],
              'valueInteger': component['valueInteger'],
              'valueBoolean': component['valueBoolean'],
              'referenceRange': component['referenceRange'],
              'component': null,
            },
            source: source,
            sourceId: sourceId ?? source,
            idPrefix: idPrefix,
          );
          if (componentRecord != null) records.add(componentRecord);
        }
      }
    }
    return records;
  }

  HealthRecord? _parseObservation(
    Map<String, dynamic> observation, {
    required String source,
    required String sourceId,
    required String idPrefix,
  }) {
    final status = observation['status']?.toString();
    if (status == 'entered-in-error' || status == 'cancelled') return null;

    final code = observation['code'];
    final name = _conceptText(code);
    if (name.isEmpty) return null;

    final quantity = observation['valueQuantity'];
    String value;
    String unit = '';
    if (quantity is Map) {
      final rawValue = quantity['value'];
      if (rawValue == null) return null;
      if (rawValue is num) {
        value = formatSensibleNumber(rawValue);
      } else {
        value = formatSensibleValue(rawValue.toString());
      }
      unit = (quantity['unit'] ?? quantity['code'] ?? '').toString();
    } else if (observation['valueString'] != null) {
      value = observation['valueString'].toString();
    } else if (observation['valueInteger'] != null) {
      value = observation['valueInteger'].toString();
    } else if (observation['valueBoolean'] is bool) {
      value = (observation['valueBoolean'] as bool) ? 'Yes' : 'No';
    } else if (observation['valueCodeableConcept'] is Map) {
      final codedValue = _conceptText(observation['valueCodeableConcept']);
      if (codedValue.isEmpty) return null;
      value = codedValue;
    } else {
      return null;
    }

    final id = observation['id']?.toString();
    final recordedAt = _observationDate(observation);
    if (id == null || id.isEmpty || recordedAt == null) return null;

    return HealthRecord(
      id: '$idPrefix:$sourceId:$id',
      name: name,
      value: value,
      unit: unit,
      recordedAt: recordedAt,
      category: RecordCategory.lab,
      source: source,
      sourceId: sourceId,
      code: _conceptCode(code),
      referenceRange: _referenceRange(observation['referenceRange']),
      status: status,
      sourceData: Map<String, Object?>.from(observation),
    );
  }

  String _conceptText(Object? concept) {
    if (concept is! Map) return '';
    final text = concept['text']?.toString().trim();
    if (text != null && text.isNotEmpty) return text;
    final codings = concept['coding'];
    if (codings is! List) return '';
    for (final coding in codings) {
      if (coding is Map) {
        final display = coding['display']?.toString().trim();
        if (display != null && display.isNotEmpty) return display;
      }
    }
    return '';
  }

  String? _conceptCode(Object? concept) {
    if (concept is! Map || concept['coding'] is! List) return null;
    for (final coding in concept['coding'] as List) {
      if (coding is Map && coding['code'] != null) {
        return coding['code'].toString();
      }
    }
    return null;
  }

  DateTime? _observationDate(Map<String, dynamic> observation) {
    final effective = observation['effectiveDateTime'];
    if (effective is String) return DateTime.tryParse(effective)?.toUtc();
    final period = observation['effectivePeriod'];
    if (period is Map && period['start'] is String) {
      return DateTime.tryParse(period['start'] as String)?.toUtc();
    }
    final issued = observation['issued'];
    if (issued is String) return DateTime.tryParse(issued)?.toUtc();
    final updated = (observation['meta'] as Map?)?['lastUpdated'];
    if (updated is String) return DateTime.tryParse(updated)?.toUtc();
    return null;
  }

  String? _referenceRange(Object? ranges) {
    if (ranges is! List || ranges.isEmpty || ranges.first is! Map) {
      return null;
    }
    final range = ranges.first as Map;
    final text = range['text']?.toString().trim();
    if (text != null && text.isNotEmpty) return text;
    final low = range['low'];
    final high = range['high'];
    final lowText = _quantityText(low);
    final highText = _quantityText(high);
    if (lowText == null && highText == null) return null;
    final unit =
        (low is Map ? low['unit'] : null) ??
        (high is Map ? high['unit'] : null);
    return '${lowText ?? '—'}–${highText ?? '—'}${unit == null ? '' : ' $unit'}';
  }

  String? _quantityText(Object? quantity) {
    if (quantity is! Map || quantity['value'] == null) return null;
    final val = quantity['value'];
    if (val is num) return formatSensibleNumber(val);
    return formatSensibleValue(val.toString());
  }
}
