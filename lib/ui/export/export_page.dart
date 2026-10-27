import 'package:flutter/material.dart';

import '../../data/synthetic_demonstration_data.dart';
import '../../exports/export_selection.dart';
import '../../exports/fhir_export_validator.dart';
import '../../exports/health_export_service.dart';
import '../../models/health_record.dart';
import '../shared/record_widgets.dart';
import 'fhir_preflight_sheet.dart';

typedef DoctorVisitPdfCallback =
    void Function(
      List<HealthRecord> records,
      DateTimeRange? range,
      String? questions, {
      bool includeVitals,
      bool includeLabs,
      bool includeMedications,
      bool includeConditions,
      bool includeAllergies,
      bool includeQuestions,
      bool includeNotes,
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

  String get tooltip => switch (this) {
    ExportDatePreset.all => 'Include records from all time in export',
    ExportDatePreset.days30 => 'Filter export to last 30 days',
    ExportDatePreset.days90 => 'Filter export to last 90 days',
    ExportDatePreset.year1 => 'Filter export to last 1 year',
    ExportDatePreset.custom => 'Choose custom date range for export',
  };
}

class _ExportPageState extends State<ExportPage> {
  final _searchController = TextEditingController();
  final _selectedCategories = RecordCategory.values.toSet();
  late Set<String> _selectedSources;
  String _searchQuery = '';
  ExportDatePreset _datePreset = ExportDatePreset.all;
  DateTimeRange? _customDateRange;
  bool _includeNotes = true;
  bool _includeSourceData = true;
  late bool _includeSynthetic;

  @override
  void initState() {
    super.initState();
    final hasReal = widget.records.any((r) => !isSyntheticRecord(r));
    final hasSynthetic = widget.records.any(isSyntheticRecord);
    _includeSynthetic = !hasReal && hasSynthetic;
    _selectedSources = widget.records.map((r) => r.source).toSet();
  }

  @override
  void didUpdateWidget(covariant ExportPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.records != oldWidget.records) {
      final oldSources = oldWidget.records.map((r) => r.source).toSet();
      final newSources = widget.records.map((r) => r.source).toSet();
      if (_selectedSources.containsAll(oldSources)) {
        _selectedSources.addAll(newSources);
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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

  List<HealthRecord> get _selectedRecords {
    final filtered = selectRecordsForExport(
      widget.records,
      _selectedCategories,
      dateRange: _effectiveDateRange,
      sources: _selectedSources,
      searchQuery: _searchQuery,
      includeSynthetic: _includeSynthetic,
    );
    return redactRecordsForExport(
      filtered,
      includeNotes: _includeNotes,
      includeSourceData: _includeSourceData,
    );
  }

  Future<void> _showFhirPreflight(List<HealthRecord> selectedRecords) async {
    final exporter = HealthExportService();
    final bundle = exporter.buildFhirBundle(
      selectedRecords,
      includeSourceData: _includeSourceData,
      includeNotes: _includeNotes,
    );

    const validator = FhirExportValidator();
    final report = validator.validateBundle(bundle, records: selectedRecords);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => FhirPreflightSheet(
        report: report,
        onConfirmExport: () => widget.onFhir(selectedRecords),
      ),
    );
  }

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
        includeNotes: _includeNotes,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedRecords = _selectedRecords;
    final hasSyntheticRecords = widget.records.any(isSyntheticRecord);
    final hasRealRecords = widget.records.any((r) => !isSyntheticRecord(r));
    final availableCategories = widget.records
        .where((record) => _includeSynthetic || !isSyntheticRecord(record))
        .map((record) => record.category)
        .toSet();
    final availableSources =
        widget.records
            .where((record) => _includeSynthetic || !isSyntheticRecord(record))
            .map((record) => record.source)
            .toSet()
            .toList()
          ..sort();

    return PageContent(
      children: [
        Text(
          'Choose which records to include, then create a copy or share it with someone you trust.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
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
                      '${categoryLabel(category)} (${widget.records.where((record) => record.category == category && (_includeSynthetic || !isSyntheticRecord(record))).length})',
                    ),
                    tooltip: _selectedCategories.contains(category)
                        ? 'Exclude ${categoryLabel(category)} from export'
                        : 'Include ${categoryLabel(category)} in export',
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
                    tooltip: preset.tooltip,
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
                                .where(
                                  (r) =>
                                      _includeSynthetic ||
                                      !isSyntheticRecord(r),
                                )
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
          const SizedBox(height: 10),
          Text(
            '${selectedRecords.length} of ${widget.records.length} ${widget.records.length == 1 ? 'record' : 'records'} selected',
            key: const ValueKey('export-selected-count-text'),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (selectedRecords.isNotEmpty) ...[
            const SizedBox(height: 8),
            ExportCategoryBreakdownCard(records: selectedRecords),
          ],
          if (selectedRecords.isEmpty) ...[
            const SizedBox(height: 12),
            if (_selectedCategories.intersection(availableCategories).isEmpty)
              const QuietEmptyState(
                icon: Icons.filter_alt_off_outlined,
                title: 'Choose a category to continue',
                message: 'Select at least one category to enable an export.',
              )
            else
              const QuietEmptyState(
                icon: Icons.filter_alt_off_outlined,
                title: 'No matching records',
                message:
                    'No records match your selected sources, categories, date, or search filters. Adjust filters to continue.',
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
                : () => _showFhirPreflight(selectedRecords),
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
          const SizedBox(height: 20),
          const SectionHeading(title: 'Export scope & privacy'),
          const SizedBox(height: 8),
          TextField(
            key: const ValueKey('export-search-input'),
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Filter measurements or codes...',
              prefixIcon: const Icon(Icons.search),
              isDense: true,
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      tooltip: 'Clear search',
                      onPressed: () {
                        setState(() {
                          _searchController.clear();
                          _searchQuery = '';
                        });
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
            ),
            onChanged: (val) => setState(() => _searchQuery = val),
          ),
          if (availableSources.isNotEmpty) ...[
            const SizedBox(height: 14),
            SectionHeading(
              title: 'Sources',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    key: const ValueKey('export-sources-select-all'),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                    ),
                    onPressed: _selectedSources.containsAll(availableSources)
                        ? null
                        : () {
                            setState(() {
                              _selectedSources.addAll(availableSources);
                            });
                          },
                    child: const Text('Select all'),
                  ),
                  const SizedBox(width: 4),
                  TextButton(
                    key: const ValueKey('export-sources-deselect-all'),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                    ),
                    onPressed: _selectedSources.isEmpty
                        ? null
                        : () {
                            setState(() {
                              _selectedSources.clear();
                            });
                          },
                    child: const Text('Clear'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final source in availableSources)
                  FilterChip(
                    key: ValueKey('export-source-$source'),
                    label: Text(
                      '$source (${widget.records.where((record) => record.source == source && (_includeSynthetic || !isSyntheticRecord(record))).length})',
                    ),
                    tooltip: _selectedSources.contains(source)
                        ? 'Exclude $source from export'
                        : 'Include $source in export',
                    selected: _selectedSources.contains(source),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedSources.add(source);
                        } else {
                          _selectedSources.remove(source);
                        }
                      });
                    },
                  ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  key: const ValueKey('export-include-notes-toggle'),
                  secondary: const Icon(Icons.note_alt_outlined),
                  title: const Text('Include personal notes'),
                  subtitle: const Text(
                    'Personal notes and questions attached to records',
                  ),
                  value: _includeNotes,
                  onChanged: (val) => setState(() => _includeNotes = val),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                SwitchListTile(
                  key: const ValueKey('export-include-source-data-toggle'),
                  secondary: const Icon(Icons.data_object_outlined),
                  title: const Text('Include raw source JSON'),
                  subtitle: const Text(
                    'Preserve raw sourceData payloads in CSV and FHIR exports',
                  ),
                  value: _includeSourceData,
                  onChanged: (val) => setState(() => _includeSourceData = val),
                ),
                if (hasSyntheticRecords) ...[
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  SwitchListTile(
                    key: const ValueKey('export-include-synthetic-toggle'),
                    secondary: const Icon(Icons.science_outlined),
                    title: const Text('Include synthetic demo data'),
                    subtitle: Text(
                      hasRealRecords
                          ? 'Excluded by default to safeguard clinical record integrity'
                          : 'Demonstration records loaded for offline testing',
                    ),
                    value: _includeSynthetic,
                    onChanged: (val) => setState(() => _includeSynthetic = val),
                  ),
                ],
              ],
            ),
          ),
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
