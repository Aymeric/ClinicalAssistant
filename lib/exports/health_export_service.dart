import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:flutter/material.dart' show DateTimeRange, DateUtils;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/health_record.dart';
import '../trends/health_trend.dart';

class HealthExportService {
  Map<String, Object?> buildFhirBundle(List<HealthRecord> records) {
    final bundle = {
      'resourceType': 'Bundle',
      'type': 'collection',
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'entry': records
          .map((record) => {'resource': _resourceForRecord(record)})
          .toList(),
    };
    return bundle;
  }

  Future<File> createFhirBundle(List<HealthRecord> records) async {
    return _writeExport(
      'health-records.fhir.json',
      const JsonEncoder.withIndent('  ').convert(buildFhirBundle(records)),
    );
  }

  String buildCsv(List<HealthRecord> records) {
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
        'Source data (JSON)',
      ],
      ...records.map(
        (record) => [
          record.name,
          record.value,
          record.unit,
          record.recordedAt.toUtc().toIso8601String(),
          record.category.name,
          record.source,
          record.sourceId ?? '',
          record.code ?? '',
          record.referenceRange ?? '',
          record.status ?? '',
          if (record.sourceData == null) '' else jsonEncode(record.sourceData),
        ],
      ),
    ];
    return const CsvEncoder().convert(rows);
  }

  Future<File> createCsv(List<HealthRecord> records) async {
    return _writeExport('health-records.csv', buildCsv(records));
  }

  String buildTextSummary(List<HealthRecord> records) {
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
      '\nNotice: This summary contains health records imported from the listed sources. '
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
      };

      buffer.writeln('--- $categoryTitle (${categoryRecords.length}) ---');
      for (final r in categoryRecords) {
        final date = _formatDate(r.recordedAt);
        final ref = r.referenceRange != null
            ? ' [Ref: ${r.referenceRange}]'
            : '';
        buffer.writeln(
          '• $date: ${r.name} = ${r.displayValue}$ref (${r.source})',
        );
      }
      buffer.writeln();
    }

    return buffer.toString();
  }

  Future<File> createTextSummary(List<HealthRecord> records) async {
    return _writeExport(
      'health-records-summary.txt',
      buildTextSummary(records),
    );
  }

  Future<File> createPdf(List<HealthRecord> records) async {
    final pdf = pw.Document();
    final ordered = [...records]
      ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    final sources = ordered.map((r) => r.source).toSet().join(', ');
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
              headers: const [
                'Date',
                'Record',
                'Value',
                'Reference range',
                'Source',
              ],
              data: ordered
                  .map(
                    (record) => [
                      _formatDate(record.recordedAt),
                      record.name,
                      record.displayValue,
                      record.referenceRange ?? '-',
                      record.source,
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
    return file;
  }

  Future<pw.Document> buildDoctorVisitSummaryPdfDocument(
    List<HealthRecord> records, {
    DateTimeRange? dateRange,
    String? patientQuestions,
  }) async {
    final pdf = pw.Document();

    var filtered = records;
    if (dateRange != null) {
      filtered = records.where((r) {
        final d = DateUtils.dateOnly(r.recordedAt.toLocal());
        return !d.isBefore(dateRange.start) && !d.isAfter(dateRange.end);
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

    // Identify out-of-range labs
    final outOfRangeLabs = <(HealthRecord, HealthReferenceStatus)>[];
    final otherLabs = <HealthRecord>[];
    for (final r in ordered.where((r) => r.category == RecordCategory.lab)) {
      final numVal = parseHealthRecordValue(r.value);
      if (numVal != null && r.referenceRange != null) {
        final range = HealthReferenceRange.tryParse(
          r.referenceRange,
          expectedUnit: r.unit,
        );
        final status =
            range?.evaluate(numVal) ?? HealthReferenceStatus.unspecified;
        if (status == HealthReferenceStatus.above ||
            status == HealthReferenceStatus.below) {
          outOfRangeLabs.add((r, status));
          continue;
        }
      }
      otherLabs.add(r);
    }

    final medications = ordered
        .where((r) => r.category == RecordCategory.medication)
        .toList();
    final conditions = ordered
        .where((r) => r.category == RecordCategory.condition)
        .toList();
    final allergies = ordered
        .where((r) => r.category == RecordCategory.allergy)
        .toList();

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
                'ClinicalAssistant | Doctor Visit Summary | Self-Collected Patient Records',
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
                    'Clinical Consultation Preparation Summary',
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromHex('#183F46'),
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    dateRange == null
                        ? 'All available records'
                        : 'Period: ${_formatDate(dateRange.start)} to ${_formatDate(dateRange.end)}',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
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
              'Notice for Clinician: These health measurements and observations were aggregated on-device from patient-authorized health platforms and provider portals. They are presented for descriptive informational review and do not constitute automated clinical diagnosis.',
              style: const pw.TextStyle(
                fontSize: 7.5,
                color: PdfColors.grey800,
              ),
            ),
          ),
          pw.SizedBox(height: 14),

          // Out-of-Range Lab Highlights Section
          if (outOfRangeLabs.isNotEmpty) ...[
            pw.Text(
              'Flagged Out-of-Range Lab Observations (${outOfRangeLabs.length})',
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
                'Result',
                'Flag',
                'Reference Range',
                'Source',
              ],
              data: outOfRangeLabs.map((item) {
                final (record, status) = item;
                final flag = status == HealthReferenceStatus.above
                    ? 'HIGH'
                    : 'LOW';
                return [
                  _formatDate(record.recordedAt),
                  record.name,
                  record.displayValue,
                  flag,
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

          // Vitals Summary Section
          if (vitalSeries.isNotEmpty) ...[
            pw.Text(
              'Vital Signs Summary',
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromHex('#183F46'),
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

                return [
                  name,
                  latestRec.displayValue,
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
              headerDecoration: const pw.BoxDecoration(
                color: PdfColor.fromInt(0xFF183F46),
              ),
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

          // Other Recent Lab Results Section
          if (otherLabs.isNotEmpty) ...[
            pw.Text(
              'Other Lab Observations (Recent ${otherLabs.take(12).length})',
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromHex('#183F46'),
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
              data: otherLabs
                  .take(12)
                  .map(
                    (record) => [
                      _formatDate(record.recordedAt),
                      record.name,
                      record.displayValue,
                      (record.referenceRange ?? '-').replaceAll('–', '-'),
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

          // Current Medications Section
          if (medications.isNotEmpty) ...[
            pw.Text(
              'Reported Medications (${medications.take(10).length})',
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromHex('#183F46'),
              ),
            ),
            pw.SizedBox(height: 6),
            pw.TableHelper.fromTextArray(
              headers: const [
                'Medication',
                'Instructions / Status',
                'Date',
                'Source',
              ],
              data: medications
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

          // Conditions & Diagnoses Section
          if (conditions.isNotEmpty) ...[
            pw.Text(
              'Recorded Conditions & Diagnoses (${conditions.take(10).length})',
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromHex('#183F46'),
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

          // Allergies Section
          if (allergies.isNotEmpty) ...[
            pw.Text(
              'Known Allergies & Intolerances (${allergies.take(10).length})',
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromHex('#183F46'),
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

          // Patient Questions / Topics for the Doctor
          pw.Text(
            'Patient Discussion Topics & Questions',
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromHex('#183F46'),
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
            child:
                patientQuestions != null && patientQuestions.trim().isNotEmpty
                ? pw.Text(
                    patientQuestions.trim(),
                    style: const pw.TextStyle(fontSize: 9, lineSpacing: 2),
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
      ),
    );

    return pdf;
  }

  Future<File> createDoctorVisitSummaryPdf(
    List<HealthRecord> records, {
    DateTimeRange? dateRange,
    String? patientQuestions,
  }) async {
    final pdf = await buildDoctorVisitSummaryPdfDocument(
      records,
      dateRange: dateRange,
      patientQuestions: patientQuestions,
    );
    final directory = await getTemporaryDirectory();
    final file = File(
      '${directory.path}/doctor-visit-summary-${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
    await file.writeAsBytes(await pdf.save(), flush: true);
    return file;
  }

  Map<String, Object?> _observationFromRecord(HealthRecord record) {
    final numericValue = num.tryParse(record.value);
    final unitCode = _ucumCode(record.unit);
    final id = record.id.replaceAll(_invalidFhirIdRegExp, '-');
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
        {'text': 'Source: ${record.source}'},
      ],
      if (record.sourceData != null)
        'extension': [
          {
            'url': 'urn:clinical-assistant:source-data',
            'valueString': jsonEncode(record.sourceData),
          },
        ],
    };
  }

  Map<String, Object?> _resourceForRecord(HealthRecord record) {
    final resourceType = record.sourceData?['resourceType'];
    if (resourceType is String && resourceType.isNotEmpty) {
      return record.sourceData!;
    }
    return _observationFromRecord(record);
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
    return file;
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

// Pre-compiled RegExp instance to avoid repeated pattern compilation overhead in hot FHIR ID sanitization paths.
final _invalidFhirIdRegExp = RegExp(r'[^A-Za-z0-9.-]');
