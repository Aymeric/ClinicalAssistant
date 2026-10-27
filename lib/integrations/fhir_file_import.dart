import 'dart:convert';

import 'package:file_picker/file_picker.dart';

import '../models/health_record.dart';
import 'fhir_observation_parser.dart';

/// Represents the raw payload of a selected or pasted FHIR file.
class FhirFilePayload {
  const FhirFilePayload({
    required this.name,
    required this.content,
    this.sizeInBytes,
  });

  final String name;
  final String content;
  final int? sizeInBytes;

  String get formattedSize {
    if (sizeInBytes == null) {
      final bytes = utf8.encode(content).length;
      return _formatBytes(bytes);
    }
    return _formatBytes(sizeInBytes!);
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// Inspection and validation preview of a single FHIR file.
class FhirFilePreview {
  const FhirFilePreview({
    required this.fileName,
    required this.records,
    required this.resourceCounts,
    this.sizeInBytes,
    this.error,
  });

  final String fileName;
  final int? sizeInBytes;
  final List<HealthRecord> records;
  final Map<String, int> resourceCounts;
  final String? error;

  bool get isValid => error == null && records.isNotEmpty;

  String get formattedSize {
    if (sizeInBytes == null) return '';
    if (sizeInBytes! < 1024) return '$sizeInBytes B';
    if (sizeInBytes! < 1024 * 1024) {
      return '${(sizeInBytes! / 1024).toStringAsFixed(1)} KB';
    }
    return '${(sizeInBytes! / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// Parses a [payload] and constructs a preview of its valid FHIR resources or error.
  factory FhirFilePreview.fromPayload(
    FhirFilePayload payload, {
    FhirObservationParser parser = const FhirObservationParser(),
  }) {
    if (payload.content.trim().isEmpty) {
      return FhirFilePreview(
        fileName: payload.name,
        sizeInBytes: payload.sizeInBytes,
        records: const [],
        resourceCounts: const {},
        error: 'File is empty.',
      );
    }

    try {
      final records = parser.parseJson(
        payload.content,
        source: payload.name,
        sourceId: payload.name,
        idPrefix: 'fhir-file',
      );

      if (records.isEmpty) {
        return FhirFilePreview(
          fileName: payload.name,
          sizeInBytes: payload.sizeInBytes,
          records: const [],
          resourceCounts: const {},
          error:
              'No supported clinical resources (Observations, Medications, Conditions, Allergies, Immunizations) were found.',
        );
      }

      final counts = <String, int>{};
      for (final record in records) {
        final resourceType =
            record.sourceData?['resourceType']?.toString() ??
            switch (record.category) {
              RecordCategory.medication => 'MedicationStatement',
              RecordCategory.condition => 'Condition',
              RecordCategory.allergy => 'AllergyIntolerance',
              RecordCategory.immunization => 'Immunization',
              _ => 'Observation',
            };
        counts[resourceType] = (counts[resourceType] ?? 0) + 1;
      }

      return FhirFilePreview(
        fileName: payload.name,
        sizeInBytes: payload.sizeInBytes,
        records: records,
        resourceCounts: counts,
      );
    } catch (e) {
      final cleanMessage = e.toString().replaceFirst('FormatException: ', '');
      return FhirFilePreview(
        fileName: payload.name,
        sizeInBytes: payload.sizeInBytes,
        records: const [],
        resourceCounts: const {},
        error: cleanMessage,
      );
    }
  }
}

/// Aggregated preview across multiple FHIR files.
class FhirFilesImportSummary {
  const FhirFilesImportSummary({required this.previews});

  final List<FhirFilePreview> previews;

  int get totalFiles => previews.length;
  int get validFilesCount => previews.where((p) => p.isValid).length;
  int get totalRecords =>
      previews.fold(0, (sum, p) => sum + (p.isValid ? p.records.length : 0));
  bool get hasErrors => previews.any((p) => !p.isValid);
  bool get isEmpty => previews.isEmpty;

  List<HealthRecord> get allValidRecords =>
      previews.where((p) => p.isValid).expand((p) => p.records).toList();

  Map<String, int> get aggregatedResourceCounts {
    final aggregated = <String, int>{};
    for (final preview in previews) {
      if (!preview.isValid) continue;
      for (final entry in preview.resourceCounts.entries) {
        aggregated[entry.key] = (aggregated[entry.key] ?? 0) + entry.value;
      }
    }
    return aggregated;
  }

  factory FhirFilesImportSummary.fromPayloads(
    List<FhirFilePayload> payloads, {
    FhirObservationParser parser = const FhirObservationParser(),
  }) {
    final previews = payloads
        .map((p) => FhirFilePreview.fromPayload(p, parser: parser))
        .toList();
    return FhirFilesImportSummary(previews: previews);
  }
}

/// Service to pick local FHIR JSON files from disk or device storage.
class FhirFilePickerService {
  const FhirFilePickerService();

  /// Prompts the user to pick one or more `.json` or `.fhir` files.
  Future<List<FhirFilePayload>?> pickFiles({
    List<String> allowedExtensions = const ['json', 'fhir'],
  }) async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: allowedExtensions,
    );

    if (files.isEmpty) {
      return null;
    }

    final payloads = <FhirFilePayload>[];
    for (final file in files) {
      try {
        final bytes = await file.readAsBytes();
        final content = utf8.decode(bytes);
        final size = file.lengthSync() ?? bytes.length;
        payloads.add(
          FhirFilePayload(name: file.name, content: content, sizeInBytes: size),
        );
      } catch (_) {
        try {
          final content = await file.xFile.readAsString();
          payloads.add(
            FhirFilePayload(
              name: file.name,
              content: content,
              sizeInBytes: content.length,
            ),
          );
        } catch (_) {}
      }
    }

    return payloads.isEmpty ? null : payloads;
  }
}
