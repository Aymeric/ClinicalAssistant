import 'dart:convert';

import '../models/clinical_panel.dart';
import '../models/health_record.dart';

class FhirObservationParser {
  const FhirObservationParser();

  /// Parses a FHIR JSON string representing either a FHIR Bundle, an Observation,
  /// MedicationRequest, Condition, AllergyIntolerance, Immunization, DiagnosticReport,
  /// or a list of resources.
  List<HealthRecord> parseJson(
    String jsonString, {
    String source = 'FHIR File',
    String? sourceId,
    String idPrefix = 'fhir-file',
  }) {
    final dynamic decoded = jsonDecode(jsonString);
    if (decoded is Map) {
      final map = Map<String, dynamic>.from(decoded);
      final resourceType = map['resourceType']?.toString();
      if (resourceType == 'Bundle') {
        return parseBundle(
          map,
          source: source,
          sourceId: sourceId,
          idPrefix: idPrefix,
        );
      } else if (resourceType == 'DiagnosticReport') {
        return parseDiagnosticReport(
          map,
          source: source,
          sourceId: sourceId ?? source,
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
      final items = <Map<String, dynamic>>[];
      for (final item in decoded) {
        if (item is Map) {
          items.add(Map<String, dynamic>.from(item));
        }
      }
      final panelMappings = _extractPanelMappings(items);
      final reportsWithoutChildren = <Map<String, dynamic>>[];

      for (final map in items) {
        final resourceType = map['resourceType']?.toString();
        if (resourceType == 'DiagnosticReport') {
          final panelInfo = _extractPanelInfoFromReport(map);
          final contained = map['contained'];
          var hasContained = false;
          if (contained is List && contained.isNotEmpty) {
            for (var index = 0; index < contained.length; index++) {
              final c = contained[index];
              if (c is! Map || c['resourceType'] != 'Observation') continue;
              final obsMap = Map<String, dynamic>.from(c);
              obsMap['id'] ??= '${map['id'] ?? 'report'}-contained-$index';
              final containedRecord = _parseObservation(
                obsMap,
                source: source,
                sourceId: sourceId ?? source,
                idPrefix: idPrefix,
                panelData: panelInfo,
                fallbackDate: panelInfo['effectiveDateTime'],
              );
              if (containedRecord != null) {
                records.add(containedRecord);
                hasContained = true;
              }
            }
          }
          if (!hasContained) {
            reportsWithoutChildren.add(map);
          }
          continue;
        }

        final record = _parseResource(
          map,
          source: source,
          sourceId: sourceId ?? source,
          idPrefix: idPrefix,
          panelMappings: panelMappings,
        );
        if (record != null) records.add(record);
      }

      for (final report in reportsWithoutChildren) {
        final panelInfo = _extractPanelInfoFromReport(report);
        final reportId = panelInfo['id'];
        final hasMatchingObservation = records.any((r) {
          final rPanel = extractRecordPanelInfo(r);
          return rPanel != null && rPanel.id == reportId;
        });
        if (!hasMatchingObservation) {
          final standalone = _parseDiagnosticReportRecord(
            report,
            source: source,
            sourceId: sourceId ?? source,
            idPrefix: idPrefix,
            panelInfo: panelInfo,
          );
          if (standalone != null) records.add(standalone);
        }
      }

      if (records.isNotEmpty) return records;
    }
    throw const FormatException(
      'The provided JSON is not a recognized FHIR Bundle or clinical resource.',
    );
  }

  /// Parses a standalone FHIR DiagnosticReport resource.
  ///
  /// If the report contains inline `contained` Observations, extracts them with
  /// panel metadata attached. Otherwise, if the report represents a narrative/standalone
  /// result (e.g. imaging, pathology, or simple test with conclusion), creates a
  /// [HealthRecord] directly representing the DiagnosticReport.
  List<HealthRecord> parseDiagnosticReport(
    Map<String, dynamic> report, {
    required String source,
    String? sourceId,
    String idPrefix = 'fhir',
  }) {
    final panelInfo = _extractPanelInfoFromReport(report);
    final records = <HealthRecord>[];
    final effectiveSourceId = sourceId ?? source;

    final contained = report['contained'];
    if (contained is List && contained.isNotEmpty) {
      for (var index = 0; index < contained.length; index++) {
        final item = contained[index];
        if (item is Map && item['resourceType'] == 'Observation') {
          final obsMap = Map<String, dynamic>.from(item);
          obsMap['id'] ??= '${report['id'] ?? 'report'}-contained-$index';
          final record = _parseObservation(
            obsMap,
            source: source,
            sourceId: effectiveSourceId,
            idPrefix: idPrefix,
            panelData: panelInfo,
            fallbackDate: panelInfo['effectiveDateTime'],
          );
          if (record != null) records.add(record);
        }
      }
    }

    if (records.isNotEmpty) return records;

    final standalone = _parseDiagnosticReportRecord(
      report,
      source: source,
      sourceId: effectiveSourceId,
      idPrefix: idPrefix,
      panelInfo: panelInfo,
    );
    if (standalone != null) return [standalone];

    return records;
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

    final panelMappings = _extractPanelMappings(entries);
    final records = <HealthRecord>[];
    final reportsWithoutChildren = <Map<String, dynamic>>[];

    for (final entry in entries) {
      if (entry is! Map || entry['resource'] is! Map) continue;
      final resource = Map<String, dynamic>.from(entry['resource'] as Map);
      final resourceType = resource['resourceType']?.toString();

      if (resourceType == 'DiagnosticReport') {
        final panelInfo = _extractPanelInfoFromReport(resource);
        final contained = resource['contained'];
        var hasContained = false;
        if (contained is List && contained.isNotEmpty) {
          for (var index = 0; index < contained.length; index++) {
            final c = contained[index];
            if (c is! Map || c['resourceType'] != 'Observation') continue;
            final obsMap = Map<String, dynamic>.from(c);
            obsMap['id'] ??= '${resource['id'] ?? 'report'}-contained-$index';
            final containedRecord = _parseObservation(
              obsMap,
              source: source,
              sourceId: sourceId ?? source,
              idPrefix: idPrefix,
              panelData: panelInfo,
              fallbackDate: panelInfo['effectiveDateTime'],
            );
            if (containedRecord != null) {
              records.add(containedRecord);
              hasContained = true;
            }
          }
        }
        if (!hasContained) {
          reportsWithoutChildren.add(resource);
        }
        continue;
      }

      final record = _parseResource(
        resource,
        source: source,
        sourceId: sourceId ?? source,
        idPrefix: idPrefix,
        panelMappings: panelMappings,
      );
      if (record != null) records.add(record);

      if (resourceType == 'Observation') {
        final components = resource['component'];
        if (components is List) {
          final isLab = _categorizeObservation(resource) == RecordCategory.lab;
          final panelData =
              _resolvePanelForObservation(resource, panelMappings) ??
              (isLab
                  ? <String, String>{
                      'id': resource['id']?.toString() ?? 'obs-panel',
                      'name': _conceptText(resource['code']),
                      'code': ?_conceptCode(resource['code']),
                    }
                  : null);

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
              panelData: panelData,
            );
            if (componentRecord != null) records.add(componentRecord);
          }
        }
      }
    }

    for (final report in reportsWithoutChildren) {
      final panelInfo = _extractPanelInfoFromReport(report);
      final reportId = panelInfo['id'];
      final hasMatchingObservation = records.any((r) {
        final rPanel = extractRecordPanelInfo(r);
        return rPanel != null && rPanel.id == reportId;
      });
      if (!hasMatchingObservation) {
        final standalone = _parseDiagnosticReportRecord(
          report,
          source: source,
          sourceId: sourceId ?? source,
          idPrefix: idPrefix,
          panelInfo: panelInfo,
        );
        if (standalone != null) records.add(standalone);
      }
    }

    return records;
  }

