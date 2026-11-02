import 'package:flutter/material.dart';

import '../../models/clinical_panel.dart';
import '../../models/doctor_visit_preparation.dart';
import '../../models/health_record.dart';
import '../../safety/critical_safety_evaluator.dart';
import '../../trends/health_trend.dart';
import '../shared/record_widgets.dart';

/// Interactive multi-step wizard for preparing a tailored clinical consultation summary.
class DoctorVisitWizardSheet extends StatefulWidget {
  const DoctorVisitWizardSheet({
    super.key,
    required this.records,
    required this.onGenerate,
  });

  final List<HealthRecord> records;
  final ValueChanged<DoctorVisitPreparationConfig> onGenerate;

  @override
  State<DoctorVisitWizardSheet> createState() => _DoctorVisitWizardSheetState();
}

class _DoctorVisitWizardSheetState extends State<DoctorVisitWizardSheet> {
  int _currentStep = 0;
  static const int _totalSteps = 5;

  DoctorVisitSpecialty _selectedSpecialty = DoctorVisitSpecialty.annualWellness;
  DateTime _visitDate = DateTime.now().add(const Duration(days: 7));
  final _clinicianController = TextEditingController();
  final _facilityController = TextEditingController();
  final _agendaInputController = TextEditingController();

  final Set<String> _selectedRecordIds = <String>{};
  final Map<String, String> _medicationNotes = <String, String>{};
  final List<String> _agendaItems = <String>[];
  final Map<String, TextEditingController> _medControllers = {};

