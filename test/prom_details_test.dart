import 'dart:convert';

import 'package:clinical_assistant/exports/health_export_service.dart';
import 'package:clinical_assistant/integrations/fhir_file_import.dart';
import 'package:clinical_assistant/integrations/fhir_observation_parser.dart';
import 'package:clinical_assistant/models/health_record.dart';
import 'package:clinical_assistant/models/prom_details.dart';
import 'package:clinical_assistant/records/manual_record_entry_sheet.dart';
import 'package:clinical_assistant/trends/health_trend.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PromDetails & Instruments', () {
    test('instruments have standard question counts and choices', () {
      expect(PromInstrument.phq9.questions.length, 9);
      expect(PromInstrument.gad7.questions.length, 7);
      expect(PromInstrument.cat.questions.length, 8);
      expect(PromInstrument.mmrc.questions.length, 1);
      expect(PromInstrument.sf12.questions.length, 12);
      expect(PromInstrument.haq.questions.length, 8);
    });

    test('PromInstrument.fromString matches names and abbreviations', () {
      expect(PromInstrument.fromString('phq-9'), PromInstrument.phq9);
      expect(PromInstrument.fromString('gad-7'), PromInstrument.gad7);
      expect(
        PromInstrument.fromString('COPD Assessment Test (CAT)'),
        PromInstrument.cat,
      );
      expect(PromInstrument.fromString('mMRC Dyspnea'), PromInstrument.mmrc);
      expect(
        PromInstrument.fromString('SF-12 Health Survey'),
        PromInstrument.sf12,
      );
      expect(
        PromInstrument.fromString('HAQ Disability Index'),
        PromInstrument.haq,
      );
    });

    test('evaluates descriptive score summaries neutrally', () {
      expect(PromInstrument.phq9.scoreSummary(3), 'Minimal (0-4)');
      expect(PromInstrument.phq9.scoreSummary(8), 'Mild (5-9)');
      expect(PromInstrument.phq9.scoreSummary(13), 'Moderate (10-14)');
      expect(PromInstrument.phq9.scoreSummary(18), 'Moderately severe (15-19)');
      expect(PromInstrument.phq9.scoreSummary(24), 'Severe (20-27)');

      expect(PromInstrument.gad7.scoreSummary(3), 'Minimal (0-4)');
      expect(PromInstrument.gad7.scoreSummary(7), 'Mild (5-9)');
      expect(PromInstrument.gad7.scoreSummary(12), 'Moderate (10-14)');
      expect(PromInstrument.gad7.scoreSummary(19), 'Severe (15-21)');
    });

    test('serializes and deserializes PromResponseDetails round-trip', () {
      final details = const PromResponseDetails(
        instrument: PromInstrument.gad7,
        totalScore: 11,
        answers: [2, 1, 2, 1, 2, 1, 2],
        scoreSummary: 'Moderate (10-14)',
        notes: 'Completed before therapy session',
      );

      final record = HealthRecord(
        id: 'prom-1',
        name: 'GAD-7',
        value: '11',
        unit: 'pts',
        recordedAt: DateTime.utc(2026, 10, 20),
        category: RecordCategory.questionnaire,
        source: 'Manual Entry',
        sourceData: details.withSourceData(null),
      );

      final parsed = PromResponseDetails.fromRecord(record);
      expect(parsed.instrument, PromInstrument.gad7);
      expect(parsed.totalScore, 11);
      expect(parsed.answers, [2, 1, 2, 1, 2, 1, 2]);
      expect(parsed.scoreSummary, 'Moderate (10-14)');
      expect(parsed.notes, 'Completed before therapy session');
    });

    test('exports standard FHIR QuestionnaireResponse resource', () {
      const details = PromResponseDetails(
        instrument: PromInstrument.phq9,
        totalScore: 7,
        answers: [1, 1, 1, 0, 1, 1, 1, 1, 0],
        notes: 'Follow-up screen',
      );

      final record = HealthRecord(
        id: 'rec-phq9-1',
        name: 'PHQ-9',
        value: '7',
        unit: 'pts',
        recordedAt: DateTime.utc(2026, 10, 21),
        category: RecordCategory.questionnaire,
        source: 'Manual Entry',
        sourceData: details.withSourceData(null),
      );

      final qr = details.toFhirQuestionnaireResponse(record);
      expect(qr['resourceType'], 'QuestionnaireResponse');
      expect(qr['status'], 'completed');
      expect(qr['questionnaire'], 'urn:loinc:44249-1');
      expect((qr['item'] as List).length, 9);
      expect((qr['item'] as List).first['linkId'], 'q1');

      // Test export service integration
      final exportService = HealthExportService();
      final bundle = exportService.buildFhirBundle([record]);
      final entry = (bundle['entry'] as List).first as Map;
      final resource = entry['resource'] as Map;
      expect(resource['resourceType'], 'QuestionnaireResponse');
      expect(resource['id'], 'rec-phq9-1');
    });

    test('parses FHIR QuestionnaireResponse in FhirObservationParser', () {
      const parser = FhirObservationParser();
      final fhirJson = jsonEncode({
        'resourceType': 'QuestionnaireResponse',
        'id': 'qr-123',
        'status': 'completed',
        'questionnaire': 'http://loinc.org/44249-1',
        'authored': '2026-10-15T14:30:00Z',
        'item': [
          {
            'linkId': 'q1',
            'text': 'Little interest or pleasure in doing things',
            'answer': [
              {'valueInteger': 2},
            ],
          },
          {
            'linkId': 'q2',
            'text': 'Feeling down, depressed, or hopeless',
            'answer': [
              {'valueInteger': 3},
            ],
          },
        ],
        'note': [
          {'text': 'Routine health check'},
        ],
      });

      final records = parser.parseJson(fhirJson, source: 'Epic Portal');
      expect(records.length, 1);
      final r = records.first;
      expect(r.category, RecordCategory.questionnaire);
      expect(r.name, 'PHQ-9');
      expect(r.value, '5'); // 2 + 3
      expect(r.unit, 'pts');
      expect(r.code, '44249-1');
      expect(r.notes, 'Routine health check');

      final details = PromResponseDetails.fromRecord(r);
      expect(details.instrument, PromInstrument.phq9);
      expect(details.totalScore, 5);
      expect(details.answers, [2, 3]);
    });

    test('FhirFileImport previews QuestionnaireResponse resource counts', () {
      final fhirJson = jsonEncode({
        'resourceType': 'Bundle',
        'type': 'collection',
        'entry': [
          {
            'resource': {
              'resourceType': 'QuestionnaireResponse',
              'id': 'qr-1',
              'status': 'completed',
              'questionnaire': 'http://loinc.org/69737-5',
              'authored': '2026-10-18T10:00:00Z',
              'item': [
                {
                  'linkId': 'q1',
                  'answer': [
                    {'valueInteger': 1},
                  ],
                },
              ],
            },
          },
        ],
      });

      final preview = FhirFilePreview.fromPayload(
        FhirFilePayload(
          name: 'test_prom.json',
          sizeInBytes: fhirJson.length,
          content: fhirJson,
        ),
      );

      expect(preview.isValid, isTrue);
      expect(preview.resourceCounts['QuestionnaireResponse'], 1);
      expect(preview.records.first.category, RecordCategory.questionnaire);
    });

    test(
      'buildHealthTrendSeries groups questionnaire PROM scores into numeric trend series',
      () {
        final records = [
          HealthRecord(
            id: 'phq-1',
            name: 'PHQ-9',
            value: '14',
            unit: 'pts',
            recordedAt: DateTime.utc(2026, 9, 1),
            category: RecordCategory.questionnaire,
            source: 'Manual Entry',
          ),
          HealthRecord(
            id: 'phq-2',
            name: 'PHQ-9',
            value: '8',
            unit: 'pts',
            recordedAt: DateTime.utc(2026, 10, 1),
            category: RecordCategory.questionnaire,
            source: 'Manual Entry',
          ),
        ];

        final seriesList = buildHealthTrendSeries(records);
        expect(seriesList.length, 1);
        final phqSeries = seriesList.first;
        expect(phqSeries.name, 'PHQ-9');
        expect(phqSeries.category, RecordCategory.questionnaire);
        expect(phqSeries.points.length, 2);
        expect(phqSeries.points.first.value, 14.0);
        expect(phqSeries.points.last.value, 8.0);
      },
    );

    testWidgets('ManualRecordEntrySheet logs structured PROM survey', (
      tester,
    ) async {
      List<HealthRecord>? savedRecords;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ManualRecordEntrySheet(
              onSave: (records) => savedRecords = records,
            ),
          ),
        ),
      );

      // Scroll to PROM survey chip
      await tester.ensureVisible(find.text('PROM Survey'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('PROM Survey'));
      await tester.pumpAndSettle();

      expect(find.text('Save Survey to Vault'), findsOneWidget);
      expect(find.textContaining('Instrument Questions (9)'), findsOneWidget);

      // Select GAD-7
      await tester.tap(find.byKey(const ValueKey('manual-prom-instrument')));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('GAD-7').last);
      await tester.pumpAndSettle();

      expect(find.textContaining('Instrument Questions (7)'), findsOneWidget);

      // Change answer on Q0 to 'More than half the days (+2)'
      await tester.tap(find.byKey(const ValueKey('manual-prom-q0')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('More than half the days (+2)').last);
      await tester.pumpAndSettle();

      // Change answer on Q1 to 'Nearly every day (+3)'
      await tester.tap(find.byKey(const ValueKey('manual-prom-q1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nearly every day (+3)').last);
      await tester.pumpAndSettle();

      // Check live calculated score display (2 + 3 = 5)
      expect(
        find.textContaining('Calculated score: 5 · Mild (5-9)'),
        findsOneWidget,
      );

      // Save
      await tester.ensureVisible(find.text('Save Survey to Vault'));
      await tester.tap(find.text('Save Survey to Vault'));
      await tester.pump();

      expect(savedRecords, isNotNull);
      expect(savedRecords!.length, 1);
      final record = savedRecords!.single;
      expect(record.name, 'GAD-7');
      expect(record.value, '5');
      expect(record.unit, 'pts');
      expect(record.category, RecordCategory.questionnaire);
      expect(record.code, '69737-5');

      final details = PromResponseDetails.fromRecord(record);
      expect(details.instrument, PromInstrument.gad7);
      expect(details.totalScore, 5);
      expect(details.answers[0], 2);
      expect(details.answers[1], 3);
    });
  });
}
