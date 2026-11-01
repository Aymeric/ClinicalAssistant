import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:flutter/material.dart' show DateTimeRange, DateUtils;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/clinical_panel.dart';
import '../models/coverage_details.dart';
import '../models/doctor_visit_preparation.dart';
import '../models/health_record.dart';
import '../models/manual_medication_details.dart';
import '../safety/critical_safety_evaluator.dart';
import '../trends/health_trend.dart';

class HealthExportService {
  static final _idSanitizer = RegExp(r'[^A-Za-z0-9.-]');

  Map<String, Object?> buildFhirBundle(
    List<HealthRecord> records, {
    bool? includeSourceData,
    bool? includeNotes,
  }) {
    final effectiveIncludeSourceData =
        includeSourceData ?? records.any((r) => r.sourceData != null);
    final effectiveIncludeNotes =
        includeNotes ??
        records.any((r) => r.notes != null && r.notes!.isNotEmpty);
    final bundle = {
      'resourceType': 'Bundle',
      'type': 'collection',
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'entry': records
          .map(
            (record) => {
              'resource': _resourceForRecord(
                record,
                includeSourceData: effectiveIncludeSourceData,
                includeNotes: effectiveIncludeNotes,
              ),
            },
          )
          .toList(),
    };
    return bundle;
  }

  Future<File> createFhirBundle(
    List<HealthRecord> records, {
    bool? includeSourceData,
    bool? includeNotes,
  }) async {
    return _writeExport(
      'health-records.fhir.json',
      const JsonEncoder.withIndent('  ').convert(
        buildFhirBundle(
          records,
          includeSourceData: includeSourceData,
          includeNotes: includeNotes,
        ),
      ),
    );
  }

  static final _csvFormulaTrigger = RegExp(r'^\s*[=+\-@\t\r]');

  /// Sanitizes CSV cell values to prevent CSV / Formula Injection attacks when exported
  /// data is opened in spreadsheet software (e.g. Excel, Calc, Google Sheets).
  static String _sanitizeCsvCell(String value) {
    if (value.isEmpty) return value;
    final trimmed = value.trimLeft();
    if (_csvFormulaTrigger.hasMatch(value)) {
      // Allow legitimate negative numbers (e.g., -12.5) without prefixing
      if (trimmed.startsWith('-') && double.tryParse(trimmed) != null) {
        return value;
      }
      return "'$value";
    }
    return value;
  }

  String buildCsv(
    List<HealthRecord> records, {
    bool? includeSourceData,
    bool? includeNotes,
  }) {
    final effectiveIncludeSourceData =
        includeSourceData ?? records.any((r) => r.sourceData != null);
    final effectiveIncludeNotes =
        includeNotes ??
        records.any((r) => r.notes != null && r.notes!.isNotEmpty);
    final rows = <List<Object?>>[
      [
        'Name',
        'Value',
        'Unit',
        'Recorded at (UTC)',
        'Category',
        'Source',
        'Source ID',
        'Code',
        'Reference range',
        'Status',
        if (effectiveIncludeNotes) 'Notes',
        if (effectiveIncludeSourceData) 'Source data (JSON)',
      ],
      ...records.map(
        (record) => [
          _sanitizeCsvCell(record.name),
          _sanitizeCsvCell(record.value),
          _sanitizeCsvCell(record.unit),
          record.recordedAt.toUtc().toIso8601String(),
          record.category.name,
          _sanitizeCsvCell(record.source),
          _sanitizeCsvCell(record.sourceId ?? ''),
          _sanitizeCsvCell(record.code ?? ''),
          _sanitizeCsvCell(record.referenceRange ?? ''),
          _sanitizeCsvCell(record.status ?? ''),
          if (effectiveIncludeNotes) _sanitizeCsvCell(record.notes ?? ''),
          if (effectiveIncludeSourceData)
            if (record.sourceData == null)
              ''
            else
              jsonEncode(record.sourceData),
        ],
      ),
    ];
    return const CsvEncoder().convert(rows);
  }

  Future<File> createCsv(
    List<HealthRecord> records, {
    bool? includeSourceData,
    bool? includeNotes,
  }) async {
    return _writeExport(
      'health-records.csv',
      buildCsv(
        records,
        includeSourceData: includeSourceData,
        includeNotes: includeNotes,
      ),
    );
  }