  late List<HealthRecord> _vitals;
  late List<HealthRecord> _labs;
  late List<HealthRecord> _medications;
  late List<String> _smartSuggestions;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  void _initializeData() {
    _vitals =
        widget.records.where((r) => r.category == RecordCategory.vital).toList()
          ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));

    _labs =
        widget.records.where((r) => r.category == RecordCategory.lab).toList()
          ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));

    _medications =
        widget.records
            .where((r) => r.category == RecordCategory.medication)
            .toList()
          ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));

    // By default, select all records
    for (final r in widget.records) {
      _selectedRecordIds.add(r.id);
    }

    // Initialize medication note controllers
    for (final m in _medications) {
      _medControllers[m.name] = TextEditingController();
    }

    _generateSmartSuggestions();
  }

  void _generateSmartSuggestions() {
    _smartSuggestions = DoctorVisitPreparationConfig.generateSmartSuggestions(
      records: widget.records,
      specialty: _selectedSpecialty,
    );
  }

  @override
  void dispose() {
    _clinicianController.dispose();
    _facilityController.dispose();
    _agendaInputController.dispose();
    for (final controller in _medControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _onSpecialtyChanged(DoctorVisitSpecialty specialty) {
    setState(() {
      _selectedSpecialty = specialty;
      _generateSmartSuggestions();
    });
  }

  Future<void> _pickVisitDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _visitDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _visitDate = picked);
    }
  }

  void _addAgendaItem(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    if (!_agendaItems.contains(trimmed)) {
      setState(() {
        _agendaItems.add(trimmed);
        _agendaInputController.clear();
      });
    }
  }

  void _removeAgendaItem(int index) {
    setState(() {
      _agendaItems.removeAt(index);
    });
  }

  void _handleComplete() {
    // Collect medication notes from text controllers
    for (final entry in _medControllers.entries) {
      final note = entry.value.text.trim();
      if (note.isNotEmpty) {
        _medicationNotes[entry.key] = note;
      }
    }

    final config = DoctorVisitPreparationConfig(
      specialty: _selectedSpecialty,
      visitDate: _visitDate,
      clinicianName: _clinicianController.text.trim().isEmpty
          ? null
          : _clinicianController.text.trim(),
      facilityName: _facilityController.text.trim().isEmpty
          ? null
          : _facilityController.text.trim(),
      selectedRecordIds: _selectedRecordIds,
      medicationNotes: _medicationNotes,
      agendaItems: _agendaItems,
    );

    Navigator.of(context).pop();
    widget.onGenerate(config);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      key: const ValueKey('doctor-visit-wizard-sheet'),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.90,
        maxWidth: 720,
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with close button
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colors.primaryContainer.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.assignment_outlined, color: colors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Doctor Visit Preparation Wizard',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Step ${_currentStep + 1} of $_totalSteps: ${_stepTitle(_currentStep)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Close wizard',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Stepper progress indicator bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (_currentStep + 1) / _totalSteps,
              minHeight: 4,
              backgroundColor: colors.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
            ),
          ),
          const SizedBox(height: 16),
          // Scrollable step content
          Expanded(
            child: SingleChildScrollView(
              child: _buildCurrentStepContent(context),
            ),
          ),
          const SizedBox(height: 14),
          // Bottom Navigation Buttons
          Row(
            children: [
              if (_currentStep > 0)
                OutlinedButton.icon(
                  key: const ValueKey('wizard-back-btn'),
                  onPressed: () => setState(() => _currentStep--),
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: const Text('Back'),
                ),
              const Spacer(),
              if (_currentStep < _totalSteps - 1)
                FilledButton.icon(
                  key: const ValueKey('wizard-next-btn'),
                  onPressed: () => setState(() => _currentStep++),
                  icon: const Icon(Icons.arrow_forward, size: 18),
                  label: const Text('Next'),
                )
              else
                FilledButton.icon(
                  key: const ValueKey('wizard-generate-btn'),
                  onPressed: _handleComplete,
                  icon: const Icon(Icons.picture_as_pdf, size: 18),
                  label: const Text('Generate Summary'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _stepTitle(int step) {
    return switch (step) {
      0 => 'Specialty & Appointment',
      1 => 'Vitals & Trends',
      2 => 'Lab Results',
      3 => 'Medications & Questions',
      4 => 'Visit Agenda & Questions',
      _ => '',
    };
  }

  Widget _buildCurrentStepContent(BuildContext context) {
    return switch (_currentStep) {
      0 => _buildStep0SpecialtyAndAppointment(context),
      1 => _buildStep1Vitals(context),
      2 => _buildStep2Labs(context),
      3 => _buildStep3Medications(context),
      4 => _buildStep4Agenda(context),
      _ => const SizedBox(),
    };
  }

  // STEP 0: Specialty & Appointment
  Widget _buildStep0SpecialtyAndAppointment(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      key: const ValueKey('wizard-step-0'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Consultation Specialty',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Choose a template tailored to your upcoming appointment. The summary structure will emphasize the most relevant metrics.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        for (final specialty in DoctorVisitSpecialty.values) ...[
          _SpecialtyOptionTile(
            key: ValueKey('specialty-option-${specialty.id}'),
            specialty: specialty,
            isSelected: _selectedSpecialty == specialty,
            onTap: () => _onSpecialtyChanged(specialty),
          ),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 16),
        Text(
          'Appointment Details (Optional)',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: colors.outlineVariant),
          ),
          dense: true,
          leading: const Icon(Icons.calendar_today_outlined),
          title: const Text('Appointment Date'),
          subtitle: Text(formatRecordDate(_visitDate)),
          trailing: TextButton(
            onPressed: _pickVisitDate,
            child: const Text('Change'),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          key: const ValueKey('wizard-clinician-name-input'),
          controller: _clinicianController,
          decoration: const InputDecoration(
            labelText: 'Doctor / Clinician Name',
            hintText: 'e.g. Dr. Sarah Chen, MD',
            prefixIcon: Icon(Icons.person_outline),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          key: const ValueKey('wizard-facility-name-input'),
          controller: _facilityController,
          decoration: const InputDecoration(
            labelText: 'Clinic / Medical Center',
            hintText: 'e.g. Metro Health Cardiology Clinic',
            prefixIcon: Icon(Icons.local_hospital_outlined),
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }

  // STEP 1: Vitals & Trends
  Widget _buildStep1Vitals(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    if (_vitals.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Text(
            'No vital sign records found in vault.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    // Group vitals by name
    final grouped = <String, List<HealthRecord>>{};
    for (final v in _vitals) {
      grouped.putIfAbsent(v.name, () => []).add(v);
    }

    return Column(
      key: const ValueKey('wizard-step-1'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Select Vital Signs to Include',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  final allSelected = _vitals.every(
                    (v) => _selectedRecordIds.contains(v.id),
                  );
                  if (allSelected) {
                    for (final v in _vitals) {
                      _selectedRecordIds.remove(v.id);
                    }
                  } else {
                    for (final v in _vitals) {
                      _selectedRecordIds.add(v.id);
                    }
                  }
                });
              },
              child: Text(
                _vitals.every((v) => _selectedRecordIds.contains(v.id))
                    ? 'Deselect All'
                    : 'Select All',
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (final entry in grouped.entries) ...[
          _buildVitalGroupTile(entry.key, entry.value, colors, theme),
          const SizedBox(height: 6),
        ],
      ],
    );
  }

  Widget _buildVitalGroupTile(
    String name,
    List<HealthRecord> records,
    ColorScheme colors,
    ThemeData theme,
  ) {
    final latest = records.first;
    final isSelected = records.any((r) => _selectedRecordIds.contains(r.id));
    final critical = CriticalSafetyEvaluator.evaluate(latest);

    return CheckboxListTile(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: colors.outlineVariant),
      ),
      dense: true,
      value: isSelected,
      onChanged: (val) {
        setState(() {
          if (val == true) {
            for (final r in records) {
              _selectedRecordIds.add(r.id);
            }
          } else {
            for (final r in records) {
              _selectedRecordIds.remove(r.id);
            }
          }
        });
      },
      title: Row(
        children: [
          Expanded(child: Text(name)),
          if (critical != null)
            Container(
              margin: const EdgeInsets.only(left: 6),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: colors.error,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'CRITICAL',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colors.onError,
                  fontWeight: FontWeight.bold,
                  fontSize: 9,
                ),
              ),
            ),
        ],
      ),
      subtitle: Text(
        'Latest: ${latest.displayValue}  ·  ${formatRecordDate(latest.recordedAt)} (${records.length} readings)',
        style: theme.textTheme.bodySmall?.copyWith(
          color: colors.onSurfaceVariant,
        ),
      ),
    );
  }

  // STEP 2: Labs
  Widget _buildStep2Labs(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    if (_labs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Text(
            'No lab test records found in vault.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return Column(
      key: const ValueKey('wizard-step-2'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Select Lab Results to Include',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  final allSelected = _labs.every(
                    (l) => _selectedRecordIds.contains(l.id),
                  );
                  if (allSelected) {
                    for (final l in _labs) {
                      _selectedRecordIds.remove(l.id);
                    }
                  } else {
                    for (final l in _labs) {
                      _selectedRecordIds.add(l.id);
                    }
                  }
                });
              },
              child: Text(
                _labs.every((l) => _selectedRecordIds.contains(l.id))
                    ? 'Deselect All'
                    : 'Select All',
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (final record in _labs) ...[
          _buildLabTile(record, colors, theme),
          const SizedBox(height: 6),
        ],
      ],
    );
  }

  Widget _buildLabTile(
    HealthRecord record,
    ColorScheme colors,
    ThemeData theme,
  ) {
    final isSelected = _selectedRecordIds.contains(record.id);
    final range = HealthReferenceRange.tryParse(record.referenceRange);
    final numVal = parseHealthRecordValue(record.value);
    final status = (range != null && numVal != null)
        ? range.evaluate(numVal)
        : null;
    final isOutOfRange =
        status == HealthReferenceStatus.above ||
        status == HealthReferenceStatus.below;
    final critical = CriticalSafetyEvaluator.evaluate(record);
    final panel = extractRecordPanelInfo(record);

    return CheckboxListTile(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isOutOfRange
              ? colors.error.withValues(alpha: 0.5)
              : colors.outlineVariant,
        ),
      ),
      dense: true,
      value: isSelected,
      onChanged: (val) {
        setState(() {
          if (val == true) {
            _selectedRecordIds.add(record.id);
          } else {
            _selectedRecordIds.remove(record.id);
          }
        });
      },
      title: Row(
        children: [
          Expanded(
            child: Text(
              panel != null ? '${record.name} (${panel.name})' : record.name,
            ),
          ),
          if (critical != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: colors.error,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'CRITICAL',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colors.onError,
                  fontWeight: FontWeight.bold,
                  fontSize: 9,
                ),
              ),
            ),
          ] else if (isOutOfRange) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: colors.errorContainer,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                status == HealthReferenceStatus.above ? 'HIGH' : 'LOW',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colors.onErrorContainer,
                  fontWeight: FontWeight.bold,
                  fontSize: 9,
                ),
              ),
            ),
          ],
        ],
      ),
      subtitle: Text(
        '${record.displayValue}  ·  Ref: ${record.referenceRange ?? "None"}  ·  ${formatRecordDate(record.recordedAt)}',
        style: theme.textTheme.bodySmall?.copyWith(
          color: colors.onSurfaceVariant,
        ),
      ),
    );
  }

  // STEP 3: Medications & Questions
  Widget _buildStep3Medications(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    if (_medications.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Text(
            'No medication records found in vault.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return Column(
      key: const ValueKey('wizard-step-3'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Review Medications & Add Patient Notes',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Add specific questions, side effects, or renewal requests next to each medication to discuss with your doctor.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        for (final med in _medications) ...[
          _buildMedicationQuestionCard(med, colors, theme),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _buildMedicationQuestionCard(
    HealthRecord med,
    ColorScheme colors,
    ThemeData theme,
  ) {
    final controller = _medControllers.putIfAbsent(
      med.name,
      () => TextEditingController(),
    );

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.medication_outlined,
                  color: colors.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    med.name,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  med.displayValue,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              key: ValueKey('wizard-med-note-input-${med.name}'),
              controller: controller,
              decoration: InputDecoration(
                isDense: true,
                labelText: 'Question or concern for ${med.name} (optional)',
                hintText:
                    'e.g. Side effects, dosage adjustment, refill request...',
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // STEP 4: Agenda & Questions
  Widget _buildStep4Agenda(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      key: const ValueKey('wizard-step-4'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Personal Consultation Agenda',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Select smart suggestions from your observations or type custom questions to discuss during your consultation.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        if (_smartSuggestions.isNotEmpty) ...[
          Text(
            'Smart Suggestions (Tap to add)',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: colors.primary,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var i = 0; i < _smartSuggestions.length; i++)
                ActionChip(
                  key: ValueKey('wizard-smart-suggestion-$i'),
                  avatar: const Icon(Icons.add, size: 16),
                  label: Text(
                    _smartSuggestions[i],
                    style: const TextStyle(fontSize: 11),
                  ),
                  onPressed: () => _addAgendaItem(_smartSuggestions[i]),
                ),
            ],
          ),
          const SizedBox(height: 16),
        ],
        Row(
          children: [
            Expanded(
              child: TextField(
                key: const ValueKey('wizard-agenda-input'),
                controller: _agendaInputController,
                decoration: const InputDecoration(
                  isDense: true,
                  labelText: 'Add question or discussion item',
                  hintText: 'e.g. Inquire about lifestyle adjustments...',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: _addAgendaItem,
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              key: const ValueKey('wizard-add-agenda-btn'),
              onPressed: () => _addAgendaItem(_agendaInputController.text),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_agendaItems.isEmpty) ...[
          Container(
            padding: const EdgeInsets.all(16),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'No agenda items added yet. Add questions above to print on your visit summary.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ] else ...[
          Text(
            'Your Prioritized Discussion Agenda (${_agendaItems.length})',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < _agendaItems.length; i++) ...[
            ListTile(
              dense: true,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: colors.outlineVariant),
              ),
              leading: CircleAvatar(
                radius: 12,
                backgroundColor: colors.primaryContainer,
                child: Text(
                  '${i + 1}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: colors.onPrimaryContainer,
                  ),
                ),
              ),
              title: Text(_agendaItems[i]),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                tooltip: 'Remove',
                onPressed: () => _removeAgendaItem(i),
              ),
            ),
            const SizedBox(height: 6),
          ],
        ],
      ],
    );
  }
}

class _SpecialtyOptionTile extends StatelessWidget {
  const _SpecialtyOptionTile({
    super.key,
    required this.specialty,
    required this.isSelected,
    required this.onTap,
  });

  final DoctorVisitSpecialty specialty;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Tooltip(
      message: isSelected
          ? '${specialty.title} template (selected)'
          : 'Select ${specialty.title} template',
      child: Semantics(
        button: true,
        selected: isSelected,
        inMutuallyExclusiveGroup: true,
        label: '${specialty.title}: ${specialty.subtitle}',
        excludeSemantics: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? colors.primary : colors.outlineVariant,
                width: isSelected ? 2 : 1,
              ),
              color: isSelected
                  ? colors.primaryContainer.withValues(alpha: 0.25)
                  : colors.surface,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? colors.primary
                        : colors.surfaceContainerHighest,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    specialty.icon,
                    color: isSelected
                        ? colors.onPrimary
                        : colors.onSurfaceVariant,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        specialty.title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isSelected ? colors.primary : colors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        specialty.subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  isSelected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: isSelected ? colors.primary : colors.outline,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
