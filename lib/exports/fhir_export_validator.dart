import '../models/health_record.dart';

/// Severity of a FHIR preflight validation issue.
enum FhirIssueSeverity {
  error('Error'),
  warning('Warning'),
  info('Notice');

  const FhirIssueSeverity(this.label);
  final String label;
}

/// A specific validation check or limitation reported during FHIR preflight review.
class FhirPreflightIssue {
  const FhirPreflightIssue({
    required this.severity,
    required this.message,
    this.resourceType,
    this.resourceId,
    this.field,
  });

  final FhirIssueSeverity severity;
  final String message;
  final String? resourceType;
  final String? resourceId;
  final String? field;

  bool get isError => severity == FhirIssueSeverity.error;
  bool get isWarning => severity == FhirIssueSeverity.warning;
  bool get isInfo => severity == FhirIssueSeverity.info;
}

/// Summary report produced by preflight validation of an exported FHIR Bundle.
class FhirPreflightReport {
  const FhirPreflightReport({
    this.targetProfile = 'HL7 FHIR Release 4 (R4 v4.0.1)',
    required this.totalResources,
    required this.resourceCounts,
    required this.issues,
  });

  final String targetProfile;
  final int totalResources;
  final Map<String, int> resourceCounts;
  final List<FhirPreflightIssue> issues;

  List<FhirPreflightIssue> get errors =>
      issues.where((i) => i.isError).toList();

  List<FhirPreflightIssue> get warnings =>
      issues.where((i) => i.isWarning).toList();

  List<FhirPreflightIssue> get infos => issues.where((i) => i.isInfo).toList();

  bool get canExport => errors.isEmpty;
  bool get hasWarnings => warnings.isNotEmpty;
  bool get hasIssues => issues.isNotEmpty;
}

/// Local preflight validator evaluating FHIR Bundles against HL7 FHIR R4 (v4.0.1)
/// structural rules and terminology conventions before sharing.
class FhirExportValidator {
  const FhirExportValidator();

  static const String defaultProfile = 'HL7 FHIR Release 4 (R4 v4.0.1)';

  static const Set<String> _validObservationStatuses = {
    'registered',
    'preliminary',
    'final',
    'amended',
    'corrected',
    'cancelled',
    'entered-in-error',
    'unknown',
  };

  static const Set<String> _validMedicationStatuses = {
    'active',
    'completed',
    'entered-in-error',
    'intended',
    'stopped',
    'on-hold',
    'unknown',
    'not-taken',
  };

