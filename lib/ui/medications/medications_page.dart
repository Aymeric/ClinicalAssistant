import 'package:flutter/material.dart';

import '../../controllers/health_data_controller.dart';
import '../../models/health_record.dart';
import '../../models/manual_medication_details.dart';
import '../../models/medication_adherence_log.dart';
import '../../models/medication_reminder.dart';
import '../../notifications/medication_reminder_service.dart';
import '../../records/manual_record_entry_sheet.dart';
import '../../safety/drug_interaction_database.dart';

class MedicationsPage extends StatefulWidget {
  const MedicationsPage({
    super.key,
    required this.controller,
    this.reminderService,
    this.onRecordTap,
  });

  final HealthDataController controller;
  final MedicationReminderService? reminderService;
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

  Future<void> _confirmDeleteMedication(HealthRecord med) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text('Delete ${med.name}?'),
        content: Text(
          'Are you sure you want to delete this medication and its adherence history? This action cannot be undone.',
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
      await widget.reminderService?.removeReminder(med.id);
      await widget.controller.deleteRecord(med.id);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Deleted ${med.name}')));
      }
    }
  }

  Future<void> _quickLogDose(
    HealthRecord med, {
    MedicationAdherenceStatus status = MedicationAdherenceStatus.taken,
  }) async {
    await widget.controller.logMedicationDose(med, status: status);
    if (mounted) {
      final actionWord = status == MedicationAdherenceStatus.skipped
          ? 'Logged skipped dose'
          : 'Logged dose';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$actionWord for ${med.name}'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _logDoseWithDetails(
    HealthRecord med, {
    MedicationAdherenceStatus initialStatus = MedicationAdherenceStatus.taken,
  }) async {
    final noteController = TextEditingController();
    DateTime chosenTime = DateTime.now();
    var chosenStatus = initialStatus;

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
              const SizedBox(height: 12),
              SegmentedButton<MedicationAdherenceStatus>(
                segments: const [
                  ButtonSegment(
                    value: MedicationAdherenceStatus.taken,
                    icon: Icon(Icons.check, size: 16),
                    label: Text('Taken'),
                  ),
                  ButtonSegment(
                    value: MedicationAdherenceStatus.skipped,
                    icon: Icon(Icons.close, size: 16),
                    label: Text('Skipped'),
                  ),
                ],
                selected: {chosenStatus},
                onSelectionChanged: (newSet) {
                  if (newSet.isNotEmpty) {
                    setDialogState(() => chosenStatus = newSet.first);
                  }
                },
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.access_time),
                title: Text(
                  chosenStatus == MedicationAdherenceStatus.skipped
                      ? 'Time skipped'
                      : 'Time taken',
                ),
                subtitle: Text(
                  MaterialLocalizations.of(
                    ctx,
                  ).formatTimeOfDay(TimeOfDay.fromDateTime(chosenTime)),
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
                decoration: InputDecoration(
                  labelText: 'Note (optional)',
                  hintText: chosenStatus == MedicationAdherenceStatus.skipped
                      ? 'e.g. Fasting for lab work, mild nausea...'
                      : 'e.g. Taken with food, mild nausea...',
                  border: const OutlineInputBorder(),
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
              child: Text(
                chosenStatus == MedicationAdherenceStatus.skipped
                    ? 'Log Skipped'
                    : 'Log Dose',
              ),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && mounted) {
      await widget.controller.logMedicationDose(
        med,
        takenAt: chosenTime,
        status: chosenStatus,
        note: noteController.text.trim().isEmpty
            ? null
            : noteController.text.trim(),
      );
      if (mounted) {
        final msg = chosenStatus == MedicationAdherenceStatus.skipped
            ? 'Logged skipped dose for ${med.name}'
            : 'Logged dose for ${med.name}';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));
      }
    }
  }

  Future<void> _showDiscontinueDialog(HealthRecord med) async {
    DateTime chosenDate = DateTime.now();
    String selectedReason = 'Completed prescribed course';
    final customReasonController = TextEditingController();
    bool isCustom = false;

    const commonReasons = [
      'Completed prescribed course',
      'Adverse reaction / side effect',
      'Changed or replaced by prescriber',
      'Ineffective / no longer needed',
      'Other reason',
    ];

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Discontinue ${med.name}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Record the effective date and clinical reason for stopping this medication:',
                  style: Theme.of(ctx).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today_outlined),
                  title: const Text('Effective Stop Date'),
                  subtitle: Text(
                    MaterialLocalizations.of(ctx).formatMediumDate(chosenDate),
                  ),
                  trailing: TextButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: chosenDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setDialogState(() => chosenDate = picked);
                      }
                    },
                    child: const Text('Change'),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Reason for Discontinuing',
                  style: Theme.of(
                    ctx,
                  ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: selectedReason,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  items: commonReasons.map((reason) {
                    return DropdownMenuItem<String>(
                      value: reason,
                      child: Text(reason, overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() {
                        selectedReason = val;
                        isCustom = val == 'Other reason';
                      });
                    }
                  },
                ),
                if (isCustom) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: customReasonController,
                    decoration: const InputDecoration(
                      labelText: 'Specify reason',
                      hintText: 'e.g. Switched to alternative therapy',
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
              onPressed: () => Navigator.pop(dialogCtx, true),
              child: const Text('Discontinue'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && mounted) {
      final effectiveReason =
          isCustom && customReasonController.text.trim().isNotEmpty
          ? customReasonController.text.trim()
          : selectedReason;

      await widget.reminderService?.cancelReminder(med.id);
      await widget.controller.updateMedicationStatus(
        med,
        'discontinued',
        endDate: chosenDate,
        discontinueReason: effectiveReason,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${med.name} marked discontinued ($effectiveReason)'),
          ),
        );
      }
    }
  }

  Future<void> _showReminderConfigDialog(HealthRecord med) async {
    final details = ManualMedicationDetails.fromRecord(med);
    final initialReminder =
        details.reminder ??
        MedicationReminder(
          medicationId: med.id,
          medicationName: med.name,
          schedule: MedicationReminderSchedule.fromString(details.frequency),
          times: MedicationReminderSchedule.fromString(
            details.frequency,
          ).defaultTimes,
          isEnabled: true,
        );

    var isEnabled = initialReminder.isEnabled;
    var selectedSchedule = initialReminder.schedule;
    var customTimes = List<TimeOfDay>.from(initialReminder.effectiveTimes);

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final theme = Theme.of(ctx);
          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.alarm, size: 24),
                const SizedBox(width: 8),
                Expanded(child: Text('Reminder: ${med.name}')),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Enable reminders'),
                    subtitle: Text(
                      isEnabled
                          ? 'Receive local notifications on schedule'
                          : 'Reminders disabled for this medication',
                    ),
                    value: isEnabled,
                    onChanged: (val) {
                      setDialogState(() => isEnabled = val);
                    },
                  ),
                  const Divider(height: 20),
                  Text(
                    'Frequency schedule',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<MedicationReminderSchedule>(
                    initialValue: selectedSchedule,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    items: MedicationReminderSchedule.values.map((s) {
                      return DropdownMenuItem(value: s, child: Text(s.label));
                    }).toList(),
                    onChanged: !isEnabled
                        ? null
                        : (newSchedule) {
                            if (newSchedule != null) {
                              setDialogState(() {
                                selectedSchedule = newSchedule;
                                customTimes = List.of(newSchedule.defaultTimes);
                              });
                            }
                          },
                  ),
                  if (isEnabled &&
                      selectedSchedule != MedicationReminderSchedule.prn) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Reminder times',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    ...customTimes.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final t = entry.value;
                      final formatted = MaterialLocalizations.of(
                        ctx,
                      ).formatTimeOfDay(t);
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.access_time, size: 20),
                        title: Text('Dose ${idx + 1}: $formatted'),
                        trailing: TextButton(
                          onPressed: () async {
                            final picked = await showTimePicker(
                              context: ctx,
                              initialTime: t,
                            );
                            if (picked != null) {
                              setDialogState(() {
                                customTimes[idx] = picked;
                              });
                            }
                          },
                          child: const Text('Change'),
                        ),
                      );
                    }),
                  ] else if (isEnabled &&
                      selectedSchedule == MedicationReminderSchedule.prn) ...[
                    const SizedBox(height: 12),
                    Text(
                      'PRN (As needed) medications do not trigger recurring fixed-time alerts. Log doses manually as taken.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
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
                onPressed: () => Navigator.pop(dialogCtx, true),
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );

    if (saved == true && mounted) {
      final updatedReminder = MedicationReminder(
        medicationId: med.id,
        medicationName: med.name,
        schedule: selectedSchedule,
        times: customTimes,
        isEnabled: isEnabled,
      );

      final updatedDetails = ManualMedicationDetails(
        frequency: details.frequency,
        route: details.route,
        endDate: details.endDate,
        discontinueReason: details.discontinueReason,
        adherenceLogs: details.adherenceLogs,
        reminder: updatedReminder,
      );

      final updatedRecord = med.copyWith(
        sourceData: updatedDetails.withSourceData(med.sourceData),
      );

      await widget.controller.updateManualRecords([updatedRecord]);
      if (widget.reminderService != null) {
        await widget.reminderService!.setReminder(updatedReminder);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isEnabled
                  ? 'Reminder scheduled for ${med.name} (${selectedSchedule.label})'
                  : 'Reminder disabled for ${med.name}',
            ),
          ),
        );
      }
    }
  }

  void _showAdherenceHistory(HealthRecord med) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (ctx) => _MedicationAdherenceSheet(med: med),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final active = widget.controller.activeMedications;
        final past = widget.controller.pastMedications;
        final detectedInteractions =
            DrugInteractionDatabase.evaluateInteractions(active);
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
                    if (detectedInteractions.isNotEmpty) ...[
                      _buildInteractionsSection(detectedInteractions),
                      const SizedBox(height: 16),
                    ],
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
                          label: Text(
                            _showPast ? 'Hide past' : 'Past (${past.length})',
                          ),
                          onPressed: () =>
                              setState(() => _showPast = !_showPast),
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

  Widget _buildInteractionsSection(List<DetectedDrugInteraction> interactions) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final hasHigh = interactions.any(
      (i) => i.interaction.severity == DrugInteractionSeverity.high,
    );
    final headerColor = hasHigh ? colors.error : colors.tertiary;

    return Container(
      key: const ValueKey('medication-interactions-section'),
      decoration: BoxDecoration(
        color: hasHigh
            ? colors.errorContainer.withValues(alpha: 0.25)
            : colors.tertiaryContainer.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (hasHigh ? colors.error : colors.tertiary).withValues(
            alpha: 0.4,
          ),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasHigh
                    ? Icons.warning_amber_rounded
                    : Icons.info_outline_rounded,
                color: headerColor,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Medication & Dietary Precautions (${interactions.length})',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Offline interaction check based on open pharmacology references (FDA / RxNorm). Discuss any flagged warnings with your pharmacist or prescriber.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 12),
          for (final item in interactions) ...[
            _buildInteractionTile(item),
            if (item != interactions.last) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  Widget _buildInteractionTile(DetectedDrugInteraction item) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isHigh = item.interaction.severity == DrugInteractionSeverity.high;
    final isFood = item.isFoodDrug;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (isHigh ? colors.error : colors.outlineVariant).withValues(
            alpha: isHigh ? 0.5 : 0.8,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isHigh
                      ? colors.error.withValues(alpha: 0.12)
                      : colors.tertiary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isFood
                          ? Icons.restaurant_menu
                          : Icons.medication_outlined,
                      size: 13,
                      color: isHigh ? colors.error : colors.tertiary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${item.interaction.type.label} · ${item.interaction.severity.label}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isHigh ? colors.error : colors.tertiary,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (item.medicationB != null)
                Text(
                  '${item.medicationA.name} + ${item.medicationB!.name}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colors.onSurfaceVariant,
                  ),
                )
              else
                Text(
                  item.medicationA.name,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colors.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            item.interaction.title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            item.interaction.description,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.health_and_safety_outlined,
                  size: 16,
                  color: colors.primary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    item.interaction.recommendation,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurface,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicationCard(HealthRecord med, {required bool isActive}) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final details = ManualMedicationDetails.fromRecord(med);
    final logCount = details.adherenceLogs.length;
    final pdc30 = MedicationPdcEvaluation.evaluate(med, windowDays: 30);

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
      final verb = lastLog.isSkipped ? 'Skipped' : 'Taken';
      if (diff.inHours < 1) {
        lastTakenLabel = '$verb recently (${diff.inMinutes}m ago)';
      } else if (diff.inHours < 24) {
        lastTakenLabel = '$verb ${diff.inHours}h ago';
      } else {
        lastTakenLabel =
            'Last ${verb.toLowerCase()}: ${MaterialLocalizations.of(context).formatShortDate(lastLog.takenAt.toLocal())}';
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
                        key: ValueKey('medication-title-${med.name}'),
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
                  tooltip: 'Medication options',
                  onSelected: (action) async {
                    if (action == 'history') {
                      _showAdherenceHistory(med);
                    } else if (action == 'reminder') {
                      await _showReminderConfigDialog(med);
                    } else if (action == 'log_with_note') {
                      await _logDoseWithDetails(med);
                    } else if (action == 'pause') {
                      await widget.reminderService?.cancelReminder(med.id);
                      await widget.controller.updateMedicationStatus(
                        med,
                        'paused',
                      );
                    } else if (action == 'discontinue') {
                      await _showDiscontinueDialog(med);
                    } else if (action == 'reactivate') {
                      await widget.controller.updateMedicationStatus(
                        med,
                        'active',
                      );
                      final rem = ManualMedicationDetails.fromRecord(
                        med,
                      ).reminder;
                      if (rem != null && rem.isEnabled) {
                        await widget.reminderService?.scheduleReminder(rem);
                      }
                    } else if (action == 'delete') {
                      await _confirmDeleteMedication(med);
                    }
                  },
                  itemBuilder: (ctx) => [
                    if (isActive) ...[
                      const PopupMenuItem(
                        value: 'reminder',
                        child: Row(
                          children: [
                            Icon(Icons.alarm, size: 20),
                            SizedBox(width: 8),
                            Expanded(child: Text('Reminder schedule...')),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'log_with_note',
                        child: Row(
                          children: [
                            Icon(Icons.edit_note, size: 20),
                            SizedBox(width: 8),
                            Expanded(child: Text('Log dose with note...')),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'pause',
                        child: Row(
                          children: [
                            Icon(Icons.pause, size: 20),
                            SizedBox(width: 8),
                            Expanded(child: Text('Pause medication')),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'discontinue',
                        child: Row(
                          children: [
                            Icon(Icons.stop_circle_outlined, size: 20),
                            SizedBox(width: 8),
                            Expanded(child: Text('Discontinue')),
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
                            Expanded(child: Text('Mark Active')),
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
                          Expanded(child: Text('Adherence history')),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete_outline,
                            size: 20,
                            color: Colors.red,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Delete',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
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
                if (details.reminder != null && details.reminder!.isEnabled)
                  Tooltip(
                    message:
                        'Reminder scheduled: ${details.reminder!.schedule.label}',
                    child: InkWell(
                      onTap: isActive
                          ? () => _showReminderConfigDialog(med)
                          : null,
                      borderRadius: BorderRadius.circular(8),
                      child: _detailPill(
                        Icons.alarm_on,
                        details.reminder!.schedule.label,
                        colors,
                        color: colors.primary,
                      ),
                    ),
                  )
                else if (isActive)
                  Tooltip(
                    message: 'Set recurring reminder',
                    child: InkWell(
                      onTap: () => _showReminderConfigDialog(med),
                      borderRadius: BorderRadius.circular(8),
                      child: _detailPill(
                        Icons.alarm_add_outlined,
                        'Set reminder',
                        colors,
                      ),
                    ),
                  ),
                if (details.route != null && details.route!.isNotEmpty)
                  _detailPill(Icons.alt_route, details.route!, colors),
                if (lastTakenLabel != null)
                  _detailPill(
                    lastLog != null && lastLog.isSkipped
                        ? Icons.cancel_outlined
                        : Icons.check_circle_outline,
                    lastTakenLabel,
                    colors,
                    color: lastLog != null && lastLog.isSkipped
                        ? colors.tertiary
                        : colors.primary,
                  ),
                if (!pdc30.isPrn && logCount > 0 && pdc30.eligibleDays > 0)
                  Tooltip(
                    message:
                        '30-day Proportion of Days Covered (PDC): ${pdc30.descriptiveLabel}',
                    child: Semantics(
                      button: true,
                      label:
                          '30-day Proportion of Days Covered: ${pdc30.pdcPercentRounded}%, ${pdc30.descriptiveLabel}. Tap to view adherence history',
                      excludeSemantics: true,
                      child: InkWell(
                        key: ValueKey('pdc-chip-${med.name}'),
                        onTap: () => _showAdherenceHistory(med),
                        borderRadius: BorderRadius.circular(8),
                        child: _detailPill(
                          pdc30.meetsClinicalBenchmark
                              ? Icons.verified_outlined
                              : Icons.pie_chart_outline,
                          '30d PDC: ${pdc30.pdcPercentRounded}%',
                          colors,
                          color: pdc30.meetsClinicalBenchmark
                              ? colors.primary
                              : colors.tertiary,
                        ),
                      ),
                    ),
                  ),
                if (logCount > 0)
                  Tooltip(
                    message: 'View adherence history',
                    child: Semantics(
                      button: true,
                      label:
                          'View adherence history, $logCount dose${logCount == 1 ? '' : 's'} logged',
                      child: InkWell(
                        onTap: () => _showAdherenceHistory(med),
                        borderRadius: BorderRadius.circular(12),
                        child: _detailPill(
                          Icons.history,
                          '$logCount dose${logCount == 1 ? '' : 's'} logged',
                          colors,
                        ),
                      ),
                    ),
                  ),
                if (!isActive && details.endDate != null)
                  _detailPill(
                    Icons.event_busy,
                    'Stopped: ${MaterialLocalizations.of(context).formatShortDate(details.endDate!.toLocal())}',
                    colors,
                    color: colors.error,
                  ),
                if (!isActive && details.discontinueReason != null)
                  _detailPill(
                    Icons.info_outline,
                    details.discontinueReason!,
                    colors,
                  ),
              ],
            ),
            if (isActive) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Tooltip(
                      message: 'Log a dose immediately',
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
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Tooltip(
                      message: 'Record a skipped dose',
                      child: OutlinedButton.icon(
                        key: ValueKey('skip-dose-${med.name}'),
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => _quickLogDose(
                          med,
                          status: MedicationAdherenceStatus.skipped,
                        ),
                        icon: const Icon(Icons.close, size: 16),
                        label: const Text('Mark Skipped'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.outlined(
                    tooltip: 'History & Calendar',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.calendar_month_outlined, size: 18),
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

class _MedicationAdherenceSheet extends StatefulWidget {
  const _MedicationAdherenceSheet({required this.med});

  final HealthRecord med;

  @override
  State<_MedicationAdherenceSheet> createState() =>
      _MedicationAdherenceSheetState();
}

class _MedicationAdherenceSheetState extends State<_MedicationAdherenceSheet> {
  int _selectedWindowDays = 30;
  late DateTime _displayedMonth;

  @override
  void initState() {
    super.initState();
    final details = ManualMedicationDetails.fromRecord(widget.med);
    if (details.adherenceLogs.isNotEmpty) {
      final latestLog = details.adherenceLogs.reduce(
        (a, b) => a.takenAt.isAfter(b.takenAt) ? a : b,
      );
      final local = latestLog.takenAt.toLocal();
      _displayedMonth = DateTime(local.year, local.month, 1);
    } else {
      final now = DateTime.now();
      _displayedMonth = DateTime(now.year, now.month, 1);
    }
  }

  void _changeMonth(int delta) {
    setState(() {
      _displayedMonth = DateTime(
        _displayedMonth.year,
        _displayedMonth.month + delta,
        1,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final details = ManualMedicationDetails.fromRecord(widget.med);
    final logs = [...details.adherenceLogs]
      ..sort((a, b) => b.takenAt.compareTo(a.takenAt));

    final pdc = MedicationPdcEvaluation.evaluate(
      widget.med,
      windowDays: _selectedWindowDays,
    );
    final monthDays = MedicationPdcEvaluation.buildMonthCalendar(
      widget.med,
      year: _displayedMonth.year,
      month: _displayedMonth.month,
    );
    final firstWeekdayOffset = _displayedMonth.weekday % 7; // Sunday = 0

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.82,
      maxChildSize: 0.94,
      minChildSize: 0.5,
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
                  color: colors.outlineVariant,
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
                        '${widget.med.name} Adherence',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${logs.length} logged dose${logs.length == 1 ? '' : 's'} · ${details.frequency.isNotEmpty ? details.frequency : "Standard schedule"}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Close',
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(height: 20),
            Expanded(
              child: ListView(
                controller: scrollController,
                children: [
                  _buildPdcSummaryCard(pdc, theme, colors),
                  const SizedBox(height: 16),
                  _buildMonthlyCalendarCard(
                    monthDays,
                    firstWeekdayOffset,
                    theme,
                    colors,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Dose Log History (${logs.length})',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (logs.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          'No doses logged yet for this medication.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    )
                  else
                    for (var i = 0; i < logs.length; i++) ...[
                      _buildLogTile(logs[i], context, colors, theme),
                      if (i < logs.length - 1) const Divider(height: 1),
                    ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPdcSummaryCard(
    MedicationPdcEvaluation pdc,
    ThemeData theme,
    ColorScheme colors,
  ) {
    final isBenchmarkMet = pdc.meetsClinicalBenchmark;
    final badgeColor = pdc.isPrn
        ? colors.secondary
        : (isBenchmarkMet ? colors.primary : colors.tertiary);

    return Container(
      key: const ValueKey('medication-pdc-summary-card'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Proportion of Days Covered (PDC)',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SegmentedButton<int>(
                key: const ValueKey('pdc-window-selector'),
                style: SegmentedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
                segments: const [
                  ButtonSegment(value: 30, label: Text('30d')),
                  ButtonSegment(value: 60, label: Text('60d')),
                  ButtonSegment(value: 90, label: Text('90d')),
                ],
                selected: {_selectedWindowDays},
                onSelectionChanged: (selection) {
                  if (selection.isNotEmpty) {
                    setState(() => _selectedWindowDays = selection.first);
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (pdc.isPrn)
            Text(
              'PRN (As needed) regimen · ${pdc.takenDoses} dose${pdc.takenDoses == 1 ? '' : 's'} taken in the last $_selectedWindowDays days.',
              style: theme.textTheme.bodyMedium,
            )
          else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '${pdc.pdcPercentRounded}%',
                  key: const ValueKey('pdc-percentage-value'),
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: badgeColor,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${pdc.coveredDays} of ${pdc.eligibleDays} eligible days covered (${pdc.expectedDosesPerDay}x/day)',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pdc.pdcRatio,
                minHeight: 6,
                backgroundColor: colors.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(badgeColor),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  isBenchmarkMet
                      ? Icons.verified_outlined
                      : Icons.info_outline_rounded,
                  size: 15,
                  color: badgeColor,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    isBenchmarkMet
                        ? 'Meets standard clinical adherence benchmark (≥80% PDC).'
                        : 'Below 80% PDC clinical adherence benchmark (${pdc.takenDoses} taken, ${pdc.skippedDoses} skipped).',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 6),
          Text(
            'Calculated locally on-device for descriptive consultation review. Does not constitute medical advice.',
            style: theme.textTheme.labelSmall?.copyWith(
              color: colors.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyCalendarCard(
    List<MedicationAdherenceDaySummary> monthDays,
    int firstWeekdayOffset,
    ThemeData theme,
    ColorScheme colors,
  ) {
    final monthLabel = MaterialLocalizations.of(
      context,
    ).formatMonthYear(_displayedMonth);
    const weekdayLabels = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

    return Container(
      key: const ValueKey('medication-adherence-calendar'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Monthly Adherence Calendar',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    key: const ValueKey('calendar-prev-month'),
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.chevron_left, size: 20),
                    tooltip: 'Previous month',
                    onPressed: () => _changeMonth(-1),
                  ),
                  Text(
                    monthLabel,
                    key: const ValueKey('calendar-month-label'),
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('calendar-next-month'),
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.chevron_right, size: 20),
                    tooltip: 'Next month',
                    onPressed: () => _changeMonth(1),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: weekdayLabels
                .map(
                  (label) => Expanded(
                    child: Center(
                      child: Text(
                        label,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colors.onSurfaceVariant,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 6),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              childAspectRatio: 1.1,
            ),
            itemCount: firstWeekdayOffset + monthDays.length,
            itemBuilder: (ctx, index) {
              if (index < firstWeekdayOffset) {
                return const SizedBox.shrink();
              }
              final summary = monthDays[index - firstWeekdayOffset];
              return _buildCalendarDayCell(summary, theme, colors);
            },
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              _buildLegendItem(
                colors.primaryContainer,
                colors.primary,
                'Covered',
                theme,
              ),
              _buildLegendItem(
                colors.secondaryContainer,
                colors.secondary,
                'Partial',
                theme,
              ),
              _buildLegendItem(
                colors.errorContainer,
                colors.error,
                'Skipped',
                theme,
              ),
              _buildLegendItem(
                colors.surfaceContainerHighest,
                colors.onSurfaceVariant,
                'No log',
                theme,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarDayCell(
    MedicationAdherenceDaySummary summary,
    ThemeData theme,
    ColorScheme colors,
  ) {
    final (bgColor, fgColor, borderColor) = switch (summary.state) {
      MedicationDayAdherenceState.covered => (
        colors.primaryContainer,
        colors.onPrimaryContainer,
        colors.primary,
      ),
      MedicationDayAdherenceState.partial => (
        colors.secondaryContainer,
        colors.onSecondaryContainer,
        colors.secondary,
      ),
      MedicationDayAdherenceState.skipped => (
        colors.errorContainer,
        colors.onErrorContainer,
        colors.error,
      ),
      MedicationDayAdherenceState.noLog => (
        colors.surfaceContainerHighest.withValues(alpha: 0.45),
        colors.onSurfaceVariant,
        colors.outlineVariant,
      ),
      MedicationDayAdherenceState.notPrescribed => (
        Colors.transparent,
        colors.onSurfaceVariant.withValues(alpha: 0.4),
        Colors.transparent,
      ),
    };

    return Tooltip(
      message:
          'Day ${summary.date.day}: ${summary.takenCount} taken, ${summary.skippedCount} skipped',
      child: Container(
        key: ValueKey(
          'calendar-day-${summary.date.year}-${summary.date.month}-${summary.date.day}',
        ),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: borderColor.withValues(alpha: 0.5),
            width:
                summary.state == MedicationDayAdherenceState.covered ||
                    summary.state == MedicationDayAdherenceState.skipped
                ? 1.2
                : 0.5,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          '${summary.date.day}',
          style: theme.textTheme.labelSmall?.copyWith(
            color: fgColor,
            fontWeight:
                summary.state == MedicationDayAdherenceState.covered ||
                    summary.state == MedicationDayAdherenceState.skipped
                ? FontWeight.bold
                : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildLegendItem(
    Color bg,
    Color border,
    String label,
    ThemeData theme,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: border.withValues(alpha: 0.6)),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: theme.textTheme.labelSmall),
      ],
    );
  }

  Widget _buildLogTile(
    MedicationAdherenceLog log,
    BuildContext ctx,
    ColorScheme colors,
    ThemeData theme,
  ) {
    final local = log.takenAt.toLocal();
    final dateStr = MaterialLocalizations.of(ctx).formatShortDate(local);
    final timeStr = MaterialLocalizations.of(
      ctx,
    ).formatTimeOfDay(TimeOfDay.fromDateTime(local));
    final isSkipped = log.isSkipped;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: isSkipped
            ? colors.errorContainer
            : colors.primaryContainer,
        foregroundColor: isSkipped
            ? colors.onErrorContainer
            : colors.onPrimaryContainer,
        child: Icon(isSkipped ? Icons.close : Icons.check, size: 18),
      ),
      title: Text('${log.status.label} · $dateStr at $timeStr'),
      subtitle: log.notes != null ? Text(log.notes!) : null,
    );
  }
}
