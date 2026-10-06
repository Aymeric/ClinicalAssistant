import 'package:flutter/material.dart';

import '../../exports/export_selection.dart';
import '../../models/health_record.dart';
import '../shared/record_widgets.dart';

typedef DoctorVisitPdfCallback = void Function(
  List<HealthRecord> records,
  DateTimeRange? range,
  String? questions, {
  bool includeVitals,
  bool includeLabs,
  bool includeMedications,
  bool includeConditions,
  bool includeAllergies,
  bool includeQuestions,
});

class ExportPage extends StatefulWidget {
  const ExportPage({
    super.key,
    required this.records,
    required this.exporting,
    required this.onPdf,
    required this.onFhir,
    required this.onCsv,
    this.onDoctorVisitPdf,
    this.onTextSummary,
    this.onCopyTextSummary,
    this.onVaultBackup,
  });

  final List<HealthRecord> records;
  final bool exporting;
  final ValueChanged<List<HealthRecord>> onPdf;
  final DoctorVisitPdfCallback? onDoctorVisitPdf;
  final ValueChanged<List<HealthRecord>> onFhir;
  final ValueChanged<List<HealthRecord>> onCsv;
  final ValueChanged<List<HealthRecord>>? onTextSummary;
  final ValueChanged<List<HealthRecord>>? onCopyTextSummary;
  final VoidCallback? onVaultBackup;

  @override
  State<ExportPage> createState() => _ExportPageState();
}

enum ExportDatePreset {
  all('All time'),
  days30('30D'),
  days90('90D'),
  year1('1Y'),
  custom('Custom');

  const ExportDatePreset(this.label);
  final String label;
}

class _ExportPageState extends State<ExportPage> {
  final _selectedCategories = RecordCategory.values.toSet();
  ExportDatePreset _datePreset = ExportDatePreset.all;
  DateTimeRange? _customDateRange;

  DateTimeRange? get _effectiveDateRange {
    final now = DateTime.now();
    final today = DateUtils.dateOnly(now);
    switch (_datePreset) {
      case ExportDatePreset.all:
        return null;
      case ExportDatePreset.days30:
        return DateTimeRange(
          start: today.subtract(const Duration(days: 30)),
          end: today,
        );
      case ExportDatePreset.days90:
        return DateTimeRange(
          start: today.subtract(const Duration(days: 90)),
          end: today,
        );
      case ExportDatePreset.year1:
        return DateTimeRange(
          start: today.subtract(const Duration(days: 365)),
          end: today,
        );
      case ExportDatePreset.custom:
        return _customDateRange;
    }
  }

  List<HealthRecord> get _selectedRecords => selectRecordsForExport(
    widget.records,
    _selectedCategories,
    dateRange: _effectiveDateRange,
  );

