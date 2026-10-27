import '../models/health_record.dart';
import '../trends/health_trend.dart';

/// Represents a standardized clinical lab panel definition with default analytes.
class ClinicalPanelPreset {
  const ClinicalPanelPreset({
    required this.name,
    this.loincCode,
    required this.analytes,
  });

  final String name;
  final String? loincCode;
  final List<PanelAnalytePreset> analytes;
}

/// Represents a single analyte within a panel preset.
class PanelAnalytePreset {
  const PanelAnalytePreset({
    required this.name,
    required this.unit,
    required this.defaultRefRange,
    this.loincCode,
  });

  final String name;
  final String unit;
  final String defaultRefRange;
  final String? loincCode;
}

/// Standard predefined clinical lab panels.
const kStandardClinicalPanels = [
  ClinicalPanelPreset(
    name: 'Lipid Panel',
    loincCode: '24331-1',
    analytes: [
      PanelAnalytePreset(
        name: 'Total Cholesterol',
        unit: 'mg/dL',
        defaultRefRange: '< 200 mg/dL',
        loincCode: '2093-3',
      ),
      PanelAnalytePreset(
        name: 'HDL Cholesterol',
        unit: 'mg/dL',
        defaultRefRange: '> 40 mg/dL',
        loincCode: '2085-9',
      ),
      PanelAnalytePreset(
        name: 'LDL Cholesterol',
        unit: 'mg/dL',
        defaultRefRange: '< 100 mg/dL',
        loincCode: '13457-7',
      ),
      PanelAnalytePreset(
        name: 'Triglycerides',
        unit: 'mg/dL',
        defaultRefRange: '< 150 mg/dL',
        loincCode: '2571-8',
      ),
    ],
  ),
  ClinicalPanelPreset(
    name: 'Basic Metabolic Panel (BMP)',
    loincCode: '24321-2',
    analytes: [
      PanelAnalytePreset(
        name: 'Glucose',
        unit: 'mg/dL',
        defaultRefRange: '70 – 99 mg/dL',
        loincCode: '2345-7',
      ),
      PanelAnalytePreset(
        name: 'Calcium',
        unit: 'mg/dL',
        defaultRefRange: '8.5 – 10.5 mg/dL',
        loincCode: '17861-6',
      ),
      PanelAnalytePreset(
        name: 'Sodium',
        unit: 'mmol/L',
        defaultRefRange: '135 – 145 mmol/L',
        loincCode: '2951-2',
      ),
      PanelAnalytePreset(
        name: 'Potassium',
        unit: 'mmol/L',
        defaultRefRange: '3.5 – 5.0 mmol/L',
        loincCode: '2823-3',
      ),
      PanelAnalytePreset(
        name: 'Carbon Dioxide (CO2)',
        unit: 'mmol/L',
        defaultRefRange: '22 – 29 mmol/L',
        loincCode: '2028-9',
      ),
      PanelAnalytePreset(
        name: 'Chloride',
        unit: 'mmol/L',
        defaultRefRange: '96 – 106 mmol/L',
        loincCode: '2075-0',
      ),
      PanelAnalytePreset(
        name: 'Blood Urea Nitrogen (BUN)',
        unit: 'mg/dL',
        defaultRefRange: '7 – 20 mg/dL',
        loincCode: '3094-0',
      ),
      PanelAnalytePreset(
        name: 'Creatinine',
        unit: 'mg/dL',
        defaultRefRange: '0.6 – 1.2 mg/dL',
        loincCode: '2160-0',
      ),
    ],
  ),
  ClinicalPanelPreset(
    name: 'Comprehensive Metabolic Panel (CMP)',
    loincCode: '24323-8',
    analytes: [
      PanelAnalytePreset(
        name: 'Glucose',
        unit: 'mg/dL',
        defaultRefRange: '70 – 99 mg/dL',
        loincCode: '2345-7',
      ),
      PanelAnalytePreset(
        name: 'Calcium',
        unit: 'mg/dL',
        defaultRefRange: '8.5 – 10.5 mg/dL',
        loincCode: '17861-6',
      ),
      PanelAnalytePreset(
        name: 'Sodium',
        unit: 'mmol/L',
        defaultRefRange: '135 – 145 mmol/L',
        loincCode: '2951-2',
      ),
      PanelAnalytePreset(
        name: 'Potassium',
        unit: 'mmol/L',
        defaultRefRange: '3.5 – 5.0 mmol/L',
        loincCode: '2823-3',
      ),
      PanelAnalytePreset(
        name: 'Carbon Dioxide (CO2)',
        unit: 'mmol/L',
        defaultRefRange: '22 – 29 mmol/L',
        loincCode: '2028-9',
      ),
      PanelAnalytePreset(
        name: 'Chloride',
        unit: 'mmol/L',
        defaultRefRange: '96 – 106 mmol/L',
        loincCode: '2075-0',
      ),
      PanelAnalytePreset(
        name: 'Blood Urea Nitrogen (BUN)',
        unit: 'mg/dL',
        defaultRefRange: '7 – 20 mg/dL',
        loincCode: '3094-0',
      ),
      PanelAnalytePreset(
        name: 'Creatinine',
        unit: 'mg/dL',
        defaultRefRange: '0.6 – 1.2 mg/dL',
        loincCode: '2160-0',
      ),
      PanelAnalytePreset(
        name: 'Total Protein',
        unit: 'g/dL',
        defaultRefRange: '6.0 – 8.3 g/dL',
        loincCode: '2885-2',
      ),
      PanelAnalytePreset(
        name: 'Albumin',
        unit: 'g/dL',
        defaultRefRange: '3.5 – 5.0 g/dL',
        loincCode: '1751-7',
      ),
      PanelAnalytePreset(
        name: 'Bilirubin (Total)',
        unit: 'mg/dL',
        defaultRefRange: '0.2 – 1.2 mg/dL',
        loincCode: '1975-2',
      ),
      PanelAnalytePreset(
        name: 'Alkaline Phosphatase (ALP)',
        unit: 'U/L',
        defaultRefRange: '44 – 147 U/L',
        loincCode: '6768-6',
      ),
      PanelAnalytePreset(
        name: 'AST (SGOT)',
        unit: 'U/L',
        defaultRefRange: '10 – 40 U/L',
        loincCode: '1920-8',
      ),
      PanelAnalytePreset(
        name: 'ALT (SGPT)',
        unit: 'U/L',
        defaultRefRange: '7 – 56 U/L',
        loincCode: '1742-6',
      ),
    ],
  ),
  ClinicalPanelPreset(
    name: 'Complete Blood Count (CBC)',
    loincCode: '57021-8',
    analytes: [
      PanelAnalytePreset(
        name: 'White Blood Cell (WBC)',
        unit: '10^3/uL',
        defaultRefRange: '4.5 – 11.0 10^3/uL',
        loincCode: '6690-2',
      ),
      PanelAnalytePreset(
        name: 'Red Blood Cell (RBC)',
        unit: '10^6/uL',
        defaultRefRange: '4.3 – 5.9 10^6/uL',
        loincCode: '789-8',
      ),
      PanelAnalytePreset(
        name: 'Hemoglobin',
        unit: 'g/dL',
        defaultRefRange: '13.5 – 17.5 g/dL',
        loincCode: '718-7',
      ),
      PanelAnalytePreset(
        name: 'Hematocrit',
        unit: '%',
        defaultRefRange: '38.8 – 50.0 %',
        loincCode: '4544-3',
      ),
      PanelAnalytePreset(
        name: 'Platelets',
        unit: '10^3/uL',
        defaultRefRange: '150 – 450 10^3/uL',
        loincCode: '777-3',
      ),
    ],
  ),
];