  FhirPreflightReport validateBundle(
    Map<String, Object?> bundle, {
    List<HealthRecord>? records,
  }) {
    final issues = <FhirPreflightIssue>[];
    final counts = <String, int>{};

    // 1. Validate Bundle envelope
    if (bundle['resourceType'] != 'Bundle') {
      issues.add(
        const FhirPreflightIssue(
          severity: FhirIssueSeverity.error,
          message: "Root resource must declare resourceType 'Bundle'.",
          field: 'resourceType',
        ),
      );
    }

    final bundleType = bundle['type'];
    if (bundleType is! String || bundleType.isEmpty) {
      issues.add(
        const FhirPreflightIssue(
          severity: FhirIssueSeverity.error,
          message: "Bundle must declare a valid 'type' (e.g. 'collection').",
          field: 'type',
        ),
      );
    }

    final rawEntries = bundle['entry'];
    if (rawEntries is! List) {
      issues.add(
        const FhirPreflightIssue(
          severity: FhirIssueSeverity.error,
          message: "Bundle does not contain a valid 'entry' list.",
          field: 'entry',
        ),
      );
      return FhirPreflightReport(
        totalResources: 0,
        resourceCounts: counts,
        issues: issues,
      );
    }

    if (rawEntries.isEmpty) {
      issues.add(
        const FhirPreflightIssue(
          severity: FhirIssueSeverity.warning,
          message:
              'Bundle entry list is empty; no health resources will be exported.',
          field: 'entry',
        ),
      );
    }

    // 2. Validate individual resources
    for (var index = 0; index < rawEntries.length; index++) {
      final entry = rawEntries[index];
      if (entry is! Map) {
        issues.add(
          FhirPreflightIssue(
            severity: FhirIssueSeverity.error,
            message: 'Bundle entry at index $index is not a valid JSON object.',
            field: 'entry[$index]',
          ),
        );
        continue;
      }

      final resource = entry['resource'];
      if (resource is! Map) {
        issues.add(
          FhirPreflightIssue(
            severity: FhirIssueSeverity.error,
            message:
                'Bundle entry at index $index is missing a resource object.',
            field: 'entry[$index].resource',
          ),
        );
        continue;
      }

      final rMap = Map<String, Object?>.from(resource);
      final rType = rMap['resourceType']?.toString() ?? '';
      final rId = rMap['id']?.toString() ?? '';

      if (rType.isEmpty) {
        issues.add(
          FhirPreflightIssue(
            severity: FhirIssueSeverity.error,
            message:
                'Resource at index $index is missing a declared resourceType.',
            field: 'entry[$index].resource.resourceType',
          ),
        );
        continue;
      }

      counts[rType] = (counts[rType] ?? 0) + 1;

      if (rId.isEmpty) {
        issues.add(
          FhirPreflightIssue(
            severity: FhirIssueSeverity.error,
            resourceType: rType,
            message:
                "Resource '$rType' at index $index is missing a required 'id'.",
            field: 'id',
          ),
        );
      }

      switch (rType) {
        case 'Observation':
          _validateObservation(rMap, issues);
          break;
        case 'MedicationStatement':
        case 'MedicationRequest':
          _validateMedication(rMap, rType, issues);
          break;
        case 'Condition':
          _validateCondition(rMap, issues);
          break;
        case 'AllergyIntolerance':
          _validateAllergy(rMap, issues);
          break;
        case 'Immunization':
          _validateImmunization(rMap, issues);
          break;
        default:
          // Valid custom or supported FHIR resource type
          break;
      }
    }

    return FhirPreflightReport(
      totalResources: rawEntries.length,
      resourceCounts: counts,
      issues: issues,
    );
  }

  void _validateObservation(
    Map<String, Object?> res,
    List<FhirPreflightIssue> issues,
  ) {
    final id = res['id']?.toString() ?? 'unknown';
    final status = res['status']?.toString().toLowerCase();

    if (status == null || status.isEmpty) {
      issues.add(
        FhirPreflightIssue(
          severity: FhirIssueSeverity.error,
          resourceType: 'Observation',
          resourceId: id,
          field: 'status',
          message: "Observation '$id' is missing a required status.",
        ),
      );
    } else if (!_validObservationStatuses.contains(status)) {
      issues.add(
        FhirPreflightIssue(
          severity: FhirIssueSeverity.warning,
          resourceType: 'Observation',
          resourceId: id,
          field: 'status',
          message: "Observation '$id' has non-standard status '$status'.",
        ),
      );
    }

    final code = res['code'];
    String recordLabel = id;
    if (code is Map) {
      final codeText = code['text']?.toString() ?? '';
      if (codeText.isNotEmpty) recordLabel = codeText;

      final codings = code['coding'];
      var hasStandardCoding = false;
      if (codings is List && codings.isNotEmpty) {
        for (final c in codings) {
          if (c is Map) {
            final sys = c['system']?.toString() ?? '';
            if (sys.contains('loinc.org') || sys.contains('snomed.info')) {
              hasStandardCoding = true;
              break;
            }
          }
        }
      }
      if (!hasStandardCoding) {
        issues.add(
          FhirPreflightIssue(
            severity: FhirIssueSeverity.info,
            resourceType: 'Observation',
            resourceId: id,
            field: 'code',
            message:
                "Observation '$recordLabel' relies on text display without standard LOINC or SNOMED terminology code.",
          ),
        );
      }
    } else {
      issues.add(
        FhirPreflightIssue(
          severity: FhirIssueSeverity.error,
          resourceType: 'Observation',
          resourceId: id,
          field: 'code',
          message: "Observation '$id' is missing a required 'code'.",
        ),
      );
    }

    final effective = res['effectiveDateTime'] ?? res['effectivePeriod'];
    if (effective == null) {
      issues.add(
        FhirPreflightIssue(
          severity: FhirIssueSeverity.warning,
          resourceType: 'Observation',
          resourceId: id,
          field: 'effectiveDateTime',
          message:
              "Observation '$recordLabel' is missing an effective date/time.",
        ),
      );
    }

    // Check value
    final hasVal =
        res['valueQuantity'] != null ||
        res['valueString'] != null ||
        res['valueCodeableConcept'] != null ||
        res['component'] != null;

    if (!hasVal) {
      issues.add(
        FhirPreflightIssue(
          severity: FhirIssueSeverity.info,
          resourceType: 'Observation',
          resourceId: id,
          field: 'value',
          message:
              "Observation '$recordLabel' contains no valueQuantity or valueString.",
        ),
      );
    }

    final vq = res['valueQuantity'];
    if (vq is Map) {
      final unit = vq['unit']?.toString() ?? '';
      final codeVal = vq['code']?.toString() ?? '';
      final sys = vq['system']?.toString() ?? '';
      if (unit.isNotEmpty &&
          (!sys.contains('unitsofmeasure.org') || codeVal.isEmpty)) {
        issues.add(
          FhirPreflightIssue(
            severity: FhirIssueSeverity.info,
            resourceType: 'Observation',
            resourceId: id,
            field: 'valueQuantity.code',
            message:
                "Observation '$recordLabel' unit '$unit' is not mapped to a standard UCUM unit code.",
          ),
        );
      }
    }
  }

