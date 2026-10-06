import 'package:flutter/material.dart';

import '../../controllers/health_data_controller.dart';
import '../../models/health_record.dart';
import '../../models/manual_medication_details.dart';
import '../../models/medication_adherence_log.dart';
import '../../records/manual_record_entry_sheet.dart';

class MedicationsPage extends StatefulWidget {
  const MedicationsPage({
    super.key,
    required this.controller,
    this.onRecordTap,
  });

  final HealthDataController controller;
  final ValueChanged<HealthRecord>? onRecordTap;

  @override
  State<MedicationsPage> createState() => _MedicationsPageState();
}

class _MedicationsPageState extends State<MedicationsPage> {
  bool _showPast = false;

  void _openAddMedication() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => ManualRecordEntrySheet(
        onSave: (newRecords) async {
          await widget.controller.addManualRecords(newRecords);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Medication saved to vault')),
            );
          }
        },
      ),
    );
  }

  Future<void> _quickLogDose(HealthRecord med) async {
    await widget.controller.logMedicationDose(med);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Logged dose for ${med.name}'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _logDoseWithDetails(HealthRecord med) async {
    final noteController = TextEditingController();
    DateTime chosenTime = DateTime.now();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Log dose: ${med.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Instructions: ${med.value}',
                style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.access_time),
                title: const Text('Time taken'),
                subtitle: Text(
                  MaterialLocalizations.of(ctx).formatTimeOfDay(
                    TimeOfDay.fromDateTime(chosenTime),
                  ),
                ),
                trailing: TextButton(
                  onPressed: () async {
                    final picked = await showTimePicker(
                      context: ctx,
                      initialTime: TimeOfDay.fromDateTime(chosenTime),
                    );
                    if (picked != null) {
                      setDialogState(() {
                        chosenTime = DateTime(
                          chosenTime.year,
                          chosenTime.month,
                          chosenTime.day,
                          picked.hour,
                          picked.minute,
                        );
                      });
                    }
                  },
                  child: const Text('Change'),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: noteController,
                decoration: const InputDecoration(
                  labelText: 'Note (optional)',
                  hintText: 'e.g. Taken with food, mild nausea...',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogCtx, true),
              child: const Text('Log Dose'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && mounted) {
      await widget.controller.logMedicationDose(
        med,
        takenAt: chosenTime,
        note: noteController.text.trim().isEmpty ? null : noteController.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Logged dose for ${med.name}')),
        );
      }
    }
  }

  void _showAdherenceHistory(HealthRecord med) {
    final details = ManualMedicationDetails.fromRecord(med);
    final logs = [...details.adherenceLogs]
      ..sort((a, b) => b.takenAt.compareTo(a.takenAt));

    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        builder: (sheetCtx, scrollController) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(ctx).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${med.name} Adherence',
                          style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${logs.length} logged dose${logs.length == 1 ? '' : 's'}',
                          style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                            color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(height: 24),
              if (logs.isEmpty)
                const Expanded(
                  child: Center(
                    child: Text('No doses logged yet for this medication.'),
                  ),
                )
              else
                Expanded(
                  child: ListView.separated(
                    controller: scrollController,
                    itemCount: logs.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final log = logs[index];
                      final local = log.takenAt.toLocal();
                      final dateStr = MaterialLocalizations.of(ctx).formatShortDate(local);
                      final timeStr = MaterialLocalizations.of(ctx).formatTimeOfDay(
                        TimeOfDay.fromDateTime(local),
                      );
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(ctx).colorScheme.primaryContainer,
                          foregroundColor: Theme.of(ctx).colorScheme.onPrimaryContainer,
                          child: const Icon(Icons.check, size: 18),
                        ),
                        title: Text('$dateStr at $timeStr'),
                        subtitle: log.notes != null ? Text(log.notes!) : null,
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final active = widget.controller.activeMedications;
        final past = widget.controller.pastMedications;
        final theme = Theme.of(context);
        final colors = theme.colorScheme;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Medications'),
            actions: [
              IconButton(
                key: const ValueKey('add-medication-button'),
                icon: const Icon(Icons.add),
                tooltip: 'Log medication',
                onPressed: _openAddMedication,
              ),
            ],
          ),
          body: active.isEmpty && past.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.medication_outlined,
                          size: 64,
                          color: colors.primary.withValues(alpha: 0.6),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No medications logged yet',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Keep track of your active prescriptions, dosage schedules, and dose adherence logs on-device.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: _openAddMedication,
                          icon: const Icon(Icons.add),
                          label: const Text('Log First Medication'),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Active Prescriptions (${active.length})',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        TextButton.icon(
                          key: const ValueKey('toggle-past-medications'),
                          icon: Icon(
                            _showPast ? Icons.visibility_off : Icons.history,
                            size: 18,
                          ),
                          label: Text(_showPast ? 'Hide past' : 'Past (${past.length})'),
                          onPressed: () => setState(() => _showPast = !_showPast),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (active.isEmpty)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'No active medications currently recorded.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ),
                      )
                    else
                      for (final med in active)
                        _buildMedicationCard(med, isActive: true),
                    if (_showPast && past.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Text(
                        'Past & Discontinued (${past.length})',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      for (final med in past)
                        _buildMedicationCard(med, isActive: false),
                    ],
                  ],
                ),
        );
      },
    );
  }

  Widget _buildMedicationCard(HealthRecord med, {required bool isActive}) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final details = ManualMedicationDetails.fromRecord(med);
    final logCount = details.adherenceLogs.length;

    MedicationAdherenceLog? lastLog;
    if (details.adherenceLogs.isNotEmpty) {
      lastLog = details.adherenceLogs.reduce(
        (a, b) => a.takenAt.isAfter(b.takenAt) ? a : b,
      );
    }

    String? lastTakenLabel;
    if (lastLog != null) {
      final now = DateTime.now();
      final diff = now.difference(lastLog.takenAt);
      if (diff.inHours < 1) {
        lastTakenLabel = 'Taken recently (${diff.inMinutes}m ago)';
      } else if (diff.inHours < 24) {
        lastTakenLabel = 'Taken ${diff.inHours}h ago';
      } else {
        lastTakenLabel = 'Last taken: ${MaterialLocalizations.of(context).formatShortDate(lastLog.takenAt.toLocal())}';
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isActive
                        ? colors.primaryContainer.withValues(alpha: 0.6)
                        : colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.medication_outlined,
                    color: isActive ? colors.primary : colors.onSurfaceVariant,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        med.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        med.value.isNotEmpty ? med.value : 'No dose specified',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (action) async {
                    if (action == 'history') {
                      _showAdherenceHistory(med);
                    } else if (action == 'log_with_note') {
                      await _logDoseWithDetails(med);
                    } else if (action == 'pause') {
                      await widget.controller.updateMedicationStatus(med, 'paused');
                    } else if (action == 'discontinue') {
                      await widget.controller.updateMedicationStatus(med, 'discontinued');
                    } else if (action == 'reactivate') {
                      await widget.controller.updateMedicationStatus(med, 'active');
                    } else if (action == 'delete') {
                      await widget.controller.deleteRecord(med.id);
                    }
                  },
                  itemBuilder: (ctx) => [
                    if (isActive) ...[
                      const PopupMenuItem(
                        value: 'log_with_note',
                        child: Row(
                          children: [
                            Icon(Icons.edit_note, size: 20),
                            SizedBox(width: 8),
                            Text('Log dose with note...'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'pause',
                        child: Row(
                          children: [
                            Icon(Icons.pause, size: 20),
                            SizedBox(width: 8),
                            Text('Pause medication'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'discontinue',
                        child: Row(
                          children: [
                            Icon(Icons.stop_circle_outlined, size: 20),
                            SizedBox(width: 8),
                            Text('Discontinue'),
                          ],
                        ),
                      ),
                    ] else ...[
                      const PopupMenuItem(
                        value: 'reactivate',
                        child: Row(
                          children: [
                            Icon(Icons.play_arrow, size: 20),
                            SizedBox(width: 8),
                            Text('Mark Active'),
                          ],
                        ),
                      ),
                    ],
                    const PopupMenuItem(
                      value: 'history',
                      child: Row(
                        children: [
                          Icon(Icons.history, size: 20),
                          SizedBox(width: 8),
                          Text('Adherence history'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, size: 20, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if (details.frequency.isNotEmpty)
                  _detailPill(Icons.repeat, details.frequency, colors),
                if (details.route != null && details.route!.isNotEmpty)
                  _detailPill(Icons.alt_route, details.route!, colors),
                if (lastTakenLabel != null)
                  _detailPill(Icons.check_circle_outline, lastTakenLabel, colors,
                      color: colors.primary),
                if (logCount > 0)
                  InkWell(
                    onTap: () => _showAdherenceHistory(med),
                    borderRadius: BorderRadius.circular(12),
                    child: _detailPill(
                      Icons.history,
                      '$logCount dose${logCount == 1 ? '' : 's'} logged',
                      colors,
                    ),
                  ),
              ],
            ),
            if (isActive) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      key: ValueKey('log-dose-${med.name}'),
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => _quickLogDose(med),
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('Mark Taken'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.outlined(
                    tooltip: 'History',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.history, size: 18),
                    onPressed: () => _showAdherenceHistory(med),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _detailPill(
    IconData icon,
    String label,
    ColorScheme colors, {
    Color? color,
  }) {
    final pillColor = color ?? colors.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: pillColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: pillColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