/// Encapsulates a cohesive group of laboratory analytes sharing a common order,
/// source, and timestamp.
class ClinicalPanel {
  const ClinicalPanel({
    required this.id,
    required this.name,
    required this.recordedAt,
    required this.source,
    required this.records,
  });

  final String id;
  final String name;
  final DateTime recordedAt;
  final String source;
  final List<HealthRecord> records;

  int get analyteCount => records.length;

  int get outOfRangeCount {
    return records.where((r) {
      if (r.referenceRange == null || r.referenceRange!.isEmpty) return false;
      final range = HealthReferenceRange.tryParse(r.referenceRange);
      final numVal = parseHealthRecordValue(r.value);
      if (range == null || numVal == null) return false;
      final status = range.evaluate(numVal);
      return status == HealthReferenceStatus.above ||
          status == HealthReferenceStatus.below;
    }).length;
  }
}

/// Extracts the panel name and panel identifier from a [HealthRecord]'s sourceData if present.
({String id, String name})? extractRecordPanelInfo(HealthRecord record) {
  final sourceData = record.sourceData;
  if (sourceData == null) return null;

  final panelData = sourceData['panel'];
  if (panelData is Map) {
    final id = panelData['id']?.toString();
    final name = panelData['name']?.toString();
    if (name != null && name.trim().isNotEmpty) {
      return (
        id:
            id ??
            '${record.source}_${record.recordedAt.millisecondsSinceEpoch}_$name',
        name: name.trim(),
      );
    }
  }

  return null;
}

/// Abstract item in the records list: either a standalone record or a grouped clinical panel.
sealed class RecordListItem {
  const RecordListItem();
  DateTime get recordedAt;
  String get displayName;
}

class SingleRecordListItem extends RecordListItem {
  const SingleRecordListItem(this.record);
  final HealthRecord record;

  @override
  DateTime get recordedAt => record.recordedAt;

  @override
  String get displayName => record.name;
}

class GroupedPanelListItem extends RecordListItem {
  const GroupedPanelListItem(this.panel);
  final ClinicalPanel panel;

  @override
  DateTime get recordedAt => panel.recordedAt;

  @override
  String get displayName => panel.name;
}

/// Groups records that belong to the same clinical panel (sharing panel ID/name,
/// source, and timestamp) while leaving unlinked records standalone.
List<RecordListItem> groupRecordsIntoListItems(List<HealthRecord> records) {
  if (records.isEmpty) return const [];

  final items = <RecordListItem>[];
  final processedRecordIds = <String>{};

  // Group candidates by panel key
  final panelGroups = <String, List<HealthRecord>>{};

  for (final record in records) {
    if (record.category != RecordCategory.lab) continue;
    final panelInfo = extractRecordPanelInfo(record);
    if (panelInfo != null) {
      final key =
          '${record.source}_${record.recordedAt.millisecondsSinceEpoch}_${panelInfo.name}';
      panelGroups.putIfAbsent(key, () => []).add(record);
    }
  }

  for (final record in records) {
    if (processedRecordIds.contains(record.id)) continue;

    final panelInfo = extractRecordPanelInfo(record);
    if (panelInfo != null && record.category == RecordCategory.lab) {
      final key =
          '${record.source}_${record.recordedAt.millisecondsSinceEpoch}_${panelInfo.name}';
      final group = panelGroups[key];

      if (group != null && group.length > 1) {
        for (final member in group) {
          processedRecordIds.add(member.id);
        }
        items.add(
          GroupedPanelListItem(
            ClinicalPanel(
              id: panelInfo.id,
              name: panelInfo.name,
              recordedAt: record.recordedAt,
              source: record.source,
              records: group,
            ),
          ),
        );
        continue;
      }
    }

    processedRecordIds.add(record.id);
    items.add(SingleRecordListItem(record));
  }

  return items;
}