  String buildTextSummary(List<HealthRecord> records, {bool? includeNotes}) {
    final effectiveIncludeNotes =
        includeNotes ??
        records.any((r) => r.notes != null && r.notes!.isNotEmpty);
    final buffer = StringBuffer();
    buffer.writeln('ClinicalAssistant Health Records Summary');
    buffer.writeln(
      'Exported (UTC): ${DateTime.now().toUtc().toIso8601String().split('T').first}',
    );
    buffer.writeln('Total records: ${records.length}');

    if (records.isEmpty) {
      buffer.writeln('\nNo records available to export.');
      return buffer.toString();
    }

    final dates = records.map((r) => r.recordedAt).toList()..sort();
    final firstDate = _formatDate(dates.first);
    final lastDate = _formatDate(dates.last);
    buffer.writeln('Date span: $firstDate to $lastDate');

    final sources = records.map((r) => r.source).toSet().join(', ');
    buffer.writeln('Sources: $sources');
    buffer.writeln(
      '\nNotice: This summary contains health records from the listed sources and manually entered records. '
      'It is not a medical interpretation or a substitute for advice from a clinician.\n',
    );

    final byCategory = <RecordCategory, List<HealthRecord>>{};
    for (final record in records) {
      byCategory.putIfAbsent(record.category, () => []).add(record);
    }

    for (final category in RecordCategory.values) {
      final categoryRecords = byCategory[category];
      if (categoryRecords == null || categoryRecords.isEmpty) continue;
      categoryRecords.sort((a, b) => b.recordedAt.compareTo(a.recordedAt));

      final categoryTitle = switch (category) {
        RecordCategory.lab => 'Laboratory Results',
        RecordCategory.vital => 'Vital Signs',
        RecordCategory.activity => 'Activity & Fitness',
        RecordCategory.sleep => 'Sleep',
        RecordCategory.nutrition => 'Nutrition',
        RecordCategory.cycleTracking => 'Cycle Tracking',
        RecordCategory.medication => 'Medications',
        RecordCategory.condition => 'Conditions & Diagnoses',
        RecordCategory.allergy => 'Allergies & Intolerances',
        RecordCategory.immunization => 'Immunizations',
        RecordCategory.coverage => 'Insurance & Health Plan Coverage',
      };

      buffer.writeln('--- $categoryTitle (${categoryRecords.length}) ---');
      for (final r in categoryRecords) {
        final date = _formatDate(r.recordedAt);
        final ref = r.referenceRange != null
            ? ' [Ref: ${r.referenceRange}]'
            : '';
        buffer.writeln(
          '• $date: ${r.name} = ${_medicationInstructions(r)}$ref (${r.source})',
        );
        if (effectiveIncludeNotes && r.notes != null && r.notes!.isNotEmpty) {
          buffer.writeln('  Note: ${r.notes}');
        }
      }
      buffer.writeln();
    }

    return buffer.toString();
  }

  Future<File> createTextSummary(
    List<HealthRecord> records, {
    bool? includeNotes,
  }) async {
    return _writeExport(
      'health-records-summary.txt',
      buildTextSummary(records, includeNotes: includeNotes),
    );
  }