  Future<void> _promptDoctorVisitPdf(List<HealthRecord> records) async {
    final controller = TextEditingController();
    bool includeVitals = true;
    bool includeLabs = true;
    bool includeMedications = true;
    bool includeConditions = true;
    bool includeAllergies = true;
    bool includeQuestions = true;

    final shouldProceed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Doctor Visit Summary'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Generate a visit-ready PDF highlighting recent vitals, flagged lab results, medications, and questions you want to discuss with your clinician.',
                ),
                const SizedBox(height: 16),
                const Text(
                  'Sections to include:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Vital signs overview'),
                  value: includeVitals,
                  onChanged: (val) =>
                      setDialogState(() => includeVitals = val ?? true),
                ),
                CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Lab results (highlights out-of-range)'),
                  value: includeLabs,
                  onChanged: (val) =>
                      setDialogState(() => includeLabs = val ?? true),
                ),
                CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Medications & adherence'),
                  value: includeMedications,
                  onChanged: (val) =>
                      setDialogState(() => includeMedications = val ?? true),
                ),
                CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Recorded conditions & diagnoses'),
                  value: includeConditions,
                  onChanged: (val) =>
                      setDialogState(() => includeConditions = val ?? true),
                ),
                CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Known allergies & intolerances'),
                  value: includeAllergies,
                  onChanged: (val) =>
                      setDialogState(() => includeAllergies = val ?? true),
                ),
                CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Discussion questions / notes'),
                  value: includeQuestions,
                  onChanged: (val) =>
                      setDialogState(() => includeQuestions = val ?? true),
                ),
                if (includeQuestions) ...[
                  const SizedBox(height: 12),
                  TextField(
                    key: const ValueKey('doctor-visit-questions-input'),
                    controller: controller,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Questions for doctor (optional)',
                      hintText:
                          'e.g. Inquire about blood pressure changes, discuss renewing medications...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const ValueKey('doctor-visit-generate-button'),
              onPressed: () => Navigator.pop(dialogCtx, true),
              child: const Text('Generate PDF'),
            ),
          ],
        ),
      ),
    );
    if (shouldProceed == true && mounted) {
      final questions = controller.text.trim().isEmpty
          ? null
          : controller.text.trim();
      widget.onDoctorVisitPdf?.call(
        records,
        _effectiveDateRange,
        questions,
        includeVitals: includeVitals,
        includeLabs: includeLabs,
        includeMedications: includeMedications,
        includeConditions: includeConditions,
        includeAllergies: includeAllergies,
        includeQuestions: includeQuestions,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedRecords = _selectedRecords;
    final availableCategories = widget.records
        .map((record) => record.category)
        .toSet();
    return PageContent(
      children: [
        Text(
          'Choose which records to include, then create a copy or share it with someone you trust.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 22),
        if (widget.records.isEmpty)
          const QuietEmptyState(
            icon: Icons.ios_share_outlined,
            title: 'Nothing to export yet',
            message:
                'Connect a source and import records first. You can choose the destination when the system share sheet opens.',
          )
        else ...[
          SectionHeading(
            title: 'Include in export',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  key: const ValueKey('export-select-all'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                  ),
                  onPressed:
                      _selectedCategories.containsAll(availableCategories)
                      ? null
                      : () {
                          setState(() {
                            _selectedCategories.addAll(availableCategories);
                          });
                        },
                  child: const Text('Select all'),
                ),
                const SizedBox(width: 4),
                TextButton(
                  key: const ValueKey('export-deselect-all'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                  ),
                  onPressed: _selectedCategories.isEmpty
                      ? null
                      : () {
                          setState(() {
                            _selectedCategories.clear();
                          });
                        },
                  child: const Text('Clear'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final category in RecordCategory.values)
                if (availableCategories.contains(category))
                  FilterChip(
                    label: Text(
                      '${categoryLabel(category)} (${widget.records.where((record) => record.category == category).length})',
                    ),
                    selected: _selectedCategories.contains(category),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedCategories.add(category);
                        } else {
                          _selectedCategories.remove(category);
                        }
                      });
                    },
                  ),
            ],
          ),
          if (_selectedCategories.isNotEmpty) ...[
            const SizedBox(height: 10),
            SectionHeading(
              title: 'Date range',
              trailing: _datePreset != ExportDatePreset.all
                  ? TextButton(
                      key: const ValueKey('export-date-reset'),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                      ),
                      onPressed: () {
                        setState(() {
                          _datePreset = ExportDatePreset.all;
                          _customDateRange = null;
                        });
                      },
                      child: const Text('All dates'),
                    )
                  : null,
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final preset in ExportDatePreset.values)
                  ChoiceChip(
                    visualDensity: VisualDensity.compact,
                    key: ValueKey('export-date-preset-${preset.name}'),
                    label: Text(
                      preset == ExportDatePreset.custom &&
                              _customDateRange != null
                          ? '${formatRecordDate(_customDateRange!.start)} – ${formatRecordDate(_customDateRange!.end)}'
                          : preset.label,
                    ),
                    selected: _datePreset == preset,
                    onSelected: (selected) async {
                      if (!selected) return;
                      if (preset == ExportDatePreset.custom) {
                        final availableDates =
                            widget.records
                                .map(
                                  (r) => DateUtils.dateOnly(
                                    r.recordedAt.toLocal(),
                                  ),
                                )
                                .toSet()
                                .toList()
                              ..sort((a, b) => b.compareTo(a));
                        final first = availableDates.isEmpty
                            ? DateTime(2000)
                            : availableDates.last;
                        final last = availableDates.isEmpty
                            ? DateTime.now().add(const Duration(days: 365))
                            : availableDates.first;
                        final picked = await showDateRangePicker(
                          context: context,
                          firstDate: first.isBefore(DateTime(2000))
                              ? first
                              : DateTime(2000),
                          lastDate: last.isAfter(DateTime(2050))
                              ? last
                              : DateTime(2050),
                          initialDateRange: _customDateRange,
                        );
                        if (picked != null) {
                          setState(() {
                            _customDateRange = picked;
                            _datePreset = ExportDatePreset.custom;
                          });
                        }
                      } else {
                        setState(() {
                          _datePreset = preset;
                        });
                      }
                    },
                  ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Text(
            '${selectedRecords.length} of ${widget.records.length} ${widget.records.length == 1 ? 'record' : 'records'} selected',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          if (selectedRecords.isNotEmpty) ...[
            const SizedBox(height: 8),
            ExportCategoryBreakdownCard(records: selectedRecords),
          ],
          if (selectedRecords.isEmpty) ...[
            const SizedBox(height: 12),
            const QuietEmptyState(
              icon: Icons.filter_alt_off_outlined,
              title: 'Choose a category to continue',
              message: 'Select at least one category to enable an export.',
            ),
          ],
          const SizedBox(height: 18),
          ExportAction(
            icon: Icons.description_outlined,
            title: 'Readable summary',
            detail: 'PDF with dates, values, reference ranges, and sources',
            buttonText: 'Create PDF',
            onPressed: widget.exporting || selectedRecords.isEmpty
                ? null
                : () => widget.onPdf(selectedRecords),
          ),
          if (widget.onDoctorVisitPdf != null) ...[
            const SizedBox(height: 12),
            ExportAction(
              icon: Icons.medical_services_outlined,
              title: 'Doctor visit preparation sheet',
              detail:
                  'Concise visit summary with vital signs, flagged lab results, and your discussion questions',
              buttonText: 'Prepare visit PDF',
              onPressed: widget.exporting || selectedRecords.isEmpty
                  ? null
                  : () => _promptDoctorVisitPdf(selectedRecords),
            ),
          ],
          if (widget.onTextSummary != null ||
              widget.onCopyTextSummary != null) ...[
            const SizedBox(height: 12),
            ExportAction(
              icon: Icons.article_outlined,
              title: 'Clinical text summary',
              detail:
                  'Formatted plain-text document ideal for clinician notes or secure messages',
              buttonText: 'Share TXT',
              onPressed:
                  widget.exporting ||
                      selectedRecords.isEmpty ||
                      widget.onTextSummary == null
                  ? null
                  : () => widget.onTextSummary!(selectedRecords),
              secondaryButtonText: 'Copy text',
              onSecondaryPressed:
                  widget.exporting ||
                      selectedRecords.isEmpty ||
                      widget.onCopyTextSummary == null
                  ? null
                  : () => widget.onCopyTextSummary!(selectedRecords),
            ),
          ],
          const SizedBox(height: 12),
          ExportAction(
            icon: Icons.data_object,
            title: 'FHIR Bundle',
            detail: 'Portable JSON; imported FHIR Observations are preserved',
            buttonText: 'Export FHIR JSON',
            onPressed: widget.exporting || selectedRecords.isEmpty
                ? null
                : () => widget.onFhir(selectedRecords),
          ),
          const SizedBox(height: 12),
          ExportAction(
            icon: Icons.table_chart_outlined,
            title: 'Spreadsheet',
            detail: 'CSV with values, units, dates, and source provenance',
            buttonText: 'Export CSV',
            onPressed: widget.exporting || selectedRecords.isEmpty
                ? null
                : () => widget.onCsv(selectedRecords),
          ),
          if (widget.onVaultBackup != null) ...[
            const SizedBox(height: 12),
            ExportAction(
              icon: Icons.shield_outlined,
              title: 'Encrypted vault backup',
              detail:
                  'Passphrase-protected AES-256 encrypted file containing all your records, notes, and metadata',
              buttonText: 'Export encrypted vault',
              onPressed: widget.exporting || widget.records.isEmpty
                  ? null
                  : widget.onVaultBackup,
            ),
          ],
          const SizedBox(height: 16),
          const PrivacyNote(
            text:
                'Exports are created temporarily on this device. They leave the app only if you choose a destination in the system share sheet.',
          ),
        ],
      ],
    );
  }
}

