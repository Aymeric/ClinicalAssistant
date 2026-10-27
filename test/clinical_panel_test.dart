import 'dart:convert';

import 'package:clinical_assistant/exports/health_export_service.dart';
import 'package:clinical_assistant/integrations/fhir_observation_parser.dart';
import 'package:clinical_assistant/models/clinical_panel.dart';
import 'package:clinical_assistant/models/health_record.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ClinicalPanelPreset definitions', () {
    test('standard presets contain expected panels and analytes', () {
      expect(kStandardClinicalPanels.length, 4);
      final names = kStandardClinicalPanels.map((p) => p.name).toList();
      expect(names, contains('Lipid Panel'));
      expect(names, contains('Basic Metabolic Panel (BMP)'));
      expect(names, contains('Comprehensive Metabolic Panel (CMP)'));
      expect(names, contains('Complete Blood Count (CBC)'));

      final lipid = kStandardClinicalPanels.firstWhere(
        (p) => p.name == 'Lipid Panel',
      );
      expect(lipid.analytes.length, 4);
      expect(
        lipid.analytes.map((a) => a.name).toList(),
        containsAll([
          'Total Cholesterol',
          'HDL Cholesterol',
          'LDL Cholesterol',
          'Triglycerides',
        ]),
      );
    });
  });

  group('groupRecordsIntoListItems', () {
    final now = DateTime.utc(2026, 10, 26, 12, 0);

    test('groups lab records sharing same panel, source, and timestamp', () {
      final records = [
        HealthRecord(
          id: 'rec-1',
          name: 'Total Cholesterol',
          value: '190',
          unit: 'mg/dL',
          recordedAt: now,
          category: RecordCategory.lab,
          source: 'LabCorp',
          referenceRange: '< 200 mg/dL',
          sourceData: const {
            'panel': {'id': 'panel-lipid-1', 'name': 'Lipid Panel'},
          },
        ),
        HealthRecord(
          id: 'rec-2',
          name: 'HDL Cholesterol',
          value: '50',
          unit: 'mg/dL',
          recordedAt: now,
          category: RecordCategory.lab,
          source: 'LabCorp',
          referenceRange: '> 40 mg/dL',
          sourceData: const {
            'panel': {'id': 'panel-lipid-1', 'name': 'Lipid Panel'},
          },
        ),
        HealthRecord(
          id: 'rec-3',
          name: 'Blood Pressure',
          value: '120/80',
          unit: 'mmHg',
          recordedAt: now,
          category: RecordCategory.vital,
          source: 'Clinic',
        ),
      ];

      final items = groupRecordsIntoListItems(records);
      expect(items.length, 2);

      expect(items[0], isA<GroupedPanelListItem>());
      final panelItem = items[0] as GroupedPanelListItem;
      expect(panelItem.panel.name, 'Lipid Panel');
      expect(panelItem.panel.analyteCount, 2);
      expect(panelItem.panel.outOfRangeCount, 0);

      expect(items[1], isA<SingleRecordListItem>());
      final singleItem = items[1] as SingleRecordListItem;
      expect(singleItem.record.name, 'Blood Pressure');
    });

    test('does not group records if only 1 record exists in the panel', () {
      final records = [
        HealthRecord(
          id: 'rec-lonely',
          name: 'Total Cholesterol',
          value: '190',
          unit: 'mg/dL',
          recordedAt: now,
          category: RecordCategory.lab,
          source: 'LabCorp',
          sourceData: const {
            'panel': {'id': 'panel-lipid-1', 'name': 'Lipid Panel'},
          },
        ),
      ];

      final items = groupRecordsIntoListItems(records);
      expect(items.length, 1);
      expect(items.first, isA<SingleRecordListItem>());
    });

    test('does not group records if timestamps or sources differ', () {
      final records = [
        HealthRecord(
          id: 'rec-1',
          name: 'Glucose',
          value: '95',
          unit: 'mg/dL',
          recordedAt: now,
          category: RecordCategory.lab,
          source: 'LabCorp',
          sourceData: const {
            'panel': {'id': 'bmp-1', 'name': 'BMP'},
          },
        ),
        HealthRecord(
          id: 'rec-2',
          name: 'Potassium',
          value: '4.2',
          unit: 'mmol/L',
          recordedAt: now.add(const Duration(hours: 1)),
          category: RecordCategory.lab,
          source: 'LabCorp',
          sourceData: const {
            'panel': {'id': 'bmp-1', 'name': 'BMP'},
          },
        ),
      ];

      final items = groupRecordsIntoListItems(records);
      expect(items.length, 2);
      expect(items.every((it) => it is SingleRecordListItem), isTrue);
    });

    test('calculates outOfRangeCount accurately for high and low analytes', () {
      final panel = ClinicalPanel(
        id: 'p-1',
        name: 'Metabolic Panel',
        recordedAt: now,
        source: 'Lab',
        records: [
          HealthRecord(
            id: '1',
            name: 'Sodium',
            value: '140', // Normal
            unit: 'mmol/L',
            recordedAt: now,
            category: RecordCategory.lab,
            source: 'Lab',
            referenceRange: '135 – 145 mmol/L',
          ),
          HealthRecord(
            id: '2',
            name: 'Potassium',
            value: '5.8', // High
            unit: 'mmol/L',
            recordedAt: now,
            category: RecordCategory.lab,
            source: 'Lab',
            referenceRange: '3.5 – 5.0 mmol/L',
          ),
          HealthRecord(
            id: '3',
            name: 'Calcium',
            value: '7.9', // Low
            unit: 'mg/dL',
            recordedAt: now,
            category: RecordCategory.lab,
            source: 'Lab',
            referenceRange: '8.5 – 10.5 mg/dL',
          ),
        ],
      );

      expect(panel.analyteCount, 3);
      expect(panel.outOfRangeCount, 2);
    });
  });

  group('FHIR Parser Panel Linkage', () {
    const parser = FhirObservationParser();

    test('preserves panel metadata from DiagnosticReport.result references', () {
      final bundle = {
        'resourceType': 'Bundle',
        'entry': [
          {
            'resource': {
              'resourceType': 'DiagnosticReport',
              'id': 'report-lipid-100',
              'code': {
                'text': 'Lipid Panel',
                'coding': [
                  {'system': 'http://loinc.org', 'code': '24331-1'},
                ],
              },
              'result': [
                {'reference': 'Observation/obs-chol'},
                {'reference': 'Observation/obs-trig'},
              ],
            },
          },
          {
            'resource': {
              'resourceType': 'Observation',
              'id': 'obs-chol',
              'status': 'final',
              'category': [
                {
                  'coding': [
                    {
                      'system':
                          'http://terminology.hl7.org/CodeSystem/observation-category',
                      'code': 'laboratory',
                    },
                  ],
                },
              ],
              'code': {
                'text': 'Cholesterol in LDL',
                'coding': [
                  {'system': 'http://loinc.org', 'code': '13457-7'},
                ],
              },
              'effectiveDateTime': '2026-10-25T08:00:00Z',
              'valueQuantity': {'value': 115, 'unit': 'mg/dL'},
              'referenceRange': [
                {'text': '< 100 mg/dL'},
              ],
            },
          },
          {
            'resource': {
              'resourceType': 'Observation',
              'id': 'obs-trig',
              'status': 'final',
              'category': [
                {
                  'coding': [
                    {
                      'system':
                          'http://terminology.hl7.org/CodeSystem/observation-category',
                      'code': 'laboratory',
                    },
                  ],
                },
              ],
              'code': {
                'text': 'Triglycerides',
                'coding': [
                  {'system': 'http://loinc.org', 'code': '2571-8'},
                ],
              },
              'effectiveDateTime': '2026-10-25T08:00:00Z',
              'valueQuantity': {'value': 140, 'unit': 'mg/dL'},
              'referenceRange': [
                {'text': '< 150 mg/dL'},
              ],
            },
          },
        ],
      };

      final records = parser.parseBundle(bundle, source: 'FHIR Export');
      expect(records.length, 2);

      for (final record in records) {
        final panelInfo = extractRecordPanelInfo(record);
        expect(panelInfo, isNotNull);
        expect(panelInfo!.name, 'Lipid Panel');
        expect(panelInfo.id, 'report-lipid-100');
      }

      final items = groupRecordsIntoListItems(records);
      expect(items.length, 1);
      expect(items.first, isA<GroupedPanelListItem>());
      final panelItem = items.first as GroupedPanelListItem;
      expect(panelItem.panel.name, 'Lipid Panel');
      expect(panelItem.panel.analyteCount, 2);
    });

    test('preserves panel metadata from Observation.hasMember references', () {
      final bundle = {
        'resourceType': 'Bundle',
        'entry': [
          {
            'resource': {
              'resourceType': 'Observation',
              'id': 'obs-parent-bmp',
              'status': 'final',
              'code': {
                'text': 'Basic Metabolic Panel',
                'coding': [
                  {'system': 'http://loinc.org', 'code': '24321-2'},
                ],
              },
              'hasMember': [
                {'reference': 'obs-glu'},
                {'reference': 'obs-na'},
              ],
            },
          },
          {
            'resource': {
              'resourceType': 'Observation',
              'id': 'obs-glu',
              'status': 'final',
              'code': {'text': 'Glucose'},
              'effectiveDateTime': '2026-10-25T09:00:00Z',
              'valueQuantity': {'value': 88, 'unit': 'mg/dL'},
            },
          },
          {
            'resource': {
              'resourceType': 'Observation',
              'id': 'obs-na',
              'status': 'final',
              'code': {'text': 'Sodium'},
              'effectiveDateTime': '2026-10-25T09:00:00Z',
              'valueQuantity': {'value': 138, 'unit': 'mmol/L'},
            },
          },
        ],
      };

      final records = parser.parseJson(jsonEncode(bundle));
      expect(records.length, 2);

      for (final record in records) {
        final panelInfo = extractRecordPanelInfo(record);
        expect(panelInfo, isNotNull);
        expect(panelInfo!.name, 'Basic Metabolic Panel');
      }
    });
  });

  group('PDF Doctor Visit Summary with Panel Metadata', () {
    test(
      'renders panel name alongside lab test names in visit summary',
      () async {
        final now = DateTime.utc(2026, 10, 26, 10, 0);
        final records = [
          HealthRecord(
            id: 'rec-c1',
            name: 'Total Cholesterol',
            value: '225', // High
            unit: 'mg/dL',
            recordedAt: now,
            category: RecordCategory.lab,
            source: 'Quest',
            referenceRange: '< 200 mg/dL',
            sourceData: const {
              'panel': {'id': 'quest-lip-1', 'name': 'Lipid Panel'},
            },
          ),
          HealthRecord(
            id: 'rec-c2',
            name: 'HDL Cholesterol',
            value: '52', // Normal
            unit: 'mg/dL',
            recordedAt: now,
            category: RecordCategory.lab,
            source: 'Quest',
            referenceRange: '> 40 mg/dL',
            sourceData: const {
              'panel': {'id': 'quest-lip-1', 'name': 'Lipid Panel'},
            },
          ),
        ];

        final service = HealthExportService();
        final pdfDoc = await service.buildDoctorVisitSummaryPdfDocument(
          records,
        );
        final bytes = await pdfDoc.save();
        expect(bytes, isNotEmpty);
      },
    );
  });
}
