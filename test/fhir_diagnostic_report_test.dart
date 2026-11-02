import 'dart:convert';

import 'package:clinical_assistant/integrations/fhir_observation_parser.dart';
import 'package:clinical_assistant/models/clinical_panel.dart';
import 'package:clinical_assistant/models/health_record.dart';
import 'package:clinical_assistant/ui/records/record_details_sheet.dart';
import 'package:clinical_assistant/ui/shared/record_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const parser = FhirObservationParser();

  group('FhirObservationParser - DiagnosticReport support', () {
    test(
      'parses standalone DiagnosticReport with inline contained observations',
      () {
        final jsonStr = jsonEncode({
          'resourceType': 'DiagnosticReport',
          'id': 'dr-lipid-101',
          'status': 'final',
          'code': {
            'coding': [
              {
                'system': 'http://loinc.org',
                'code': '57698-3',
                'display': 'Lipid Panel with Direct LDL',
              },
            ],
            'text': 'Lipid Panel',
          },
          'effectiveDateTime': '2026-10-25T08:30:00Z',
          'performer': [
            {'display': 'Quest Diagnostics Metro Lab'},
          ],
          'conclusion':
              'Lipid levels are within normal physiological target ranges.',
          'contained': [
            {
              'resourceType': 'Observation',
              'id': 'obs-chol',
              'status': 'final',
              'code': {'text': 'Total Cholesterol'},
              'valueQuantity': {'value': 185, 'unit': 'mg/dL'},
              // Note: omitting effectiveDateTime to verify fallback inheritance
            },
            {
              'resourceType': 'Observation',
              'id': 'obs-trig',
              'status': 'final',
              'code': {'text': 'Triglycerides'},
              'valueQuantity': {'value': 120, 'unit': 'mg/dL'},
              'effectiveDateTime': '2026-10-25T08:30:00Z',
            },
          ],
        });

        final records = parser.parseJson(jsonStr);
        expect(records.length, 2);

        final chol = records.firstWhere((r) => r.name == 'Total Cholesterol');
        expect(chol.value, '185');
        expect(chol.unit, 'mg/dL');
        expect(chol.recordedAt, DateTime.parse('2026-10-25T08:30:00Z'));

        final panelInfo = extractRecordPanelInfo(chol);
        expect(panelInfo, isNotNull);
        expect(panelInfo!.id, 'dr-lipid-101');
        expect(panelInfo.name, 'Lipid Panel');
        expect(panelInfo.code, '57698-3');
        expect(panelInfo.status, 'final');
        expect(panelInfo.performer, 'Quest Diagnostics Metro Lab');
        expect(
          panelInfo.conclusion,
          'Lipid levels are within normal physiological target ranges.',
        );

        final items = groupRecordsIntoListItems(records);
        expect(items.length, 1);
        expect(items.first, isA<GroupedPanelListItem>());
        final panel = (items.first as GroupedPanelListItem).panel;
        expect(panel.name, 'Lipid Panel');
        expect(panel.performer, 'Quest Diagnostics Metro Lab');
        expect(
          panel.conclusion,
          'Lipid levels are within normal physiological target ranges.',
        );
        expect(panel.records.length, 2);
      },
    );

    test(
      'parses bundle with DiagnosticReport referencing observations via result',
      () {
        final jsonStr = jsonEncode({
          'resourceType': 'Bundle',
          'type': 'searchset',
          'entry': [
            {
              'resource': {
                'resourceType': 'DiagnosticReport',
                'id': 'dr-cmp-200',
                'status': 'final',
                'code': {
                  'coding': [
                    {
                      'code': '24323-8',
                      'display': 'Comprehensive Metabolic Panel',
                    },
                  ],
                },
                'effectiveDateTime': '2026-10-26T09:00:00Z',
                'performer': [
                  {'display': 'Memorial Hospital Pathology'},
                ],
                'conclusion': 'Electrolytes and kidney markers are stable.',
                'result': [
                  {'reference': 'Observation/obs-na'},
                  {'reference': 'Observation/obs-k'},
                ],
              },
            },
            {
              'resource': {
                'resourceType': 'Observation',
                'id': 'obs-na',
                'status': 'final',
                'code': {'text': 'Sodium'},
                'valueQuantity': {'value': 140, 'unit': 'mmol/L'},
                'effectiveDateTime': '2026-10-26T09:00:00Z',
              },
            },
            {
              'resource': {
                'resourceType': 'Observation',
                'id': 'obs-k',
                'status': 'final',
                'code': {'text': 'Potassium'},
                'valueQuantity': {'value': 4.2, 'unit': 'mmol/L'},
                'effectiveDateTime': '2026-10-26T09:00:00Z',
              },
            },
          ],
        });

        final records = parser.parseJson(jsonStr);
        expect(records.length, 2);

        final na = records.firstWhere((r) => r.name == 'Sodium');
        final panelInfo = extractRecordPanelInfo(na);
        expect(panelInfo, isNotNull);
        expect(panelInfo!.id, 'dr-cmp-200');
        expect(panelInfo.name, 'Comprehensive Metabolic Panel');
        expect(panelInfo.performer, 'Memorial Hospital Pathology');
        expect(
          panelInfo.conclusion,
          'Electrolytes and kidney markers are stable.',
        );

        final items = groupRecordsIntoListItems(records);
        expect(items.length, 1);
        expect(items.first, isA<GroupedPanelListItem>());
        final panel = (items.first as GroupedPanelListItem).panel;
        expect(panel.performer, 'Memorial Hospital Pathology');
        expect(panel.conclusion, 'Electrolytes and kidney markers are stable.');
      },
    );

    test(
      'links observations to DiagnosticReport via partOf / basedOn references',
      () {
        final jsonStr = jsonEncode({
          'resourceType': 'Bundle',
          'type': 'collection',
          'entry': [
            {
              'resource': {
                'resourceType': 'DiagnosticReport',
                'id': 'dr-cbc-300',
                'code': {'text': 'Complete Blood Count'},
                'effectiveDateTime': '2026-10-26T10:00:00Z',
                'performer': [
                  {'display': 'BioReference Lab'},
                ],
              },
            },
            {
              'resource': {
                'resourceType': 'Observation',
                'id': 'obs-wbc',
                'status': 'final',
                'code': {'text': 'White Blood Cells'},
                'valueQuantity': {'value': 6.5, 'unit': '10*3/uL'},
                'effectiveDateTime': '2026-10-26T10:00:00Z',
                'partOf': [
                  {'reference': 'DiagnosticReport/dr-cbc-300'},
                ],
              },
            },
            {
              'resource': {
                'resourceType': 'Observation',
                'id': 'obs-rbc',
                'status': 'final',
                'code': {'text': 'Red Blood Cells'},
                'valueQuantity': {'value': 4.8, 'unit': '10*6/uL'},
                'effectiveDateTime': '2026-10-26T10:00:00Z',
                'basedOn': [
                  {'reference': 'DiagnosticReport/dr-cbc-300'},
                ],
              },
            },
          ],
        });

        final records = parser.parseJson(jsonStr);
        expect(records.length, 2);

        final wbc = records.firstWhere((r) => r.name == 'White Blood Cells');
        final rbc = records.firstWhere((r) => r.name == 'Red Blood Cells');
        expect(extractRecordPanelInfo(wbc)?.id, 'dr-cbc-300');
        expect(extractRecordPanelInfo(rbc)?.id, 'dr-cbc-300');
      },
    );

    test(
      'parses standalone narrative DiagnosticReport without child observations as HealthRecord',
      () {
        final jsonStr = jsonEncode({
          'resourceType': 'DiagnosticReport',
          'id': 'dr-chest-xray-01',
          'status': 'final',
          'code': {'text': 'Chest X-Ray 2 Views'},
          'effectiveDateTime': '2026-10-20T14:15:00Z',
          'conclusion':
              'Lungs are clear bilaterally. No acute cardiopulmonary abnormality.',
          'performer': [
            {'display': 'Apex Radiology Associates'},
          ],
        });

        final records = parser.parseJson(jsonStr);
        expect(records.length, 1);
        final record = records.first;
        expect(record.name, 'Chest X-Ray 2 Views');
        expect(
          record.value,
          'Lungs are clear bilaterally. No acute cardiopulmonary abnormality.',
        );
        expect(record.category, RecordCategory.lab);
        expect(record.recordedAt, DateTime.parse('2026-10-20T14:15:00Z'));

        final panelInfo = extractRecordPanelInfo(record);
        expect(panelInfo, isNotNull);
        expect(panelInfo!.performer, 'Apex Radiology Associates');
        expect(
          panelInfo.conclusion,
          'Lungs are clear bilaterally. No acute cardiopulmonary abnormality.',
        );
      },
    );
  });

  group('UI widgets - DiagnosticReport and Panel details', () {
    testWidgets('ClinicalPanelCard displays performer and conclusion note', (
      tester,
    ) async {
      final now = DateTime.utc(2026, 10, 26, 12, 0);
      final panel = ClinicalPanel(
        id: 'panel-lipid',
        name: 'Lipid Panel',
        source: 'Quest Diagnostics',
        recordedAt: now,
        performer: 'Quest Metro Laboratory',
        conclusion: 'All lipid analytes are within desirable baseline limits.',
        records: [
          HealthRecord(
            id: 'rec-1',
            name: 'Total Cholesterol',
            value: '185',
            unit: 'mg/dL',
            recordedAt: now,
            category: RecordCategory.lab,
            source: 'Quest Diagnostics',
          ),
          HealthRecord(
            id: 'rec-2',
            name: 'HDL Cholesterol',
            value: '55',
            unit: 'mg/dL',
            recordedAt: now,
            category: RecordCategory.lab,
            source: 'Quest Diagnostics',
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ClinicalPanelCard(
                panel: panel,
                isLast: true,
                initiallyExpanded: true,
              ),
            ),
          ),
        ),
      );

      // Verify header contains panel name and performer
      expect(find.text('Lipid Panel'), findsOneWidget);
      expect(find.textContaining('Quest Metro Laboratory'), findsOneWidget);

      // Verify expanded body contains conclusion callout note with notes icon
      expect(find.byIcon(Icons.notes), findsOneWidget);
      expect(
        find.text('All lipid analytes are within desirable baseline limits.'),
        findsOneWidget,
      );

      // Verify analytes are rendered
      expect(find.text('Total Cholesterol'), findsOneWidget);
      expect(find.text('HDL Cholesterol'), findsOneWidget);
    });

    testWidgets(
      'RecordDetailsSheet displays panel name, conclusion, and performer',
      (tester) async {
        final now = DateTime.utc(2026, 10, 26, 12, 0);
        final record = HealthRecord(
          id: 'rec-detail-1',
          name: 'Total Cholesterol',
          value: '185',
          unit: 'mg/dL',
          recordedAt: now,
          category: RecordCategory.lab,
          source: 'LabCorp',
          sourceData: const {
            'panel': {
              'id': 'dr-123',
              'name': 'Lipid Panel with Reflex',
              'performer': 'LabCorp Central',
              'conclusion': 'Optimal profile.',
            },
          },
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RecordDetailsSheet(record: record, isNumeric: true),
            ),
          ),
        );

        expect(find.text('Clinical panel'), findsOneWidget);
        expect(find.text('Lipid Panel with Reflex'), findsOneWidget);
        expect(find.text('Diagnostic performer'), findsOneWidget);
        expect(find.text('LabCorp Central'), findsOneWidget);
        expect(find.text('Report conclusion'), findsOneWidget);
        expect(find.text('Optimal profile.'), findsOneWidget);
      },
    );
  });
}