  Future<File> createPdf(
    List<HealthRecord> records, {
    bool? includeNotes,
  }) async {
    final effectiveIncludeNotes =
        includeNotes ??
        records.any((r) => r.notes != null && r.notes!.isNotEmpty);
    final pdf = pw.Document();
    final ordered = [...records]
      ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    final sources = ordered.map((r) => r.source).toSet().join(', ');
    final hasNotes =
        effectiveIncludeNotes &&
        ordered.any((r) => r.notes != null && r.notes!.isNotEmpty);
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 10),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'ClinicalAssistant • Personal health record copy',
                style: const pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.grey700,
                ),
              ),
              pw.Text(
                'Page ${context.pageNumber} of ${context.pagesCount}',
                style: const pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.grey700,
                ),
              ),
            ],
          ),
        ),
        build: (_) => [
          pw.Text(
            'Your health records',
            style: pw.TextStyle(
              fontSize: 24,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromHex('#183F46'),
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            'Exported ${DateTime.now().toUtc().toIso8601String().split('.').first} UTC · ${records.length} ${records.length == 1 ? 'record' : 'records'}${sources.isNotEmpty ? ' · Sources: $sources' : ''}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800),
          ),
          pw.SizedBox(height: 10),
          pw.Text(
            'This summary contains records imported from the sources listed below. '
            'It is not a medical interpretation or a substitute for advice from a clinician.',
            style: const pw.TextStyle(fontSize: 10),
          ),
          pw.SizedBox(height: 20),
          if (ordered.isEmpty)
            pw.Text('No records were available to export.')
          else
            pw.TableHelper.fromTextArray(
              headers: [
                'Date',
                'Record',
                'Value',
                'Reference range',
                'Source',
                if (hasNotes) 'Notes',
              ],
              data: ordered
                  .map(
                    (record) => [
                      _formatDate(record.recordedAt),
                      record.name,
                      record.displayValue,
                      record.referenceRange ?? '-',
                      record.source,
                      if (hasNotes) record.notes ?? '-',
                    ],
                  )
                  .toList(),
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
                fontSize: 9,
              ),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColor.fromInt(0xFF183F46),
              ),
              cellStyle: const pw.TextStyle(fontSize: 8),
              cellPadding: const pw.EdgeInsets.all(6),
              border: pw.TableBorder(
                horizontalInside: pw.BorderSide(
                  color: PdfColor.fromHex('#D8E2E1'),
                  width: 0.5,
                ),
              ),
            ),
        ],
      ),
    );

    final directory = await getTemporaryDirectory();
    final file = File(
      '${directory.path}/health-records-${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
    await file.writeAsBytes(await pdf.save(), flush: true);
    await _restrictFilePermissions(file);
    return file;
  }

  Future<pw.Document> buildDoctorVisitSummaryPdfDocument(
    List<HealthRecord> records, {
    DateTimeRange? dateRange,
    String? patientQuestions,
    bool includeVitals = true,
    bool includeLabs = true,
    bool includeMedications = true,
    bool includeConditions = true,
    bool includeAllergies = true,
    bool includeQuestions = true,
    DoctorVisitPreparationConfig? config,
  }) async {
    final pdf = pw.Document();

    final effectiveSpecialty =
        config?.specialty ?? DoctorVisitSpecialty.annualWellness;
    final effectiveDateRange = config?.dateRange ?? dateRange;
    final effectiveIncludeVitals = config?.includeVitals ?? includeVitals;
    final effectiveIncludeLabs = config?.includeLabs ?? includeLabs;
    final effectiveIncludeMedications =
        config?.includeMedications ?? includeMedications;
    final effectiveIncludeConditions =
        config?.includeConditions ?? includeConditions;
    final effectiveIncludeAllergies =
        config?.includeAllergies ?? includeAllergies;
    final effectiveIncludeQuestions = includeQuestions;

    var candidateRecords = records;
    if (config != null && config.selectedRecordIds.isNotEmpty) {
      final selected = records
          .where((r) => config.selectedRecordIds.contains(r.id))
          .toList();
      if (selected.isNotEmpty) {
        candidateRecords = selected;
      }
    }

    var filtered = candidateRecords;
    if (effectiveDateRange != null) {
      filtered = candidateRecords.where((r) {
        final d = DateUtils.dateOnly(r.recordedAt.toLocal());
        return !d.isBefore(effectiveDateRange.start) &&
            !d.isAfter(effectiveDateRange.end);
      }).toList();
    }
    final ordered = [...filtered]
      ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    final sources = ordered.map((r) => r.source).toSet().join(', ');

    // Group vitals
    final vitals = ordered
        .where((r) => r.category == RecordCategory.vital)
        .toList();
    final vitalSeries = <String, List<HealthRecord>>{};
    for (final v in vitals) {
      vitalSeries.putIfAbsent(v.name, () => []).add(v);
    }

    final latestLabSummaries = buildLatestLabResultSummaries(
      records,
      candidates: ordered.where(
        (record) => record.category == RecordCategory.lab,
      ),
    );
    final outOfRangeLabs = latestLabSummaries
        .where(
          (summary) =>
              summary.latestStatus == HealthReferenceStatus.above ||
              summary.latestStatus == HealthReferenceStatus.below,
        )
        .toList();
    final flaggedSeriesIds = outOfRangeLabs
        .map((summary) => healthTrendSeriesId(summary.latest.record))
        .toSet();
    final otherLabs =
        ordered
            .where(
              (record) =>
                  record.category == RecordCategory.lab &&
                  !flaggedSeriesIds.contains(healthTrendSeriesId(record)),
            )
            .toList()
          ..sort((a, b) {
            final dateCmp = b.recordedAt.compareTo(a.recordedAt);
            if (dateCmp != 0) return dateCmp;
            final aPanel = extractRecordPanelInfo(a)?.name ?? '';
            final bPanel = extractRecordPanelInfo(b)?.name ?? '';
            final panelCmp = aPanel.compareTo(bPanel);
            if (panelCmp != 0) return panelCmp;
            return a.name.compareTo(b.name);
          });

    final medications = ordered
        .where((r) => r.category == RecordCategory.medication)
        .toList();
    final conditions = ordered
        .where((r) => r.category == RecordCategory.condition)
        .toList();
    final allergies = ordered
        .where((r) => r.category == RecordCategory.allergy)
        .toList();
    final coverages = ordered
        .where((r) => r.category == RecordCategory.coverage)
        .toList();

    final summaryTitle = switch (effectiveSpecialty) {
      DoctorVisitSpecialty.cardiology => 'Cardiology Consultation Summary',
      DoctorVisitSpecialty.endocrinology =>
        'Endocrinology & Diabetes Consultation Summary',
      DoctorVisitSpecialty.annualWellness =>
        'Clinical Consultation Preparation Summary',
    };
    final specialtyHeaderColor = switch (effectiveSpecialty) {
      DoctorVisitSpecialty.cardiology => PdfColor.fromHex('#B71C1C'),
      DoctorVisitSpecialty.endocrinology => PdfColor.fromHex('#0D47A1'),
      DoctorVisitSpecialty.annualWellness => PdfColor.fromHex('#183F46'),
    };

    final subtitleItems = <String>[
      if (config != null) 'Appointment: ${_formatDate(config.visitDate)}',
      if (config?.clinicianName != null &&
          config!.clinicianName!.trim().isNotEmpty)
        'Clinician: ${config.clinicianName!.trim()}',
      if (config?.facilityName != null &&
          config!.facilityName!.trim().isNotEmpty)
        'Facility: ${config.facilityName!.trim()}',
      effectiveDateRange == null
          ? 'Period: All available records'
          : 'Period: ${_formatDate(effectiveDateRange.start)} to ${_formatDate(effectiveDateRange.end)}',
    ];

    // Helper to render out-of-range table
    pw.Widget buildOutOfRangeTable() {
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Currently Out-of-Range Lab Results (${outOfRangeLabs.length})',
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromHex('#B71C1C'),
            ),
          ),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            headers: const [
              'Date',
              'Lab Test',
              'Result / flag',
              'Reference range',
              'Previous result / trend',
              'Source',
            ],
            data: outOfRangeLabs.map((summary) {
              final record = summary.latest.record;
              final previous = summary.previous;
              final panelInfo = extractRecordPanelInfo(record);
              final testName = panelInfo != null
                  ? '${record.name} (${panelInfo.name})'
                  : record.name;
              final criticalAlert = CriticalSafetyEvaluator.evaluate(record);
              final flag = criticalAlert != null
                  ? 'CRITICAL'
                  : (summary.latestStatus == HealthReferenceStatus.above
                        ? 'HIGH'
                        : 'LOW');
              final previousContext = previous == null
                  ? 'No earlier comparable result'
                  : [
                      '${_formatDate(previous.record.recordedAt)}: ${previous.record.displayValue}',
                      'Ref: ${summary.previousRange?.sourceText ?? "unavailable"}',
                      summary.direction.label,
                    ].join('\n');
              return [
                _formatDate(record.recordedAt),
                testName,
                '${record.displayValue} ($flag)',
                (record.referenceRange ?? '-').replaceAll('–', '-'),
                previousContext,
                record.source,
              ];
            }).toList(),
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
              fontSize: 8,
            ),
            headerDecoration: const pw.BoxDecoration(
              color: PdfColor.fromInt(0xFFB71C1C),
            ),
            cellStyle: const pw.TextStyle(fontSize: 8),
            cellPadding: const pw.EdgeInsets.symmetric(
              horizontal: 5,
              vertical: 4,
            ),
            border: pw.TableBorder(
              horizontalInside: pw.BorderSide(
                color: PdfColor.fromHex('#E0E0E0'),
                width: 0.5,
              ),
            ),
          ),
          pw.SizedBox(height: 14),
        ],
      );
    }

    // Helper to render vitals summary table
    pw.Widget buildVitalsSummaryTable({String title = 'Vital Signs Summary'}) {
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: specialtyHeaderColor,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            headers: const [
              'Vital Sign',
              'Latest Reading',
              'Date',
              'Readings',
              'Average',
              'Min - Max',
            ],
            data: vitalSeries.entries.map((entry) {
              final name = entry.key;
              final list = entry.value;
              final latestRec = list.first;
              final unit = latestRec.unit;
              final numericValues = list
                  .map((r) => parseHealthRecordValue(r.value))
                  .whereType<double>()
                  .toList();

              String avgStr = '-';
              String minMaxStr = '-';
              if (numericValues.isNotEmpty) {
                final sum = numericValues.reduce((a, b) => a + b);
                final avg = sum / numericValues.length;
                avgStr = '${formatSensibleNumber(avg)} $unit'.trim();
                numericValues.sort();
                minMaxStr =
                    '${formatSensibleNumber(numericValues.first)} - ${formatSensibleNumber(numericValues.last)} $unit'
                        .trim();
              }

              final criticalAlert = CriticalSafetyEvaluator.evaluate(latestRec);
              final latestDisplay = criticalAlert != null
                  ? '${latestRec.displayValue} (CRITICAL)'
                  : latestRec.displayValue;

              return [
                name,
                latestDisplay,
                _formatDate(latestRec.recordedAt),
                list.length.toString(),
                avgStr,
                minMaxStr,
              ];
            }).toList(),
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
              fontSize: 8,
            ),
            headerDecoration: pw.BoxDecoration(color: specialtyHeaderColor),
            cellStyle: const pw.TextStyle(fontSize: 8),
            cellPadding: const pw.EdgeInsets.symmetric(
              horizontal: 5,
              vertical: 4,
            ),
            border: pw.TableBorder(
              horizontalInside: pw.BorderSide(
                color: PdfColor.fromHex('#D8E2E1'),
                width: 0.5,
              ),
            ),
          ),
          pw.SizedBox(height: 14),
        ],
      );
    }

    // Helper to render other labs table
    pw.Widget buildOtherLabsTable({
      String title = 'Other Lab Observations',
      List<HealthRecord>? customLabs,
    }) {
      final labsToRender = customLabs ?? otherLabs;
      if (labsToRender.isEmpty) return pw.SizedBox();
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            '$title (${labsToRender.take(14).length})',
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: specialtyHeaderColor,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            headers: const [
              'Date',
              'Lab Test',
              'Result',
              'Reference Range',
              'Source',
            ],
            data: labsToRender.take(14).map((record) {
              final panelInfo = extractRecordPanelInfo(record);
              final testName = panelInfo != null
                  ? '${record.name} (${panelInfo.name})'
                  : record.name;
              final criticalAlert = CriticalSafetyEvaluator.evaluate(record);
              final displayVal = criticalAlert != null
                  ? '${record.displayValue} (CRITICAL)'
                  : record.displayValue;
              return [
                _formatDate(record.recordedAt),
                testName,
                displayVal,
                (record.referenceRange ?? '-').replaceAll('–', '-'),
                record.source,
              ];
            }).toList(),
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
              fontSize: 8,
            ),
            headerDecoration: const pw.BoxDecoration(
              color: PdfColor.fromInt(0xFF37474F),
            ),
            cellStyle: const pw.TextStyle(fontSize: 8),
            cellPadding: const pw.EdgeInsets.symmetric(
              horizontal: 5,
              vertical: 4,
            ),
            border: pw.TableBorder(
              horizontalInside: pw.BorderSide(
                color: PdfColor.fromHex('#E0E0E0'),
                width: 0.5,
              ),
            ),
          ),
          pw.SizedBox(height: 14),
        ],
      );
    }

    // Helper to render medications table
    pw.Widget buildMedicationsTable() {
      if (medications.isEmpty) return pw.SizedBox();
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Reported Medications (${medications.take(12).length})',
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: specialtyHeaderColor,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            headers: const [
              'Medication',
              'Dosage & Schedule',
              'Status / Adherence',
              'Date / Source',
            ],
            data: medications.take(12).map((record) {
              final details = record.isManual
                  ? ManualMedicationDetails.fromRecord(record)
                  : null;
              var dosageSchedule = details != null
                  ? [
                      record.value,
                      details.frequency,
                      if (details.route != null) details.route!,
                    ].where((s) => s.isNotEmpty).join(' · ')
                  : record.displayValue;

              // Check if patient provided a note/question for this medication
              final patientNote =
                  config?.medicationNotes[record.name] ??
                  config?.medicationNotes[record.id];
              if (patientNote != null && patientNote.trim().isNotEmpty) {
                dosageSchedule =
                    '$dosageSchedule\n[Patient Note: ${patientNote.trim()}]';
              }

              final adherenceInfo =
                  details != null && details.adherenceLogs.isNotEmpty
                  ? '${record.status ?? "active"} (${details.adherenceLogs.length} doses logged)'
                  : (record.status ?? 'active');
              final dateSource =
                  '${_formatDate(record.recordedAt)}\n${record.source}';
              return [record.name, dosageSchedule, adherenceInfo, dateSource];
            }).toList(),
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
              fontSize: 8,
            ),
            headerDecoration: const pw.BoxDecoration(
              color: PdfColor.fromInt(0xFF4A148C),
            ),
            cellStyle: const pw.TextStyle(fontSize: 8),
            cellPadding: const pw.EdgeInsets.symmetric(
              horizontal: 5,
              vertical: 4,
            ),
            border: pw.TableBorder(
              horizontalInside: pw.BorderSide(
                color: PdfColor.fromHex('#E0E0E0'),
                width: 0.5,
              ),
            ),
          ),
          pw.SizedBox(height: 14),
        ],
      );
    }

    // Helper to render conditions table
    pw.Widget buildConditionsTable() {
      if (conditions.isEmpty) return pw.SizedBox();
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Recorded Conditions & Diagnoses (${conditions.take(10).length})',
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: specialtyHeaderColor,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            headers: const [
              'Condition / Diagnosis',
              'Status',
              'Date',
              'Source',
            ],
            data: conditions
                .take(10)
                .map(
                  (record) => [
                    record.name,
                    record.displayValue,
                    _formatDate(record.recordedAt),
                    record.source,
                  ],
                )
                .toList(),
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
              fontSize: 8,
            ),
            headerDecoration: const pw.BoxDecoration(
              color: PdfColor.fromInt(0xFFE65100),
            ),
            cellStyle: const pw.TextStyle(fontSize: 8),
            cellPadding: const pw.EdgeInsets.symmetric(
              horizontal: 5,
              vertical: 4,
            ),
            border: pw.TableBorder(
              horizontalInside: pw.BorderSide(
                color: PdfColor.fromHex('#E0E0E0'),
                width: 0.5,
              ),
            ),
          ),
          pw.SizedBox(height: 14),
        ],
      );
    }

    // Helper to render allergies table
    pw.Widget buildAllergiesTable() {
      if (allergies.isEmpty) return pw.SizedBox();
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Known Allergies & Intolerances (${allergies.take(10).length})',
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: specialtyHeaderColor,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            headers: const [
              'Allergen / Substance',
              'Reaction / Severity',
              'Date',
              'Source',
            ],
            data: allergies
                .take(10)
                .map(
                  (record) => [
                    record.name,
                    record.displayValue,
                    _formatDate(record.recordedAt),
                    record.source,
                  ],
                )
                .toList(),
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
              fontSize: 8,
            ),
            headerDecoration: const pw.BoxDecoration(
              color: PdfColor.fromInt(0xFFC2185B),
            ),
            cellStyle: const pw.TextStyle(fontSize: 8),
            cellPadding: const pw.EdgeInsets.symmetric(
              horizontal: 5,
              vertical: 4,
            ),
            border: pw.TableBorder(
              horizontalInside: pw.BorderSide(
                color: PdfColor.fromHex('#E0E0E0'),
                width: 0.5,
              ),
            ),
          ),
          pw.SizedBox(height: 14),
        ],
      );
    }

    // Helper to render insurance coverage table
    pw.Widget buildCoverageTable() {
      if (coverages.isEmpty) return pw.SizedBox();
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Health Insurance & Coverage (${coverages.take(5).length})',
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: specialtyHeaderColor,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            headers: const [
              'Payer / Insurer',
              'Plan & Group',
              'Subscriber ID',
              'Status',
              'Copays / Cost Sharing',
            ],
            data: coverages.take(5).map((record) {
              final cov = CoverageDetails.fromRecord(record);
              final payer = cov?.payorName.isNotEmpty == true
                  ? cov!.payorName
                  : record.name;
              final planGroup = [
                if (cov?.planName != null) cov!.planName!,
                if (cov?.groupNumber != null) 'Grp: ${cov!.groupNumber!}',
              ].join('\n');
              final subId = cov?.subscriberId ?? '-';
              final status = cov?.status != null
                  ? cov!.status!.toUpperCase()
                  : (record.status ?? 'ACTIVE').toUpperCase();
              final copayText = cov != null && cov.copays.isNotEmpty
                  ? cov.copays.map((c) => '${c.type}: ${c.amount}').join(', ')
                  : '-';

              return [
                payer,
                planGroup.isNotEmpty ? planGroup : '-',
                subId,
                status,
                copayText,
              ];
            }).toList(),
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
              fontSize: 8,
            ),
            headerDecoration: const pw.BoxDecoration(
              color: PdfColor.fromInt(0xFF00695C),
            ),
            cellStyle: const pw.TextStyle(fontSize: 8),
            cellPadding: const pw.EdgeInsets.symmetric(
              horizontal: 5,
              vertical: 4,
            ),
            border: pw.TableBorder(
              horizontalInside: pw.BorderSide(
                color: PdfColor.fromHex('#E0E0E0'),
                width: 0.5,
              ),
            ),
          ),
          pw.SizedBox(height: 14),
        ],
      );
    }

    // Helper to render patient discussion topics / agenda
    pw.Widget buildQuestionsSection() {
      final combinedAgenda = <String>[
        if (config != null) ...config.agendaItems,
        if (patientQuestions != null && patientQuestions.trim().isNotEmpty)
          patientQuestions.trim(),
      ];

      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Patient Discussion Topics & Questions',
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: specialtyHeaderColor,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(
                color: PdfColor.fromHex('#9E9E9E'),
                width: 0.8,
              ),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: combinedAgenda.isNotEmpty
                ? pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < combinedAgenda.length; i++) ...[
                        pw.Text(
                          '${i + 1}. ${combinedAgenda[i]}',
                          style: const pw.TextStyle(fontSize: 9),
                        ),
                        if (i < combinedAgenda.length - 1)
                          pw.SizedBox(height: 4),
                      ],
                      pw.SizedBox(height: 10),
                      pw.Text(
                        'Clinician Notes / Plan:',
                        style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey700,
                        ),
                      ),
                      pw.SizedBox(height: 18),
                    ],
                  )
                : pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        '1. __________________________________________________________________________',
                        style: const pw.TextStyle(
                          fontSize: 9,
                          color: PdfColors.grey600,
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text(
                        '2. __________________________________________________________________________',
                        style: const pw.TextStyle(
                          fontSize: 9,
                          color: PdfColors.grey600,
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text(
                        '3. __________________________________________________________________________',
                        style: const pw.TextStyle(
                          fontSize: 9,
                          color: PdfColors.grey600,
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      );
    }

    // Helper for Cardiology: Lipid Panel & Cardiovascular Labs
    pw.Widget buildCardiologyLipidsSection() {
      final lipidLabs = ordered.where((r) {
        if (r.category != RecordCategory.lab) return false;
        final name = r.name.toLowerCase();
        return name.contains('cholesterol') ||
            name.contains('ldl') ||
            name.contains('hdl') ||
            name.contains('triglyceride') ||
            name.contains('crp') ||
            name.contains('apob') ||
            name.contains('bnp') ||
            name.contains('troponin');
      }).toList();

      if (lipidLabs.isEmpty) return pw.SizedBox();
      return buildOtherLabsTable(
        title: 'Lipid Panel & Cardiovascular Markers',
        customLabs: lipidLabs,
      );
    }

    // Helper for Endocrinology: Glycemic Control & Glucose Log
    pw.Widget buildEndocrinologyGlucoseSection() {
      final glucoseRecords = ordered.where((r) {
        final name = r.name.toLowerCase();
        return (r.category == RecordCategory.vital ||
                r.category == RecordCategory.lab) &&
            (name.contains('glucose') ||
                name.contains('hba1c') ||
                name.contains('a1c') ||
                name.contains('ketone'));
      }).toList();

      if (glucoseRecords.isEmpty) return pw.SizedBox();
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Glycemic Control & Glucose History (${glucoseRecords.take(12).length})',
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: specialtyHeaderColor,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            headers: const [
              'Date',
              'Measurement',
              'Value',
              'Context / Meal State',
              'Target Range',
              'Source',
            ],
            data: glucoseRecords.take(12).map((record) {
              final contextTag = record.hasExplicitMeasurementContext
                  ? record.measurementContext
                  : (record.sourceData?['context']?.toString() ?? '—');
              final criticalAlert = CriticalSafetyEvaluator.evaluate(record);
              final displayVal = criticalAlert != null
                  ? '${record.displayValue} (CRITICAL)'
                  : record.displayValue;
              return [
                _formatDate(record.recordedAt),
                record.name,
                displayVal,
                contextTag,
                (record.referenceRange ?? '-').replaceAll('–', '-'),
                record.source,
              ];
            }).toList(),
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
              fontSize: 8,
            ),
            headerDecoration: const pw.BoxDecoration(
              color: PdfColor.fromInt(0xFF0D47A1),
            ),
            cellStyle: const pw.TextStyle(fontSize: 8),
            cellPadding: const pw.EdgeInsets.symmetric(
              horizontal: 5,
              vertical: 4,
            ),
            border: pw.TableBorder(
              horizontalInside: pw.BorderSide(
                color: PdfColor.fromHex('#E0E0E0'),
                width: 0.5,
              ),
            ),
          ),
          pw.SizedBox(height: 14),
        ],
      );
    }

    // Helper for Endocrinology: Renal & Metabolic Function
    pw.Widget buildEndocrinologyRenalSection() {
      final renalLabs = ordered.where((r) {
        if (r.category != RecordCategory.lab) return false;
        final name = r.name.toLowerCase();
        return name.contains('creatinine') ||
            name.contains('egfr') ||
            name.contains('bun') ||
            name.contains('urea') ||
            name.contains('albumin') ||
            name.contains('microalbumin') ||
            name.contains('potassium') ||
            name.contains('sodium') ||
            name.contains('tsh');
      }).toList();

      if (renalLabs.isEmpty) return pw.SizedBox();
      return buildOtherLabsTable(
        title: 'Metabolic & Renal Function Markers',
        customLabs: renalLabs,
      );
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 8),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'ClinicalAssistant | $summaryTitle | Self-Collected Patient Records',
                style: const pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.grey700,
                ),
              ),
              pw.Text(
                'Page ${context.pageNumber} of ${context.pagesCount}',
                style: const pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.grey700,
                ),
              ),
            ],
          ),
        ),
        build: (_) => [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    summaryTitle,
                    style: pw.TextStyle(
                      fontSize: 17,
                      fontWeight: pw.FontWeight.bold,
                      color: specialtyHeaderColor,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  for (final line in subtitleItems)
                    pw.Text(
                      line,
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: line.startsWith('Period:')
                            ? pw.FontWeight.bold
                            : pw.FontWeight.normal,
                        color: PdfColors.grey800,
                      ),
                    ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'Generated: ${DateTime.now().toUtc().toIso8601String().split('T').first}',
                    style: const pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.grey700,
                    ),
                  ),
                  pw.Text(
                    '${ordered.length} total records',
                    style: const pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.grey700,
                    ),
                  ),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            'Sources: ${sources.isEmpty ? 'None' : sources}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 8),
          pw.Container(
            padding: const pw.EdgeInsets.all(6),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#F4F7F6'),
              borderRadius: pw.BorderRadius.circular(4),
              border: pw.Border.all(
                color: PdfColor.fromHex('#D8E2E1'),
                width: 0.5,
              ),
            ),
            child: pw.Text(
              'Notice for Clinician: These health measurements and observations were aggregated on-device from patient-authorized health platforms, devices, and provider portals. They are presented for descriptive informational review and do not constitute automated clinical diagnosis.',
              style: const pw.TextStyle(
                fontSize: 7.5,
                color: PdfColors.grey800,
              ),
            ),
          ),
          pw.SizedBox(height: 14),

          // Layout section ordering based on specialty template
          if (effectiveSpecialty == DoctorVisitSpecialty.cardiology) ...[
            if (effectiveIncludeVitals && vitalSeries.isNotEmpty)
              buildVitalsSummaryTable(
                title: 'Cardiovascular Vitals & Blood Pressure Summary',
              ),
            if (effectiveIncludeLabs) ...[
              buildCardiologyLipidsSection(),
              if (outOfRangeLabs.isNotEmpty) buildOutOfRangeTable(),
            ],
            if (effectiveIncludeMedications && medications.isNotEmpty)
              buildMedicationsTable(),
            if (effectiveIncludeLabs && otherLabs.isNotEmpty)
              buildOtherLabsTable(),
            if (effectiveIncludeConditions && conditions.isNotEmpty)
              buildConditionsTable(),
            if (effectiveIncludeAllergies && allergies.isNotEmpty)
              buildAllergiesTable(),
            if (coverages.isNotEmpty) buildCoverageTable(),
            if (effectiveIncludeQuestions) buildQuestionsSection(),
          ] else if (effectiveSpecialty ==
              DoctorVisitSpecialty.endocrinology) ...[
            if (effectiveIncludeLabs || effectiveIncludeVitals)
              buildEndocrinologyGlucoseSection(),
            if (effectiveIncludeLabs) ...[
              buildEndocrinologyRenalSection(),
              if (outOfRangeLabs.isNotEmpty) buildOutOfRangeTable(),
            ],
            if (effectiveIncludeVitals && vitalSeries.isNotEmpty)
              buildVitalsSummaryTable(),
            if (effectiveIncludeMedications && medications.isNotEmpty)
              buildMedicationsTable(),
            if (effectiveIncludeLabs && otherLabs.isNotEmpty)
              buildOtherLabsTable(),
            if (effectiveIncludeConditions && conditions.isNotEmpty)
              buildConditionsTable(),
            if (effectiveIncludeAllergies && allergies.isNotEmpty)
              buildAllergiesTable(),
            if (coverages.isNotEmpty) buildCoverageTable(),
            if (effectiveIncludeQuestions) buildQuestionsSection(),
          ] else ...[
            // Annual Wellness / General Template
            if (effectiveIncludeLabs && outOfRangeLabs.isNotEmpty)
              buildOutOfRangeTable(),
            if (effectiveIncludeVitals && vitalSeries.isNotEmpty)
              buildVitalsSummaryTable(),
            if (effectiveIncludeLabs && otherLabs.isNotEmpty)
              buildOtherLabsTable(),
            if (effectiveIncludeMedications && medications.isNotEmpty)
              buildMedicationsTable(),
            if (effectiveIncludeConditions && conditions.isNotEmpty)
              buildConditionsTable(),
            if (effectiveIncludeAllergies && allergies.isNotEmpty)
              buildAllergiesTable(),
            if (coverages.isNotEmpty) buildCoverageTable(),
            if (effectiveIncludeQuestions) buildQuestionsSection(),
          ],
        ],
      ),
    );

    return pdf;
  }

  Future<File> createDoctorVisitSummaryPdf(
    List<HealthRecord> records, {
    DateTimeRange? dateRange,
    String? patientQuestions,
    bool includeVitals = true,
    bool includeLabs = true,
    bool includeMedications = true,
    bool includeConditions = true,
    bool includeAllergies = true,
    bool includeQuestions = true,
    DoctorVisitPreparationConfig? config,
  }) async {
    final pdf = await buildDoctorVisitSummaryPdfDocument(
      records,
      dateRange: dateRange,
      patientQuestions: patientQuestions,
      includeVitals: includeVitals,
      includeLabs: includeLabs,
      includeMedications: includeMedications,
      includeConditions: includeConditions,
      includeAllergies: includeAllergies,
      includeQuestions: includeQuestions,
      config: config,
    );
    final directory = await getTemporaryDirectory();
    final file = File(
      '${directory.path}/doctor-visit-summary-${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
    await file.writeAsBytes(await pdf.save(), flush: true);
    await _restrictFilePermissions(file);
    return file;
  }

  Map<String, Object?> _observationFromRecord(
    HealthRecord record, {
    bool includeSourceData = true,
    bool includeNotes = true,
  }) {
    final numericValue = num.tryParse(record.value);
    final unitCode = _ucumCode(record.unit);
    final id = record.id.replaceAll(_idSanitizer, '-');
    return {
      'resourceType': 'Observation',
      'id': id.isEmpty ? 'record' : id,
      'status': 'unknown',
      'category': [
        {
          'text': switch (record.category) {
            RecordCategory.lab => 'Laboratory',
            RecordCategory.vital => 'Vital signs',
            RecordCategory.activity => 'Activity',
            RecordCategory.sleep => 'Sleep',
            RecordCategory.nutrition => 'Nutrition',
            RecordCategory.cycleTracking => 'Cycle tracking',
            RecordCategory.medication => 'Medication',
            RecordCategory.condition => 'Condition',
            RecordCategory.allergy => 'Allergy',
            RecordCategory.immunization => 'Immunization',
            RecordCategory.coverage => 'Coverage',
          },
        },
      ],
      'code': {
        'text': record.name,
        if (record.code != null)
          'coding': [
            {
              'system': 'urn:clinical-assistant:health-type',
              'code': record.code,
              'display': record.name,
            },
          ],
      },
      'effectiveDateTime': record.recordedAt.toUtc().toIso8601String(),
      if (numericValue != null)
        'valueQuantity': {
          'value': numericValue,
          'unit': record.unit,
          ...?(unitCode == null
              ? null
              : {'system': 'http://unitsofmeasure.org', 'code': unitCode}),
        }
      else
        'valueString': record.value,
      if (record.referenceRange case final referenceRange?)
        'referenceRange': [
          {'text': referenceRange},
        ],
      'note': [
        if (includeNotes && record.notes != null && record.notes!.isNotEmpty)
          {'text': record.notes},
        {'text': 'Source: ${record.source}'},
      ],
      if (includeSourceData && record.sourceData != null)
        'extension': [
          {
            'url': 'urn:clinical-assistant:source-data',
            'valueString': jsonEncode(record.sourceData),
          },
        ],
    };
  }

  Map<String, Object?> _resourceForRecord(
    HealthRecord record, {
    bool includeSourceData = true,
    bool includeNotes = true,
  }) {
    if (record.isManual && record.category == RecordCategory.medication) {
      return _manualMedicationStatement(record, includeNotes: includeNotes);
    }
    final resourceType = record.sourceData?['resourceType'];
    if (includeSourceData &&
        resourceType is String &&
        resourceType.isNotEmpty) {
      final resource = Map<String, Object?>.from(record.sourceData!);
      if (!includeNotes) {
        resource.remove('note');
      }
      return resource;
    }
    return _observationFromRecord(
      record,
      includeSourceData: includeSourceData,
      includeNotes: includeNotes,
    );
  }

  Map<String, Object?> _manualMedicationStatement(
    HealthRecord record, {
    bool includeNotes = true,
  }) {
    final details = ManualMedicationDetails.fromRecord(record);
    final id = record.id.replaceAll(_idSanitizer, '-');
    return {
      'resourceType': 'MedicationStatement',
      'id': id.isEmpty ? 'medication' : id,
      'status': record.status ?? 'unknown',
      'medicationCodeableConcept': {'text': record.name},
      'effectivePeriod': {
        'start': record.recordedAt.toUtc().toIso8601String(),
        if (details.endDate != null) 'end': _formatDate(details.endDate!),
      },
      'dosage': [
        {
          'text': record.value,
          'timing': {
            'code': {'text': details.frequency},
          },
          if (details.route != null) 'route': {'text': details.route},
        },
      ],
      if (includeNotes && record.notes != null && record.notes!.isNotEmpty)
        'note': [
          {'text': record.notes},
        ],
      'extension': [
        {'url': 'urn:clinical-assistant:source', 'valueString': record.source},
      ],
    };
  }

  String _medicationInstructions(HealthRecord record) {
    if (!record.isManual || record.category != RecordCategory.medication) {
      return record.displayValue;
    }
    final details = ManualMedicationDetails.fromRecord(record);
    return [
      record.value,
      if (details.frequency.isNotEmpty) details.frequency,
      if (details.route != null) details.route,
      if (record.status != null) record.status,
    ].join(' · ');
  }

  Future<File> createVaultBackup(String backupJson) async {
    final timestamp = DateTime.now()
        .toUtc()
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-');
    return _writeExport(
      'clinical_assistant_vault_backup_$timestamp.clinicalvault',
      backupJson,
    );
  }

  Future<File> _writeExport(String fileName, String contents) async {
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/$fileName');
    await file.writeAsString(contents, encoding: utf8, flush: true);
    await _restrictFilePermissions(file);
    return file;
  }

  Future<void> _restrictFilePermissions(File file) async {
    // Restrict permissions to user read/write only (0600) on POSIX platforms
    // to safeguard exported health data and vault backups against local process access.
    if (!Platform.isWindows) {
      try {
        await Process.run('chmod', ['600', file.path]);
      } catch (_) {}
    }
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year}-$month-$day';
  }

  String? _ucumCode(String unit) => switch (unit) {
    'mg/dL' => 'mg/dL',
    'mmol/L' => 'mmol/L',
    '%' => '%',
    'mmHg' => 'mm[Hg]',
    '°C' => 'Cel',
    '°F' => '[degF]',
    'bpm' => '/min',
    'breaths/min' => '/min',
    'ms' => 'ms',
    'm' => 'm',
    'cm' => 'cm',
    'kg' => 'kg',
    'lb' => '[lb_av]',
    'count' => '1',
    _ => null,
  };
}
