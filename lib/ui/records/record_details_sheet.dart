import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/synthetic_demonstration_data.dart';
import '../../models/health_record.dart';
import '../../models/manual_medication_details.dart';
import '../../trends/health_trend.dart';
import '../shared/record_widgets.dart';

class RecordDetailsSheet extends StatefulWidget {
  const RecordDetailsSheet({
    super.key,
    required this.record,
    required this.isNumeric,
    this.isPinned = false,
    this.onTogglePin,
    this.onSaveNotes,
    this.onDelete,
    this.onEdit,
    this.onViewInTrends,
  });

  final HealthRecord record;
  final bool isNumeric;
  final bool isPinned;
  final VoidCallback? onTogglePin;
  final ValueChanged<String?>? onSaveNotes;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;
  final VoidCallback? onViewInTrends;

  @override
  State<RecordDetailsSheet> createState() => _RecordDetailsSheetState();
}

class _RecordDetailsSheetState extends State<RecordDetailsSheet> {
  bool _showRawData = false;
  late TextEditingController _notesController;
  bool _isEditingNote = false;
  String? _currentNotes;

  @override
  void initState() {
    super.initState();
    _currentNotes = widget.record.notes;
    _notesController = TextEditingController(text: _currentNotes ?? '');
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  void _copyValue(BuildContext context) {
    Clipboard.setData(ClipboardData(text: widget.record.displayValue));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Value copied to clipboard'),
          duration: Duration(seconds: 2),
        ),
      );
  }

  void _copyAllDetails(BuildContext context) {
    final r = widget.record;
    final lines = [
      'Measurement: ${r.name}',
      'Value: ${r.displayValue}',
      'Recorded: ${r.recordedAt.toLocal().toString().split('.').first}',
      'Source: ${r.source}',
      'Category: ${categoryLabel(r.category)}',
      if (r.referenceRange != null) 'Reference range: ${r.referenceRange}',
      if (r.status != null) 'Status: ${r.status}',
      if (r.code != null) 'Code: ${r.code}',
      if (r.sourceId != null) 'Source ID: ${r.sourceId}',
      if (_currentNotes != null) 'Personal note: $_currentNotes',
    ];
    Clipboard.setData(ClipboardData(text: lines.join('\n')));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Details copied to clipboard'),
          duration: Duration(seconds: 2),
        ),
      );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Delete measurement?'),
        content: Text(
          'Are you sure you want to delete this ${widget.record.name} record? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      widget.onDelete?.call();
    }
  }

  Future<void> _saveNote() async {
    final trimmed = _notesController.text.trim();
    final value = trimmed.isEmpty ? null : trimmed;
    setState(() {
      _currentNotes = value;
      _isEditingNote = false;
    });
    widget.onSaveNotes?.call(value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final record = widget.record;
    final catColor = categoryColor(record.category, colors);
    final medicationDetails =
        record.isManual && record.category == RecordCategory.medication
        ? ManualMedicationDetails.fromRecord(record)
        : null;

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => SingleChildScrollView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: catColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        categoryIcon(record.category),
                        size: 14,
                        color: catColor,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        categoryLabel(record.category),
                        style: TextStyle(
                          color: catColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                if (widget.onTogglePin != null)
                  IconButton(
                    tooltip: widget.isPinned
                        ? 'Unpin from Overview'
                        : 'Pin to Overview',
                    icon: Icon(
                      widget.isPinned
                          ? Icons.push_pin
                          : Icons.push_pin_outlined,
                      size: 20,
                      color: widget.isPinned ? colors.primary : null,
                    ),
                    onPressed: widget.onTogglePin,
                  ),
                if (widget.onEdit != null)
                  IconButton(
                    tooltip: 'Edit manual record',
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    onPressed: widget.onEdit,
                  ),
                if (widget.onDelete != null)
                  IconButton(
                    tooltip: 'Delete manual record',
                    icon: Icon(
                      Icons.delete_outline,
                      size: 20,
                      color: colors.error,
                    ),
                    onPressed: () => _confirmDelete(context),
                  ),
                IconButton(
                  tooltip: 'Copy all details',
                  icon: const Icon(Icons.copy_all, size: 20),
                  onPressed: () => _copyAllDetails(context),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              record.name,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if (record.isManual) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: colors.primaryContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.edit_note,
                      size: 14,
                      color: colors.onPrimaryContainer,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Manual entry',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: colors.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (isSyntheticRecord(record)) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.amber.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.science_outlined,
                      size: 14,
                      color: Colors.amber.shade800,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Demonstration record (Synthetic)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.amber.shade900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      record.displayValue,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colors.primary,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Copy value',
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    onPressed: () => _copyValue(context),
                  ),
                ],
              ),
            ),
            Builder(
              builder: (context) {
                if (record.referenceRange == null) {
                  return const SizedBox.shrink();
                }
                final numeric = parseHealthRecordValue(record.value);
                if (numeric == null) return const SizedBox.shrink();
                final range = HealthReferenceRange.tryParse(
                  record.referenceRange!,
                );
                if (range == null) return const SizedBox.shrink();
                final status = range.evaluate(numeric);
                if (status == HealthReferenceStatus.unspecified) {
                  return const SizedBox.shrink();
                }
                final (
                  Color badgeColor,
                  String statusText,
                  IconData statusIcon,
                ) = switch (status) {
                  HealthReferenceStatus.within => (
                    Colors.teal,
                    'Within range (${record.referenceRange})',
                    Icons.check_circle_outline,
                  ),
                  HealthReferenceStatus.above => (
                    Colors.deepOrange,
                    'Above range (${record.referenceRange})',
                    Icons.arrow_upward,
                  ),
                  HealthReferenceStatus.below => (
                    Colors.blueGrey,
                    'Below range (${record.referenceRange})',
                    Icons.arrow_downward,
                  ),
                  HealthReferenceStatus.unspecified => (
                    Colors.grey,
                    '',
                    Icons.help_outline,
                  ),
                };
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: badgeColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      runSpacing: 2,
                      children: [
                        Icon(statusIcon, size: 14, color: badgeColor),
                        Text(
                          statusText,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: badgeColor,
                          ),
                        ),
                        Text(
                          '· Source-reported',
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            if (widget.onViewInTrends != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: FilledButton.tonalIcon(
                  onPressed: widget.onViewInTrends,
                  icon: const Icon(Icons.show_chart, size: 18),
                  label: const Text('View in Trends'),
                ),
              ),
            const Divider(),
            const SizedBox(height: 8),
            DetailLine(label: 'Value', value: record.displayValue),
            DetailLine(
              label: record.category == RecordCategory.medication
                  ? 'Started'
                  : 'Recorded',
              value: record.recordedAt.toLocal().toString().split('.').first,
            ),
            DetailLine(label: 'Source', value: record.source),
            DetailLine(
              label: 'Category',
              value: categoryLabel(record.category),
            ),
            if (record.referenceRange != null)
              DetailLine(
                label: 'Reference range',
                value: record.referenceRange!,
              ),
            if (record.status != null)
              DetailLine(
                label:
                    record.isManual &&
                        record.category == RecordCategory.medication
                    ? 'Medication status'
                    : 'Source status',
                value: record.status!.replaceAll('-', ' '),
              ),
            if (medicationDetails?.frequency.isNotEmpty == true)
              DetailLine(
                label: 'Frequency',
                value: medicationDetails!.frequency,
              ),
            if (medicationDetails?.route != null)
              DetailLine(label: 'Route', value: medicationDetails!.route!),
            if (medicationDetails?.endDate != null)
              DetailLine(
                label: 'Ended',
                value: medicationDetails!.endDate!
                    .toLocal()
                    .toString()
                    .split('.')
                    .first,
              ),
            if (record.code != null)
              DetailLine(label: 'Code', value: record.code!),
            if (record.sourceId != null)
              DetailLine(label: 'Source ID', value: record.sourceId!),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            // Personal Notes Section
            Row(
              children: [
                Icon(Icons.note_alt_outlined, size: 18, color: colors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Personal note',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (!_isEditingNote)
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    icon: Icon(
                      _currentNotes == null || _currentNotes!.isEmpty
                          ? Icons.add
                          : Icons.edit_outlined,
                      size: 16,
                    ),
                    label: Text(
                      _currentNotes == null || _currentNotes!.isEmpty
                          ? 'Add note'
                          : 'Edit',
                    ),
                    onPressed: () {
                      setState(() {
                        _notesController.text = _currentNotes ?? '';
                        _isEditingNote = true;
                      });
                    },
                  ),
              ],
            ),
            const SizedBox(height: 6),
            if (_isEditingNote) ...[
              TextField(
                key: const ValueKey('record-notes-input'),
                controller: _notesController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Add context, symptoms, or what you were doing...',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.all(12),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _isEditingNote = false;
                        _notesController.text = _currentNotes ?? '';
                      });
                    },
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    key: const ValueKey('record-save-notes-button'),
                    onPressed: _saveNote,
                    child: const Text('Save Note'),
                  ),
                ],
              ),
            ] else if (_currentNotes != null && _currentNotes!.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: colors.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                child: Text(_currentNotes!, style: theme.textTheme.bodyMedium),
              ),
            ] else ...[
              Text(
                'No personal note added. Keep private contextual notes about this record.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            if (record.sourceData != null && record.sourceData!.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => setState(() => _showRawData = !_showRawData),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Icon(
                              _showRawData
                                  ? Icons.expand_less
                                  : Icons.expand_more,
                              color: colors.primary,
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Raw Source / FHIR Data',
                                style: TextStyle(fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  TextButton.icon(
                    key: const ValueKey('record-copy-json-button'),
                    onPressed: () {
                      final jsonStr = const JsonEncoder.withIndent(
                        '  ',
                      ).convert(record.sourceData);
                      Clipboard.setData(ClipboardData(text: jsonStr));
                      ScaffoldMessenger.of(context)
                        ..hideCurrentSnackBar()
                        ..showSnackBar(
                          const SnackBar(
                            content: Text('Raw JSON copied to clipboard'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                    },
                    icon: const Icon(Icons.copy, size: 14),
                    label: const Text('Copy JSON'),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
              if (_showRawData)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: colors.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  child: SelectableText(
                    const JsonEncoder.withIndent(
                      '  ',
                    ).convert(record.sourceData),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
