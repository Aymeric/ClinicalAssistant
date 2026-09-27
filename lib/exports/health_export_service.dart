import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/health_record.dart';

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

  Future<File> createPdf(List<HealthRecord> records) async {
    final pdf = pw.Document();
    final ordered = [...records]
      ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (_) => [
          pw.Text(
            'Your health records',
            style: pw.TextStyle(
              fontSize: 24,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromHex('#183F46'),
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'Exported ${DateTime.now().toUtc().toIso8601String()}',
            style: const pw.TextStyle(fontSize: 9),
          ),
          pw.SizedBox(height: 12),
          pw.Text(
            'This summary contains records imported from the sources listed below. '
            'It is not a medical interpretation or a substitute for advice from a clinician.',
            style: const pw.TextStyle(fontSize: 10),
          ),
          pw.SizedBox(height: 22),
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

  Map<String, Object?> _observationFromRecord(HealthRecord record) {
    final numericValue = num.tryParse(record.value);
    final unitCode = _ucumCode(record.unit);
    final id = record.id.replaceAll(RegExp(r'[^A-Za-z0-9.-]'), '-');
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
