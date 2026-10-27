import 'dart:convert';

import 'package:clinical_assistant/integrations/fhir_file_import.dart';
import 'package:clinical_assistant/ui/connections/connections_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class MockFhirFilePickerService extends FhirFilePickerService {
  MockFhirFilePickerService(this.mockFiles);

  final List<FhirFilePayload>? mockFiles;

  @override
  Future<List<FhirFilePayload>?> pickFiles({
    List<String> allowedExtensions = const ['json', 'fhir'],
  }) async {
    return mockFiles;
  }
}

String _observationBundle(
  String id,
  String testName,
  double value,
  String unit,
) {
  return jsonEncode({
    'resourceType': 'Bundle',
    'id': 'bundle-$id',
    'type': 'collection',
    'entry': [
      {
        'resource': {
          'resourceType': 'Observation',
          'id': id,
          'status': 'final',
          'code': {
            'coding': [
              {
                'system': 'http://loinc.org',
                'code': '1558-6',
                'display': testName,
              },
            ],
            'text': testName,
          },
          'subject': {'reference': 'Patient/p1'},
          'effectiveDateTime': '2026-03-15T08:30:00Z',
          'valueQuantity': {
            'value': value,
            'unit': unit,
            'system': 'http://unitsofmeasure.org',
            'code': unit,
          },
        },
      },
    ],
  });
}

void main() {
  group('FhirJsonImportCard UI', () {
    testWidgets('renders Choose FHIR File(s) and Paste FHIR JSON buttons', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FhirJsonImportCard(
              busy: false,
              onImport: (json, {source = 'FHIR File'}) async {},
              onImportFiles: (files, {source}) async {},
            ),
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey('connection-pick-fhir-file-button')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('connection-import-fhir-json-button')),
        findsOneWidget,
      );
      expect(find.text('Choose FHIR File(s)'), findsOneWidget);
      expect(find.text('Paste FHIR JSON'), findsOneWidget);
    });

    testWidgets('triggers file picker and opens sheet with chosen files', (
      tester,
    ) async {
      final mockFiles = [
        FhirFilePayload(
          name: 'patient_labs.json',
          content: _observationBundle('obs-1', 'Hemoglobin A1c', 5.7, '%'),
          sizeInBytes: 1024,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FhirJsonImportCard(
              busy: false,
              filePickerService: MockFhirFilePickerService(mockFiles),
              onImportFiles: (files, {source}) async {},
            ),
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('connection-pick-fhir-file-button')),
      );
      await tester.pumpAndSettle();

      // Verify the bottom sheet opened showing the chosen file preview
      expect(find.text('FHIR File Import'), findsOneWidget);
      expect(find.widgetWithText(Card, 'patient_labs.json'), findsOneWidget);
      expect(find.text('Observation: 1'), findsWidgets);
      expect(find.text('Ready to import 1 record'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('fhir-json-submit-button')),
        findsOneWidget,
      );
    });
  });

  group('FhirJsonImportSheet UI', () {
    testWidgets(
      'renders preview for multiple files, handles removing a file and confirms import',
      (tester) async {
        final file1 = FhirFilePayload(
          name: 'blood_test.json',
          content: _observationBundle('obs-1', 'Glucose', 99.0, 'mg/dL'),
          sizeInBytes: 850,
        );
        final file2 = FhirFilePayload(
          name: 'metabolic.json',
          content: _observationBundle('obs-2', 'Calcium', 9.5, 'mg/dL'),
          sizeInBytes: 950,
        );

        List<FhirFilePayload>? importedFiles;
        String? importedSource;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: FhirJsonImportSheet(
                initialFiles: [file1, file2],
                onImportFiles: (files, source) async {
                  importedFiles = files;
                  importedSource = source;
                },
              ),
            ),
          ),
        );

        expect(find.text('Selected Files (2)'), findsOneWidget);
        expect(find.widgetWithText(Card, 'blood_test.json'), findsOneWidget);
        expect(find.widgetWithText(Card, 'metabolic.json'), findsOneWidget);
        expect(find.text('Ready to import 2 records'), findsOneWidget);

        // Remove the second file
        final removeBtn = find.byKey(
          const ValueKey('fhir-file-remove-metabolic.json'),
        );
        expect(removeBtn, findsOneWidget);
        await tester.tap(removeBtn);
        await tester.pumpAndSettle();

        // Now only 1 file remains
        expect(find.text('Selected Files (1)'), findsOneWidget);
        expect(find.widgetWithText(Card, 'blood_test.json'), findsOneWidget);
        expect(find.widgetWithText(Card, 'metabolic.json'), findsNothing);
        expect(find.text('Ready to import 1 record'), findsOneWidget);

        // Submit
        final submitBtn = find.byKey(const ValueKey('fhir-json-submit-button'));
        expect(submitBtn, findsOneWidget);
        await tester.tap(submitBtn);
        await tester.pumpAndSettle();

        expect(importedFiles, isNotNull);
        expect(importedFiles!.length, 1);
        expect(importedFiles!.first.name, 'blood_test.json');
        expect(importedSource, 'blood_test.json');
      },
    );

    testWidgets('disables submit when a file has validation errors', (
      tester,
    ) async {
      final valid = FhirFilePayload(
        name: 'valid.json',
        content: _observationBundle('obs-1', 'Sodium', 140.0, 'mmol/L'),
      );
      const invalid = FhirFilePayload(
        name: 'corrupted.json',
        content: '{ broken-fhir }',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FhirJsonImportSheet(
              initialFiles: [valid, invalid],
              onImportFiles: (files, source) async {},
            ),
          ),
        ),
      );

      // Error message for corrupted file is visible
      expect(find.text('corrupted.json'), findsOneWidget);
      expect(
        find.textContaining('One or more files have errors'),
        findsOneWidget,
      );

      // The submit button is disabled
      final submitButton = tester.widget<FilledButton>(
        find.byKey(const ValueKey('fhir-json-submit-button')),
      );
      expect(submitButton.onPressed, isNull);

      // Remove the corrupted file
      await tester.tap(
        find.byKey(const ValueKey('fhir-file-remove-corrupted.json')),
      );
      await tester.pumpAndSettle();

      // Error is gone and button is re-enabled
      expect(
        find.textContaining('One or more files have errors'),
        findsNothing,
      );
      final updatedSubmitButton = tester.widget<FilledButton>(
        find.byKey(const ValueKey('fhir-json-submit-button')),
      );
      expect(updatedSubmitButton.onPressed, isNotNull);
    });

    testWidgets('supports pasting FHIR JSON when no files are selected', (
      tester,
    ) async {
      String? importedContent;
      String? importedSource;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FhirJsonImportSheet(
              onImportJson: (content, source) async {
                importedContent = content;
                importedSource = source;
              },
            ),
          ),
        ),
      );

      expect(find.text('OR PASTE FHIR JSON'), findsOneWidget);
      final inputField = find.byKey(const ValueKey('fhir-json-input-field'));
      expect(inputField, findsOneWidget);

      final validJson = _observationBundle(
        'obs-paste',
        'Potassium',
        4.5,
        'mmol/L',
      );
      await tester.enterText(inputField, validJson);
      await tester.pumpAndSettle();

      expect(find.text('Ready to import 1 record'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('fhir-json-submit-button')));
      await tester.pumpAndSettle();

      expect(importedContent, validJson);
      expect(importedSource, 'FHIR Import');
    });
  });
}
