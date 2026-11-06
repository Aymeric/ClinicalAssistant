import 'package:clinical_assistant/exports/health_export_service.dart';
import 'package:clinical_assistant/models/doctor_visit_preparation.dart';
import 'package:clinical_assistant/models/health_record.dart';
import 'package:clinical_assistant/models/manual_medication_details.dart';
import 'package:clinical_assistant/models/medication_adherence_log.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late HealthExportService exporter;

  setUp(() {
    exporter = HealthExportService();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => '/tmp',
        );
  });

  group('DoctorVisitPreparationConfig & Smart Suggestions', () {
    test('initializes with sensible defaults and supports copyWith', () {
      final config = DoctorVisitPreparationConfig(
        specialty: DoctorVisitSpecialty.cardiology,
        clinicianName: 'Dr. Sarah Chen',
        facilityName: 'Metro Heart Institute',
        selectedRecordIds: {'rec-1', 'rec-2'},
        medicationNotes: {'Lisinopril': 'Causes dry cough'},
        agendaItems: ['Discuss dosage reduction'],
      );

      expect(config.specialty, DoctorVisitSpecialty.cardiology);
      expect(config.clinicianName, 'Dr. Sarah Chen');
      expect(config.facilityName, 'Metro Heart Institute');
      expect(config.selectedRecordIds, contains('rec-1'));
      expect(config.medicationNotes['Lisinopril'], 'Causes dry cough');
      expect(config.agendaItems, contains('Discuss dosage reduction'));
      expect(config.includeVitals, isTrue);

      final updated = config.copyWith(
        specialty: DoctorVisitSpecialty.endocrinology,
        clinicianName: 'Dr. Robert Patel',
      );
      expect(updated.specialty, DoctorVisitSpecialty.endocrinology);
      expect(updated.clinicianName, 'Dr. Robert Patel');
      expect(updated.facilityName, 'Metro Heart Institute');
    });

    test(
      'generates smart suggestions for Cardiology with elevated BP and lipids',
      () {
        final records = [
          HealthRecord(
            id: 'bp-sys',
            name: 'Systolic Blood Pressure',
            value: '148',
            unit: 'mmHg',
            recordedAt: DateTime.utc(2026, 10, 15),
            category: RecordCategory.vital,
            source: 'Manual Entry',
            referenceRange: '< 120 mmHg',
          ),
          HealthRecord(
            id: 'lab-ldl',
            name: 'LDL Cholesterol',
            value: '165',
            unit: 'mg/dL',
            recordedAt: DateTime.utc(2026, 10, 10),
            category: RecordCategory.lab,
            source: 'Quest Diagnostics',
            referenceRange: '< 100 mg/dL',
          ),
          HealthRecord(
            id: 'med-atorvastatin',
            name: 'Atorvastatin',
            value: '20 mg',
            unit: 'tablet',
            recordedAt: DateTime.utc(2026, 10, 1),
            category: RecordCategory.medication,
            source: 'Hospital Portal',
          ),
        ];

        final suggestions =
            DoctorVisitPreparationConfig.generateSmartSuggestions(
              records: records,
              specialty: DoctorVisitSpecialty.cardiology,
            );

        expect(
          suggestions.any((s) => s.contains('blood pressure averages')),
          isTrue,
        );
        expect(suggestions.any((s) => s.contains('chest discomfort')), isTrue);
        expect(
          suggestions.any(
            (s) => s.contains('LDL Cholesterol') && s.contains('elevated'),
          ),
          isTrue,
        );
        expect(suggestions.any((s) => s.contains('140 mmHg')), isTrue);
        expect(
          suggestions.any(
            (s) => s.contains('Review current prescription dosages'),
          ),
          isTrue,
        );
      },
    );

    test(
      'generates smart suggestions for Endocrinology with elevated glucose',
      () {
        final records = [
          HealthRecord(
            id: 'glucose-1',
            name: 'Blood Glucose',
            value: '195',
            unit: 'mg/dL',
            recordedAt: DateTime.utc(2026, 10, 12),
            category: RecordCategory.vital,
            source: 'Contour Next',
            referenceRange: '70 - 99 mg/dL',
          ),
        ];

        final suggestions =
            DoctorVisitPreparationConfig.generateSmartSuggestions(
              records: records,
              specialty: DoctorVisitSpecialty.endocrinology,
            );

        expect(
          suggestions.any((s) => s.contains('fasting vs. post-meal glucose')),
          isTrue,
        );
        expect(suggestions.any((s) => s.contains('low blood sugar')), isTrue);
        expect(
          suggestions.any(
            (s) => s.contains('glucose readings above 180 mg/dL'),
          ),
          isTrue,
        );
      },
    );

    test(
      'generates smart suggestion when a medication has <80% 30-day PDC adherence',
      () {
        final now = DateTime.now().toUtc();
        final medRecord = HealthRecord(
          id: 'med-low-pdc',
          name: 'Atorvastatin',
          value: '20 mg',
          unit: '',
          recordedAt: now.subtract(const Duration(days: 30)),
          category: RecordCategory.medication,
          source: 'Manual Entry',
          status: 'active',
          sourceData: ManualMedicationDetails(
            frequency: 'Once daily',
            adherenceLogs: [
              MedicationAdherenceLog(
                id: 'l-1',
                medicationId: 'med-low-pdc',
                medicationName: 'Atorvastatin',
                takenAt: now.subtract(const Duration(days: 2)),
                status: MedicationAdherenceStatus.taken,
              ),
              MedicationAdherenceLog(
                id: 'l-2',
                medicationId: 'med-low-pdc',
                medicationName: 'Atorvastatin',
                takenAt: now.subtract(const Duration(days: 1)),
                status: MedicationAdherenceStatus.skipped,
              ),
            ],
          ).withSourceData(null),
        );

        final suggestions =
            DoctorVisitPreparationConfig.generateSmartSuggestions(
              records: [medRecord],
              specialty: DoctorVisitSpecialty.cardiology,
            );

        expect(
          suggestions.any(
            (s) => s.contains('Atorvastatin') && s.contains('30-day PDC'),
          ),
          isTrue,
        );
      },
    );
  });

  group('HealthExportService Specialty-Tailored PDF Templates', () {
    final now = DateTime.utc(2026, 10, 20);
    final sampleRecords = [
      HealthRecord(
        id: 'sys-bp',
        name: 'Systolic Blood Pressure',
        value: '138',
        unit: 'mmHg',
        recordedAt: now,
        category: RecordCategory.vital,
        source: 'Home Monitor',
        referenceRange: '< 120 mmHg',
      ),
      HealthRecord(
        id: 'dia-bp',
        name: 'Diastolic Blood Pressure',
        value: '86',
        unit: 'mmHg',
        recordedAt: now,
        category: RecordCategory.vital,
        source: 'Home Monitor',
        referenceRange: '< 80 mmHg',
      ),
      HealthRecord(
        id: 'lab-chol',
        name: 'Total Cholesterol',
        value: '220',
        unit: 'mg/dL',
        recordedAt: now,
        category: RecordCategory.lab,
        source: 'LabCorp',
        referenceRange: '< 200 mg/dL',
      ),
      HealthRecord(
        id: 'lab-glucose',
        name: 'Blood Glucose',
        value: '110',
        unit: 'mg/dL',
        recordedAt: now,
        category: RecordCategory.vital,
        source: 'Dexcom G7',
        referenceRange: '70 - 99 mg/dL',
        sourceData: {'context': 'Post-meal (2 hr)'},
      ),
      HealthRecord(
        id: 'lab-creatinine',
        name: 'Creatinine',
        value: '1.0',
        unit: 'mg/dL',
        recordedAt: now,
        category: RecordCategory.lab,
        source: 'LabCorp',
        referenceRange: '0.7 - 1.3 mg/dL',
      ),
      HealthRecord(
        id: 'med-lisinopril',
        name: 'Lisinopril',
        value: '10 mg',
        unit: 'tablet',
        recordedAt: now,
        category: RecordCategory.medication,
        source: 'Care Portal',
      ),
    ];

    test(
      'builds Cardiology consultation PDF with cardiac sections & patient notes',
      () async {
        final config = DoctorVisitPreparationConfig(
          specialty: DoctorVisitSpecialty.cardiology,
          clinicianName: 'Dr. Evans',
          facilityName: 'Heart Care Center',
          visitDate: DateTime(2026, 10, 25),
          medicationNotes: {
            'Lisinopril': 'Occasional dizziness when standing up',
          },
          agendaItems: [
            'Review blood pressure averages',
            'Ask about increasing exercise safely',
          ],
        );

        final doc = await exporter.buildDoctorVisitSummaryPdfDocument(
          sampleRecords,
          config: config,
        );

        final bytes = await doc.save();
        expect(bytes, isNotEmpty);
        expect(bytes.length, greaterThan(1500));
      },
    );

    test(
      'builds Endocrinology consultation PDF with glycemic log & kidney markers',
      () async {
        final config = DoctorVisitPreparationConfig(
          specialty: DoctorVisitSpecialty.endocrinology,
          clinicianName: 'Dr. Gupta',
          facilityName: 'Endocrine Care Clinic',
          visitDate: DateTime(2026, 10, 28),
          medicationNotes: {'Metformin': 'Mild stomach upset'},
          agendaItems: [
            'Discuss continuous glucose monitor trends',
            'Evaluate post-prandial spikes',
          ],
        );

        final doc = await exporter.buildDoctorVisitSummaryPdfDocument(
          sampleRecords,
          config: config,
        );

        final bytes = await doc.save();
        expect(bytes, isNotEmpty);
        expect(bytes.length, greaterThan(1500));
      },
    );

    test('builds Annual Wellness PDF with comprehensive overview', () async {
      final config = DoctorVisitPreparationConfig(
        specialty: DoctorVisitSpecialty.annualWellness,
        clinicianName: 'Dr. Miller',
        visitDate: DateTime(2026, 11, 2),
        agendaItems: ['Annual wellness screening checklist'],
      );

      final doc = await exporter.buildDoctorVisitSummaryPdfDocument(
        sampleRecords,
        config: config,
      );

      final bytes = await doc.save();
      expect(bytes, isNotEmpty);
      expect(bytes.length, greaterThan(1200));
    });

    test(
      'createDoctorVisitSummaryPdf writes specialty PDF file to disk',
      () async {
        final config = DoctorVisitPreparationConfig(
          specialty: DoctorVisitSpecialty.cardiology,
          agendaItems: ['Test file persistence'],
        );

        final file = await exporter.createDoctorVisitSummaryPdf(
          sampleRecords,
          config: config,
        );

        expect(await file.exists(), isTrue);
        expect(await file.length(), greaterThan(1000));
        await file.delete();
      },
    );
  });
}