class ExportCategoryBreakdownCard extends StatelessWidget {
  const ExportCategoryBreakdownCard({super.key, required this.records});

  final List<HealthRecord> records;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final counts = <RecordCategory, int>{};
    for (final record in records) {
      counts[record.category] = (counts[record.category] ?? 0) + 1;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 4,
        children: [
          for (final entry in counts.entries)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  categoryIcon(entry.key),
                  size: 13,
                  color: categoryColor(entry.key, colors),
                ),
                const SizedBox(width: 4),
                Text(
                  '${categoryLabel(entry.key)}: ${entry.value}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class ExportAction extends StatelessWidget {
  const ExportAction({
    super.key,
    required this.icon,
    required this.title,
    required this.detail,
    required this.buttonText,
    required this.onPressed,
    this.secondaryButtonText,
    this.onSecondaryPressed,
  });

  final IconData icon;
  final String title;
  final String detail;
  final String buttonText;
  final VoidCallback? onPressed;
  final String? secondaryButtonText;
  final VoidCallback? onSecondaryPressed;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(detail, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(onPressed: onPressed, child: Text(buttonText)),
                if (secondaryButtonText != null)
                  FilledButton.tonal(
                    onPressed: onSecondaryPressed,
                    child: Text(secondaryButtonText!),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
