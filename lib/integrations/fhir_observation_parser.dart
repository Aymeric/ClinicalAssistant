import 'dart:convert';

import '../models/health_record.dart';

class FhirObservationParser {
  const FhirObservationParser();

  /// Parses a FHIR JSON string representing either a FHIR Bundle, an Observation,
  /// MedicationRequest, Condition, AllergyIntolerance, Immunization, or a list of resources.
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
      } else {
        final record = _parseResource(
          map,
          source: source,
          sourceId: sourceId ?? source,
          idPrefix: idPrefix,
        );
        if (record != null) return [record];
      }
    } else if (decoded is List) {
      final records = <HealthRecord>[];
      for (final item in decoded) {
        if (item is Map) {
          final map = Map<String, dynamic>.from(item);
          final record = _parseResource(
            map,
            source: source,
            sourceId: sourceId ?? source,
            idPrefix: idPrefix,
          );
          if (record != null) records.add(record);
        }
      }
      if (records.isNotEmpty) return records;
    }
    throw const FormatException(
      'The provided JSON is not a recognized FHIR Bundle or clinical resource.',
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
      final record = _parseResource(
        resource,
        source: source,
        sourceId: sourceId ?? source,
        idPrefix: idPrefix,
      );
      if (record != null) records.add(record);

      if (resource['resourceType'] == 'Observation') {
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
    }
    return records;
  }

  HealthRecord? _parseResource(
    Map<String, dynamic> resource, {
    required String source,
    required String sourceId,
    required String idPrefix,
  }) {
    final type = resource['resourceType']?.toString();
    switch (type) {
      case 'Observation':
        return _parseObservation(
          resource,
          source: source,
          sourceId: sourceId,
          idPrefix: idPrefix,
        );
      case 'MedicationRequest':
        return _parseMedicationRequest(
          resource,
          source: source,
          sourceId: sourceId,
          idPrefix: idPrefix,
        );
      case 'MedicationStatement':
        return _parseMedicationStatement(
          resource,
          source: source,
          sourceId: sourceId,
          idPrefix: idPrefix,
        );
      case 'Condition':
        return _parseCondition(
          resource,
          source: source,
          sourceId: sourceId,
          idPrefix: idPrefix,
        );
      case 'AllergyIntolerance':
        return _parseAllergyIntolerance(
          resource,
          source: source,
          sourceId: sourceId,
          idPrefix: idPrefix,
        );
      case 'Immunization':
        return _parseImmunization(
          resource,
          source: source,
          sourceId: sourceId,
          idPrefix: idPrefix,
        );
      default:
        return null;
    }
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
      category: _categorizeObservation(observation),
      source: source,
      sourceId: sourceId,
      code: _conceptCode(code),
      referenceRange: _referenceRange(observation['referenceRange']),
      status: status,
      notes: _notesText(observation['note']),
      sourceData: Map<String, Object?>.from(observation),
    );
  }

  RecordCategory _categorizeObservation(Map<String, dynamic> observation) {
    final categories = observation['category'];
    if (categories is List) {
      for (final cat in categories) {
        if (cat is Map) {
          final codings = cat['coding'];
          if (codings is List) {
            for (final c in codings) {
              if (c is Map && c['code'] == 'vital-signs') {
                return RecordCategory.vital;
              }
            }
          }
          final text = cat['text']?.toString().toLowerCase();
          if (text == 'vital signs' || text == 'vital-signs') {
            return RecordCategory.vital;
          }
        }
      }
    }
    return RecordCategory.lab;
  }

  HealthRecord? _parseMedicationRequest(
    Map<String, dynamic> medication, {
    required String source,
    required String sourceId,
    required String idPrefix,
  }) {
    final status = medication['status']?.toString();
    if (status == 'entered-in-error' || status == 'cancelled') return null;

    final id = medication['id']?.toString();
    if (id == null || id.isEmpty) return null;

    final codeObj =
        medication['medicationCodeableConcept'] ?? medication['code'];
    var name = _conceptText(codeObj);
    if (name.isEmpty) {
      name = _referenceText(medication['medicationReference']);
    }
    if (name.isEmpty) return null;

    String? instructionText;
    final dosageInstructions = medication['dosageInstruction'];
    if (dosageInstructions is List && dosageInstructions.isNotEmpty) {
      final texts = <String>[];
      for (final di in dosageInstructions) {
        if (di is Map) {
          final t = di['text']?.toString().trim();
          if (t != null && t.isNotEmpty) {
            texts.add(t);
          } else if (di['patientInstruction'] != null) {
            final pi = di['patientInstruction'].toString().trim();
            if (pi.isNotEmpty) texts.add(pi);
          }
        }
      }
      if (texts.isNotEmpty) instructionText = texts.join('; ');
    }

    final value = instructionText ?? (status != null ? _capitalize(status) : 'Prescribed');
    final recordedAt = _parseFhirDate(medication['authoredOn']) ??
        _parseFhirDate(medication['effectiveDateTime']) ??
        _parseFhirDate((medication['meta'] as Map?)?['lastUpdated']) ??
        DateTime.now().toUtc();

    return HealthRecord(
      id: '$idPrefix:$sourceId:$id',
      name: name,
      value: value,
      unit: '',
      recordedAt: recordedAt,
      category: RecordCategory.medication,
      source: source,
      sourceId: sourceId,
      code: _conceptCode(codeObj),
      status: status,
      notes: _notesText(medication['note']),
      sourceData: Map<String, Object?>.from(medication),
    );
  }

  HealthRecord? _parseMedicationStatement(
    Map<String, dynamic> statement, {
    required String source,
    required String sourceId,
    required String idPrefix,
  }) {
    final status = statement['status']?.toString();
    if (status == 'entered-in-error' || status == 'not-taken') return null;

    final id = statement['id']?.toString();
    if (id == null || id.isEmpty) return null;

    final codeObj =
        statement['medicationCodeableConcept'] ?? statement['code'];
    var name = _conceptText(codeObj);
    if (name.isEmpty) {
      name = _referenceText(statement['medicationReference']);
    }
    if (name.isEmpty) return null;

    String? instructionText;
    final dosage = statement['dosage'];
    if (dosage is List && dosage.isNotEmpty) {
      final texts = <String>[];
      for (final d in dosage) {
        if (d is Map) {
          final t = d['text']?.toString().trim();
          if (t != null && t.isNotEmpty) texts.add(t);
        }
      }
      if (texts.isNotEmpty) instructionText = texts.join('; ');
    }

    final value = instructionText ?? (status != null ? _capitalize(status) : 'Reported');
    final recordedAt = _parseFhirDate(statement['effectiveDateTime']) ??
        _parseFhirDate(statement['dateAsserted']) ??
        _parseFhirDate((statement['meta'] as Map?)?['lastUpdated']) ??
        DateTime.now().toUtc();

    return HealthRecord(
      id: '$idPrefix:$sourceId:$id',
      name: name,
      value: value,
      unit: '',
      recordedAt: recordedAt,
      category: RecordCategory.medication,
      source: source,
      sourceId: sourceId,
      code: _conceptCode(codeObj),
      status: status,
      notes: _notesText(statement['note']),
      sourceData: Map<String, Object?>.from(statement),
    );
  }

  HealthRecord? _parseCondition(
    Map<String, dynamic> condition, {
    required String source,
    required String sourceId,
    required String idPrefix,
  }) {
    final verificationStatus = _conceptCode(condition['verificationStatus']) ??
        _conceptText(condition['verificationStatus']).toLowerCase();
    if (verificationStatus == 'entered-in-error' || verificationStatus == 'refuted') {
      return null;
    }

    final id = condition['id']?.toString();
    if (id == null || id.isEmpty) return null;

    final code = condition['code'];
    final name = _conceptText(code);
    if (name.isEmpty) return null;

    final clinicalStatus = _conceptCode(condition['clinicalStatus']) ??
        _conceptText(condition['clinicalStatus']);
    final severity = _conceptText(condition['severity']);

    String value;
    if (clinicalStatus.isNotEmpty && severity.isNotEmpty) {
      value = '${_capitalize(clinicalStatus)} ($severity)';
    } else if (clinicalStatus.isNotEmpty) {
      value = _capitalize(clinicalStatus);
    } else if (severity.isNotEmpty) {
      value = severity;
    } else {
      value = 'Diagnosed';
    }

    final recordedAt = _parseFhirDate(condition['onsetDateTime']) ??
        _parseFhirDate(condition['recordedDate']) ??
        _parseFhirDate((condition['onsetPeriod'] as Map?)?['start']) ??
        _parseFhirDate((condition['meta'] as Map?)?['lastUpdated']) ??
        DateTime.now().toUtc();

    return HealthRecord(
      id: '$idPrefix:$sourceId:$id',
      name: name,
      value: value,
      unit: '',
      recordedAt: recordedAt,
      category: RecordCategory.condition,
      source: source,
      sourceId: sourceId,
      code: _conceptCode(code),
      status: clinicalStatus.isNotEmpty ? clinicalStatus : verificationStatus,
      notes: _notesText(condition['note']),
      sourceData: Map<String, Object?>.from(condition),
    );
  }

  HealthRecord? _parseAllergyIntolerance(
    Map<String, dynamic> allergy, {
    required String source,
    required String sourceId,
    required String idPrefix,
  }) {
    final verificationStatus = _conceptCode(allergy['verificationStatus']) ??
        _conceptText(allergy['verificationStatus']).toLowerCase();
    if (verificationStatus == 'entered-in-error' || verificationStatus == 'refuted') {
      return null;
    }

    final id = allergy['id']?.toString();
    if (id == null || id.isEmpty) return null;

    final code = allergy['code'];
    final name = _conceptText(code);
    if (name.isEmpty) return null;

    final clinicalStatus = _conceptCode(allergy['clinicalStatus']) ??
        _conceptText(allergy['clinicalStatus']);
    final criticality = allergy['criticality']?.toString();

    final reactions = allergy['reaction'];
    final manifestations = <String>[];
    if (reactions is List) {
      for (final r in reactions) {
        if (r is Map) {
          final manifs = r['manifestation'];
          if (manifs is List) {
            for (final m in manifs) {
              final text = _conceptText(m);
              if (text.isNotEmpty) manifestations.add(text);
            }
          }
          final severity = r['severity']?.toString();
          if (severity != null && severity.isNotEmpty && manifestations.isNotEmpty) {
            final last = manifestations.removeLast();
            manifestations.add('$last ($severity)');
          }
        }
      }
    }

    String value;
    if (manifestations.isNotEmpty) {
      value = manifestations.join(', ');
    } else if (criticality != null && criticality.isNotEmpty) {
      value = 'Criticality: ${_capitalize(criticality)}';
    } else if (clinicalStatus.isNotEmpty) {
      value = _capitalize(clinicalStatus);
    } else {
      value = 'Recorded';
    }

    final recordedAt = _parseFhirDate(allergy['recordedDate']) ??
        _parseFhirDate(allergy['onsetDateTime']) ??
        _parseFhirDate(allergy['lastOccurrence']) ??
        _parseFhirDate((allergy['meta'] as Map?)?['lastUpdated']) ??
        DateTime.now().toUtc();

    return HealthRecord(
      id: '$idPrefix:$sourceId:$id',
      name: name,
      value: value,
      unit: '',
      recordedAt: recordedAt,
      category: RecordCategory.allergy,
      source: source,
      sourceId: sourceId,
      code: _conceptCode(code),
      status: clinicalStatus.isNotEmpty ? clinicalStatus : verificationStatus,
      notes: _notesText(allergy['note']),
      sourceData: Map<String, Object?>.from(allergy),
    );
  }

  HealthRecord? _parseImmunization(
    Map<String, dynamic> immunization, {
    required String source,
    required String sourceId,
    required String idPrefix,
  }) {
    final status = immunization['status']?.toString();
    if (status == 'entered-in-error' || status == 'not-done') return null;

    final id = immunization['id']?.toString();
    if (id == null || id.isEmpty) return null;

    final vaccineCode = immunization['vaccineCode'];
    final name = _conceptText(vaccineCode);
    if (name.isEmpty) return null;

    final lotNumber = immunization['lotNumber']?.toString().trim();
    final value = lotNumber != null && lotNumber.isNotEmpty
        ? 'Completed (Lot: $lotNumber)'
        : 'Completed';

    final recordedAt = _parseFhirDate(immunization['occurrenceDateTime']) ??
        _parseFhirDate(immunization['occurrenceString']) ??
        _parseFhirDate(immunization['recorded']) ??
        _parseFhirDate((immunization['meta'] as Map?)?['lastUpdated']) ??
        DateTime.now().toUtc();

    return HealthRecord(
      id: '$idPrefix:$sourceId:$id',
      name: name,
      value: value,
      unit: '',
      recordedAt: recordedAt,
      category: RecordCategory.immunization,
      source: source,
      sourceId: sourceId,
      code: _conceptCode(vaccineCode),
      status: status ?? 'completed',
      notes: _notesText(immunization['note']),
      sourceData: Map<String, Object?>.from(immunization),
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

  String _referenceText(Object? reference) {
    if (reference is! Map) return '';
    final display = reference['display']?.toString().trim();
    if (display != null && display.isNotEmpty) return display;
    final ref = reference['reference']?.toString().trim();
    if (ref != null && ref.isNotEmpty) return ref;
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

  String? _notesText(Object? note) {
    if (note is List) {
      final texts = <String>[];
      for (final item in note) {
        if (item is Map && item['text'] != null) {
          final t = item['text'].toString().trim();
          if (t.isNotEmpty) texts.add(t);
        } else if (item is String && item.trim().isNotEmpty) {
          texts.add(item.trim());
        }
      }
      return texts.isEmpty ? null : texts.join('\n');
    } else if (note is Map && note['text'] != null) {
      final t = note['text'].toString().trim();
      return t.isEmpty ? null : t;
    } else if (note is String && note.trim().isNotEmpty) {
      return note.trim();
    }
    return null;
  }

  static final _ymdDateRegExp = RegExp(r'^\d{4}-\d{2}-\d{2}$');

  DateTime? _parseFhirDate(Object? value) {
    if (value is String && value.trim().isNotEmpty) {
      final trimmed = value.trim();
      if (_ymdDateRegExp.hasMatch(trimmed)) {
        final parts = trimmed.split('-').map(int.parse).toList();
        return DateTime.utc(parts[0], parts[1], parts[2]);
      }
      return DateTime.tryParse(trimmed)?.toUtc();
    }
    return null;
  }

  String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
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