  void _validateMedication(
    Map<String, Object?> res,
    String resourceType,
    List<FhirPreflightIssue> issues,
  ) {
    final id = res['id']?.toString() ?? 'unknown';
    final status = res['status']?.toString().toLowerCase();

    if (status != null && !_validMedicationStatuses.contains(status)) {
      issues.add(
        FhirPreflightIssue(
          severity: FhirIssueSeverity.warning,
          resourceType: resourceType,
          resourceId: id,
          field: 'status',
          message: "$resourceType '$id' has non-standard status '$status'.",
        ),
      );
    }

    final hasConcept =
        res['medicationCodeableConcept'] != null ||
        res['medicationReference'] != null;
    if (!hasConcept) {
      issues.add(
        FhirPreflightIssue(
          severity: FhirIssueSeverity.error,
          resourceType: resourceType,
          resourceId: id,
          field: 'medicationCodeableConcept',
          message:
              "$resourceType '$id' is missing a medication code or reference.",
        ),
      );
    }
  }

  void _validateCondition(
    Map<String, Object?> res,
    List<FhirPreflightIssue> issues,
  ) {
    final id = res['id']?.toString() ?? 'unknown';
    if (res['code'] == null) {
      issues.add(
        FhirPreflightIssue(
          severity: FhirIssueSeverity.error,
          resourceType: 'Condition',
          resourceId: id,
          field: 'code',
          message: "Condition '$id' is missing a diagnostic code.",
        ),
      );
    }
  }

  void _validateAllergy(
    Map<String, Object?> res,
    List<FhirPreflightIssue> issues,
  ) {
    final id = res['id']?.toString() ?? 'unknown';
    if (res['code'] == null) {
      issues.add(
        FhirPreflightIssue(
          severity: FhirIssueSeverity.error,
          resourceType: 'AllergyIntolerance',
          resourceId: id,
          field: 'code',
          message: "AllergyIntolerance '$id' is missing an allergen code.",
        ),
      );
    }
  }

  void _validateImmunization(
    Map<String, Object?> res,
    List<FhirPreflightIssue> issues,
  ) {
    final id = res['id']?.toString() ?? 'unknown';
    if (res['vaccineCode'] == null) {
      issues.add(
        FhirPreflightIssue(
          severity: FhirIssueSeverity.error,
          resourceType: 'Immunization',
          resourceId: id,
          field: 'vaccineCode',
          message: "Immunization '$id' is missing a vaccineCode.",
        ),
      );
    }
  }
}
