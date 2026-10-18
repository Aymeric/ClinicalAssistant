import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'clinical_guideline.dart';
import 'guideline_source.dart';

class GuidelinePdfExportService {
  const GuidelinePdfExportService();

  static final _primaryColor = PdfColor.fromHex('#183F46');
  static final _secondaryColor = PdfColor.fromHex('#2F5C64');
  static final _accentColor = PdfColor.fromHex('#4A7C85');
  static final _neutralBg = PdfColor.fromHex('#F4F6F6');
  static final _borderColor = PdfColor.fromHex('#D2DCDE');
  static final _subtleText = PdfColor.fromHex('#5A6E72');

  Future<File> generateGuidelinePdf({
    required ClinicalGuideline guideline,
    String? patientNotes,
    DateTime? generatedAt,
    Directory? outputDirectory,
  }) async {
    final pdf = pw.Document();
    final effectiveGeneratedAt = (generatedAt ?? DateTime.now()).toUtc();
    final notes = patientNotes?.trim();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        header: (pw.Context context) {
          return pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 12),
            padding: const pw.EdgeInsets.only(bottom: 8),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(
                  color: PdfColor.fromInt(0xFFD2DCDE),
                  width: 0.8,
                ),
              ),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'ClinicalAssistant · Evidence-Based Practice Brief',
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                    color: _secondaryColor,
                  ),
                ),
                pw.Text(
                  'ID: ${guideline.identifier} · ${guideline.publisher}',
                  style: pw.TextStyle(
                    fontSize: 8,
                    color: _subtleText,
                  ),
                ),
              ],
            ),
          );
        },
        footer: (pw.Context context) {
          return pw.Container(
            margin: const pw.EdgeInsets.only(top: 14),
            padding: const pw.EdgeInsets.only(top: 8),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                top: pw.BorderSide(
                  color: PdfColor.fromInt(0xFFD2DCDE),
                  width: 0.8,
                ),
              ),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Expanded(
                      child: pw.Text(
                        'Educational and clinical discussion reference. Not an automated diagnosis or individualized prescription.',
                        style: pw.TextStyle(
                          fontSize: 7,
                          color: _subtleText,
                          fontStyle: pw.FontStyle.italic,
                        ),
                      ),
                    ),
                    pw.SizedBox(width: 12),
                    pw.Text(
                      'Page ${context.pageNumber} of ${context.pagesCount}',
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                        color: _secondaryColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
        build: (pw.Context context) {
          return [
            // Top Title & Meta Banner
            pw.Container(
              padding: const pw.EdgeInsets.all(14),
              decoration: pw.BoxDecoration(
                color: _neutralBg,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                border: pw.Border.all(color: _borderColor, width: 0.8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: pw.BoxDecoration(
                          color: _primaryColor,
                          borderRadius: const pw.BorderRadius.all(
                            pw.Radius.circular(4),
                          ),
                        ),
                        child: pw.Text(
                          guideline.identifier,
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                      pw.Text(
                        '${guideline.topic.label} · ${guideline.jurisdiction.label}',
                        style: pw.TextStyle(
                          color: _secondaryColor,
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    guideline.title,
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      color: _primaryColor,
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    'Published by: ${guideline.publisher}',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: _accentColor,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Published: ${_formatDate(guideline.publishedDate)}'
                    '${guideline.lastUpdatedDate != null ? ' · Updated: ${_formatDate(guideline.lastUpdatedDate!)}' : ''}'
                    ' · Exported: ${_formatDate(effectiveGeneratedAt)}',
                    style: pw.TextStyle(
                      fontSize: 8,
                      color: _subtleText,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 14),

            // Patient Consultation Questions & Notes (if provided)
            if (notes != null && notes.isNotEmpty) ...[
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#EFF6F7'),
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(6),
                  ),
                  border: pw.Border.all(
                    color: PdfColor.fromHex('#B4D0D5'),
                    width: 0.8,
                  ),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Doctor Appointment Questions & Patient Discussion Notes',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: _primaryColor,
                      ),
                    ),
                    pw.SizedBox(height: 5),
                    pw.Text(
                      notes,
                      style: const pw.TextStyle(
                        fontSize: 9,
                        lineSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 14),
            ],

            // Overview & Evidence Grade
            pw.Text(
              'Clinical Summary & Target Scope',
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: _primaryColor,
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              guideline.summary,
              style: const pw.TextStyle(
                fontSize: 9,
                lineSpacing: 2.2,
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: pw.BoxDecoration(
                color: _neutralBg,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                border: pw.Border.all(color: _borderColor, width: 0.6),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Target Population: ${guideline.targetAudience}',
                    style: pw.TextStyle(
                      fontSize: 8.5,
                      fontWeight: pw.FontWeight.bold,
                      color: _secondaryColor,
                    ),
                  ),
                  pw.SizedBox(height: 3),
                  pw.Text(
                    'Evidence Assessment: ${guideline.evidenceGrade}',
                    style: pw.TextStyle(
                      fontSize: 8.5,
                      fontWeight: pw.FontWeight.bold,
                      color: _accentColor,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 14),

            // Key Recommendations Section
            pw.Text(
              'Key Recommendations (${guideline.recommendations.length})',
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: _primaryColor,
              ),
            ),
            pw.SizedBox(height: 6),

            for (final rec in guideline.recommendations) ...[
              pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 8),
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.white,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  border: pw.Border.all(color: _borderColor, width: 0.6),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Expanded(
                          child: pw.Text(
                            rec.title,
                            style: pw.TextStyle(
                              fontSize: 9.5,
                              fontWeight: pw.FontWeight.bold,
                              color: _primaryColor,
                            ),
                          ),
                        ),
                        pw.SizedBox(width: 8),
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: pw.BoxDecoration(
                            color: _neutralBg,
                            borderRadius: const pw.BorderRadius.all(
                              pw.Radius.circular(3),
                            ),
                            border: pw.Border.all(
                              color: _borderColor,
                              width: 0.5,
                            ),
                          ),
                          child: pw.Text(
                            '${rec.strength} · ${rec.evidenceLevel}',
                            style: pw.TextStyle(
                              fontSize: 7.5,
                              fontWeight: pw.FontWeight.bold,
                              color: _secondaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      rec.text,
                      style: const pw.TextStyle(
                        fontSize: 8.5,
                        lineSpacing: 1.8,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            pw.SizedBox(height: 10),

            // Detailed Clinical Guidance Sections
            pw.Text(
              'Detailed Guidance Sections',
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: _primaryColor,
              ),
            ),
            pw.SizedBox(height: 6),

            for (final section in guideline.sections) ...[
              pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 8),
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: _neutralBg,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  border: pw.Border.all(color: _borderColor, width: 0.6),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      section.title,
                      style: pw.TextStyle(
                        fontSize: 9.5,
                        fontWeight: pw.FontWeight.bold,
                        color: _secondaryColor,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      section.content,
                      style: const pw.TextStyle(
                        fontSize: 8.5,
                        lineSpacing: 1.8,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            pw.SizedBox(height: 10),

            // Citation & Source Box
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: _borderColor, width: 0.6),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Citation & Official Provenance',
                    style: pw.TextStyle(
                      fontSize: 8.5,
                      fontWeight: pw.FontWeight.bold,
                      color: _primaryColor,
                    ),
                  ),
                  pw.SizedBox(height: 3),
                  pw.Text(
                    guideline.citation,
                    style: pw.TextStyle(
                      fontSize: 7.5,
                      fontStyle: pw.FontStyle.italic,
                      color: _subtleText,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Online Reference: ${guideline.webUrl}',
                    style: pw.TextStyle(
                      fontSize: 7.5,
                      color: _accentColor,
                    ),
                  ),
                ],
              ),
            ),
          ];
        },
      ),
    );

    final dir = outputDirectory ?? await _resolveOutputDirectory();
    final sanitizedId =
        guideline.id.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
    final file = File('${dir.path}/guideline_$sanitizedId.pdf');
    await file.writeAsBytes(await pdf.save(), flush: true);
    return file;
  }

  Future<Directory> _resolveOutputDirectory() async {
    try {
      final base = await getApplicationDocumentsDirectory();
      final target = Directory('${base.path}/guideline_exports');
      if (!await target.exists()) {
        await target.create(recursive: true);
      }
      return target;
    } catch (_) {
      return Directory.systemTemp.createTempSync('guideline_exports_');
    }
  }

  static String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }
}