  HealthRecord? _parseResource(
    Map<String, dynamic> resource, {
    required String source,
    required String sourceId,
    required String idPrefix,
    Map<String, Map<String, String>> panelMappings = const {},
  }) {
    final type = resource['resourceType']?.toString();
    switch (type) {
      case 'Observation':
        final panelData = _resolvePanelForObservation(resource, panelMappings);
        return _parseObservation(
          resource,
          source: source,
          sourceId: sourceId,
          idPrefix: idPrefix,
          panelData: panelData,
        );
      case 'DiagnosticReport':
        final panelInfo = _extractPanelInfoFromReport(resource);
        return _parseDiagnosticReportRecord(
          resource,
          source: source,
          sourceId: sourceId,
          idPrefix: idPrefix,
          panelInfo: panelInfo,
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
    Map<String, String>? panelData,
    String? fallbackDate,
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
    final recordedAt =
        _observationDate(observation) ??
        (fallbackDate != null ? _parseFhirDate(fallbackDate) : null) ??
        (panelData != null && panelData['effectiveDateTime'] != null
            ? _parseFhirDate(panelData['effectiveDateTime'])
            : null);
    if (id == null || id.isEmpty || recordedAt == null) return null;

    final sourceData = Map<String, Object?>.from(observation);
    if (panelData != null) {
      sourceData['panel'] = panelData;
    }

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
      sourceData: sourceData,
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

    final value =
        instructionText ??
        (status != null ? _capitalize(status) : 'Prescribed');
    final recordedAt =
        _parseFhirDate(medication['authoredOn']) ??
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

    final codeObj = statement['medicationCodeableConcept'] ?? statement['code'];
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

    final value =
        instructionText ?? (status != null ? _capitalize(status) : 'Reported');
    final recordedAt =
        _parseFhirDate(statement['effectiveDateTime']) ??
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
    final verificationStatus =
        _conceptCode(condition['verificationStatus']) ??
        _conceptText(condition['verificationStatus']).toLowerCase();
    if (verificationStatus == 'entered-in-error' ||
        verificationStatus == 'refuted') {
      return null;
    }

    final id = condition['id']?.toString();
    if (id == null || id.isEmpty) return null;

    final code = condition['code'];
    final name = _conceptText(code);
    if (name.isEmpty) return null;

    final clinicalStatus =
        _conceptCode(condition['clinicalStatus']) ??
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

    final recordedAt =
        _parseFhirDate(condition['onsetDateTime']) ??
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
    final verificationStatus =
        _conceptCode(allergy['verificationStatus']) ??
        _conceptText(allergy['verificationStatus']).toLowerCase();
    if (verificationStatus == 'entered-in-error' ||
        verificationStatus == 'refuted') {
      return null;
    }

    final id = allergy['id']?.toString();
    if (id == null || id.isEmpty) return null;

    final code = allergy['code'];
    final name = _conceptText(code);
    if (name.isEmpty) return null;

    final clinicalStatus =
        _conceptCode(allergy['clinicalStatus']) ??
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
          if (severity != null &&
              severity.isNotEmpty &&
              manifestations.isNotEmpty) {
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

    final recordedAt =
        _parseFhirDate(allergy['recordedDate']) ??
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

    final recordedAt =
        _parseFhirDate(immunization['occurrenceDateTime']) ??
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

  static final _isoDatePattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');

  DateTime? _parseFhirDate(Object? value) {
    if (value is String && value.trim().isNotEmpty) {
      final trimmed = value.trim();
      if (_isoDatePattern.hasMatch(trimmed)) {
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

  String? _performerText(Object? performer) {
    if (performer is List && performer.isNotEmpty) {
      final first = performer.first;
      if (first is Map) {
        final display = first['display']?.toString().trim();
        if (display != null && display.isNotEmpty) return display;
        final reference = first['reference']?.toString().trim();
        if (reference != null && reference.isNotEmpty) return reference;
      }
    } else if (performer is Map) {
      final display = performer['display']?.toString().trim();
      if (display != null && display.isNotEmpty) return display;
      final reference = performer['reference']?.toString().trim();
      if (reference != null && reference.isNotEmpty) return reference;
    }
    return null;
  }

  String _stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String? _extractReportNarrative(Map<String, dynamic> report) {
    final conclusion = report['conclusion']?.toString().trim();
    if (conclusion != null && conclusion.isNotEmpty) return conclusion;

    final conclusionCode = _conceptText(report['conclusionCode']);
    if (conclusionCode.isNotEmpty) return conclusionCode;

    final textObj = report['text'];
    if (textObj is Map && textObj['div'] != null) {
      final div = textObj['div'].toString();
      final cleanText = _stripHtml(div);
      if (cleanText.isNotEmpty) return cleanText;
    }

    final presentedForm = report['presentedForm'];
    if (presentedForm is List && presentedForm.isNotEmpty) {
      for (final form in presentedForm) {
        if (form is Map) {
          final data = form['data']?.toString().trim();
          if (data != null && data.isNotEmpty) {
            try {
              final decodedBytes = base64Decode(data);
              final decodedString = utf8.decode(decodedBytes).trim();
              final clean = _stripHtml(decodedString);
              if (clean.isNotEmpty) return clean;
            } catch (_) {}
          }
          final title = form['title']?.toString().trim();
          if (title != null && title.isNotEmpty) return title;
        }
      }
    }

    return null;
  }

  Map<String, String> _extractPanelInfoFromReport(Map<String, dynamic> report) {
    final name = _conceptText(report['code']);
    final code = _conceptCode(report['code']);
    final panelId = report['id']?.toString() ?? 'report-${name.hashCode}';
    final panelName = name.isNotEmpty ? name : 'Diagnostic Report';
    final effectiveDateTime =
        (report['effectiveDateTime'] ??
                (report['effectivePeriod'] is Map
                    ? report['effectivePeriod']['start']
                    : null) ??
                report['issued'] ??
                (report['meta'] is Map ? report['meta']['lastUpdated'] : null))
            ?.toString();
    final status = report['status']?.toString();
    final conclusion = _extractReportNarrative(report);
    final performer = _performerText(report['performer']);

    return <String, String>{
      'id': panelId,
      'name': panelName,
      'code': ?code,
      'status': ?status,
      'effectiveDateTime': ?effectiveDateTime,
      'performer': ?performer,
      'conclusion': ?conclusion,
    };
  }

  HealthRecord? _parseDiagnosticReportRecord(
    Map<String, dynamic> report, {
    required String source,
    required String sourceId,
    required String idPrefix,
    Map<String, String>? panelInfo,
  }) {
    final status = report['status']?.toString();
    if (status == 'entered-in-error' || status == 'cancelled') return null;

    final info = panelInfo ?? _extractPanelInfoFromReport(report);
    final rawDate =
        info['effectiveDateTime'] ??
        report['effectiveDateTime']?.toString() ??
        (report['effectivePeriod'] is Map
            ? report['effectivePeriod']['start']?.toString()
            : null) ??
        report['issued']?.toString() ??
        (report['meta'] is Map
            ? (report['meta'] as Map)['lastUpdated']?.toString()
            : null);
    final recordedAt =
        (rawDate != null ? _parseFhirDate(rawDate) : null) ??
        DateTime.now().toUtc();

    final id = report['id']?.toString() ?? 'report-${info['name'].hashCode}';
    final narrative = _extractReportNarrative(report);
    final value = (narrative != null && narrative.isNotEmpty)
        ? narrative
        : (status != null && status.isNotEmpty
              ? 'Status: $status'
              : 'Completed');

    // Extract longer narrative for notes if text.div or presentedForm has extra content
    String? fullNarrative;
    final textObj = report['text'];
    if (textObj is Map && textObj['div'] != null) {
      final cleanText = _stripHtml(textObj['div'].toString());
      if (cleanText.isNotEmpty && cleanText != value) {
        fullNarrative = cleanText;
      }
    }

    final sourceData = Map<String, Object?>.from(report);
    sourceData['panel'] = info;

    return HealthRecord(
      id: '$idPrefix:$sourceId:$id',
      name: info['name'] ?? 'Diagnostic Report',
      value: value,
      unit: '',
      recordedAt: recordedAt,
      category: RecordCategory.lab,
      source: source,
      sourceId: sourceId,
      code: info['code'],
      status: status,
      notes:
          fullNarrative ??
          _notesText(report['presentedForm']) ??
          _notesText(report['note']),
      sourceData: sourceData,
    );
  }

  Map<String, Map<String, String>> _extractPanelMappings(List<dynamic> items) {
    final panelMap = <String, Map<String, String>>{};

    for (final item in items) {
      Map<String, dynamic>? resource;
      if (item is Map) {
        if (item['resource'] is Map) {
          resource = Map<String, dynamic>.from(item['resource'] as Map);
        } else {
          resource = Map<String, dynamic>.from(item);
        }
      }
      if (resource == null) continue;

      final resourceType = resource['resourceType']?.toString();
      if (resourceType == 'DiagnosticReport') {
        final panelInfo = _extractPanelInfoFromReport(resource);
        final panelId = panelInfo['id']!;
        _registerPanelRef(panelMap, panelId, panelInfo);
        _registerPanelRef(panelMap, 'DiagnosticReport/$panelId', panelInfo);

        final results = resource['result'];
        if (results is List) {
          for (final resRef in results) {
            if (resRef is Map) {
              final ref = resRef['reference']?.toString();
              if (ref != null && ref.isNotEmpty) {
                _registerPanelRef(panelMap, ref, panelInfo);
              }
            }
          }
        }

        final contained = resource['contained'];
        if (contained is List) {
          for (final c in contained) {
            if (c is Map && c['id'] != null) {
              final cId = c['id'].toString();
              _registerPanelRef(panelMap, cId, panelInfo);
              _registerPanelRef(panelMap, '#$cId', panelInfo);
              _registerPanelRef(panelMap, 'Observation/$cId', panelInfo);
            }
          }
        }
      } else if (resourceType == 'Observation') {
        final hasMember = resource['hasMember'];
        if (hasMember is List && hasMember.isNotEmpty) {
          final name = _conceptText(resource['code']);
          final code = _conceptCode(resource['code']);
          final panelId =
              resource['id']?.toString() ?? 'panel-${name.hashCode}';
          final panelName = name.isNotEmpty ? name : 'Observation Panel';
          final performer = _performerText(resource['performer']);
          final panelInfo = <String, String>{
            'id': panelId,
            'name': panelName,
            'code': ?code,
            'status': ?resource['status']?.toString(),
            'performer': ?performer,
          };
          _registerPanelRef(panelMap, panelId, panelInfo);
          _registerPanelRef(panelMap, 'Observation/$panelId', panelInfo);

          for (final memberRef in hasMember) {
            if (memberRef is Map) {
              final ref = memberRef['reference']?.toString();
              if (ref != null && ref.isNotEmpty) {
                _registerPanelRef(panelMap, ref, panelInfo);
              }
            }
          }
        }
      }
    }

    return panelMap;
  }

  void _registerPanelRef(
    Map<String, Map<String, String>> panelMap,
    String ref,
    Map<String, String> panelInfo,
  ) {
    panelMap[ref] = panelInfo;
    if (ref.startsWith('#')) {
      panelMap[ref.substring(1)] = panelInfo;
    }
    if (ref.startsWith('Observation/')) {
      panelMap[ref.substring('Observation/'.length)] = panelInfo;
    }
    if (ref.startsWith('DiagnosticReport/')) {
      panelMap[ref.substring('DiagnosticReport/'.length)] = panelInfo;
    }
    if (ref.startsWith('urn:uuid:')) {
      panelMap[ref.substring('urn:uuid:'.length)] = panelInfo;
    }
  }

  Map<String, String>? _resolvePanelForObservation(
    Map<String, dynamic> observation,
    Map<String, Map<String, String>> panelMappings,
  ) {
    final id = observation['id']?.toString();
    if (id != null) {
      final direct =
          panelMappings[id] ??
          panelMappings['Observation/$id'] ??
          panelMappings['#$id'] ??
          panelMappings['urn:uuid:$id'];
      if (direct != null) return direct;
    }

    final partOf = observation['partOf'];
    if (partOf is List) {
      for (final refObj in partOf) {
        if (refObj is Map) {
          final ref = refObj['reference']?.toString();
          if (ref != null && panelMappings.containsKey(ref)) {
            return panelMappings[ref];
          }
        }
      }
    }

    final basedOn = observation['basedOn'];
    if (basedOn is List) {
      for (final refObj in basedOn) {
        if (refObj is Map) {
          final ref = refObj['reference']?.toString();
          if (ref != null && panelMappings.containsKey(ref)) {
            return panelMappings[ref];
          }
        }
      }
    }

    return null;
  }
}
