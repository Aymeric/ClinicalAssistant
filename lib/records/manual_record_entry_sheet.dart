import 'package:flutter/material.dart';

import '../models/health_record.dart';
import '../models/manual_medication_details.dart';

enum ManualEntryType {
  bloodPressure('Blood Pressure', Icons.favorite_border),
  glucose('Blood Glucose', Icons.water_drop_outlined),
  heartRate('Heart Rate', Icons.monitor_heart_outlined),
  weight('Body Weight', Icons.scale_outlined),
  temperature('Temperature', Icons.thermostat_outlined),
  oxygen('Oxygen (SpO2)', Icons.air_outlined),
  medication('Medication', Icons.medication_outlined),
  custom('Custom Measurement', Icons.tune_outlined);

  const ManualEntryType(this.label, this.icon);
  final String label;
  final IconData icon;
}

class ManualRecordEntrySheet extends StatefulWidget {
  const ManualRecordEntrySheet({super.key, required this.onSave});

  final ValueChanged<List<HealthRecord>> onSave;

  @override
  State<ManualRecordEntrySheet> createState() => _ManualRecordEntrySheetState();
}

class _ManualRecordEntrySheetState extends State<ManualRecordEntrySheet> {
  var _selectedType = ManualEntryType.bloodPressure;
  var _recordedAt = DateTime.now();

  // Controllers for values
  final _systolicController = TextEditingController(text: '120');
  final _diastolicController = TextEditingController(text: '80');
  final _valueController = TextEditingController();
  final _customNameController = TextEditingController();
  final _customUnitController = TextEditingController();
  final _refRangeController = TextEditingController();
  final _medicationFrequencyController = TextEditingController();
  final _medicationRouteController = TextEditingController();
  final _notesController = TextEditingController();

  var _customCategory = RecordCategory.vital;
  var _glucoseContext = 'Fasting';
  var _weightUnit = 'lbs';
  var _tempUnit = '°F';
  var _medicationStatus = 'active';
  DateTime? _medicationEndDate;

  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _systolicController.dispose();
    _diastolicController.dispose();
    _valueController.dispose();
    _customNameController.dispose();
    _customUnitController.dispose();
    _refRangeController.dispose();
    _medicationFrequencyController.dispose();
    _medicationRouteController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _onTypeChanged(ManualEntryType type) {
    setState(() {
      _selectedType = type;
      _valueController.clear();
      _customNameController.clear();
      _refRangeController.clear();
      _medicationFrequencyController.clear();
      _medicationRouteController.clear();
      switch (type) {
        case ManualEntryType.glucose:
          _refRangeController.text = '70 – 99 mg/dL';
          break;
        case ManualEntryType.heartRate:
          _refRangeController.text = '60 – 100 bpm';
          break;
        case ManualEntryType.oxygen:
          _refRangeController.text = '95 – 100 %';
          break;
        case ManualEntryType.temperature:
          _refRangeController.text =
              _tempUnit == '°F' ? '97.0 – 99.0 °F' : '36.1 – 37.2 °C';
          break;
        case ManualEntryType.medication:
          _medicationStatus = 'active';
          _medicationEndDate = null;
          break;
        default:
          break;
      }
    });
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _recordedAt,
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_recordedAt),
    );
    if (pickedTime == null || !mounted) return;

    setState(() {
      _recordedAt = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  Future<void> _pickMedicationEndDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _medicationEndDate ?? now,
      firstDate: DateUtils.dateOnly(_recordedAt),
      lastDate: now,
    );
    if (picked == null || !mounted) return;
    setState(() => _medicationEndDate = picked);
    _formKey.currentState?.validate();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final timestamp = _recordedAt.toUtc();
    final noteText = _notesController.text.trim();
    final userNote = noteText.isEmpty ? null : noteText;
    final nowMs = DateTime.now().microsecondsSinceEpoch;

    final records = <HealthRecord>[];

    switch (_selectedType) {
      case ManualEntryType.bloodPressure:
        final sysVal = _systolicController.text.trim();
        final diaVal = _diastolicController.text.trim();
        records.add(
          HealthRecord(
            id: 'manual:sys:$nowMs',
            name: 'Systolic Blood Pressure',
            value: sysVal,
            unit: 'mmHg',
            recordedAt: timestamp,
            category: RecordCategory.vital,
            source: 'Manual Entry',
            referenceRange: '< 120 mmHg',
            notes: userNote,
          ),
        );
        records.add(
          HealthRecord(
            id: 'manual:dia:$nowMs',
            name: 'Diastolic Blood Pressure',
            value: diaVal,
            unit: 'mmHg',
            recordedAt: timestamp,
            category: RecordCategory.vital,
            source: 'Manual Entry',
            referenceRange: '< 80 mmHg',
            notes: userNote,
          ),
        );
        break;

      case ManualEntryType.glucose:
        final fullNote = [
          'Context: $_glucoseContext',
          if (userNote != null) userNote
        ].join(' · ');
        records.add(
          HealthRecord(
            id: 'manual:glucose:$nowMs',
            name: 'Blood Glucose',
            value: _valueController.text.trim(),
            unit: 'mg/dL',
            recordedAt: timestamp,
            category: RecordCategory.lab,
            source: 'Manual Entry',
            referenceRange: _refRangeController.text.trim().isEmpty
                ? '70 – 99 mg/dL'
                : _refRangeController.text.trim(),
            notes: fullNote,
          ),
        );
        break;

      case ManualEntryType.heartRate:
        records.add(
          HealthRecord(
            id: 'manual:hr:$nowMs',
            name: 'Heart Rate',
            value: _valueController.text.trim(),
            unit: 'bpm',
            recordedAt: timestamp,
            category: RecordCategory.vital,
            source: 'Manual Entry',
            referenceRange: _refRangeController.text.trim().isEmpty
                ? '60 – 100 bpm'
                : _refRangeController.text.trim(),
            notes: userNote,
          ),
        );
        break;

      case ManualEntryType.weight:
        records.add(
          HealthRecord(
            id: 'manual:weight:$nowMs',
            name: 'Weight',
            value: _valueController.text.trim(),
            unit: _weightUnit,
            recordedAt: timestamp,
            category: RecordCategory.vital,
            source: 'Manual Entry',
            notes: userNote,
          ),
        );
        break;

      case ManualEntryType.temperature:
        records.add(
          HealthRecord(
            id: 'manual:temp:$nowMs',
            name: 'Body Temperature',
            value: _valueController.text.trim(),
            unit: _tempUnit,
            recordedAt: timestamp,
            category: RecordCategory.vital,
            source: 'Manual Entry',
            referenceRange: _refRangeController.text.trim().isEmpty
                ? (_tempUnit == '°F' ? '97.0 – 99.0 °F' : '36.1 – 37.2 °C')
                : _refRangeController.text.trim(),
            notes: userNote,
          ),
        );
        break;

      case ManualEntryType.oxygen:
        records.add(
          HealthRecord(
            id: 'manual:spo2:$nowMs',
            name: 'Oxygen Saturation',
            value: _valueController.text.trim(),
            unit: '%',
            recordedAt: timestamp,
            category: RecordCategory.vital,
            source: 'Manual Entry',
            referenceRange: _refRangeController.text.trim().isEmpty
                ? '95 – 100 %'
                : _refRangeController.text.trim(),
            notes: userNote,
          ),
        );
        break;

      case ManualEntryType.medication:
        final route = _medicationRouteController.text.trim();
        final details = ManualMedicationDetails(
          frequency: _medicationFrequencyController.text.trim(),
          route: route.isEmpty ? null : route,
          endDate: _medicationEndDate,
        );
        records.add(
          HealthRecord(
            id: 'manual:medication:$nowMs',
            name: _customNameController.text.trim(),
            value: _valueController.text.trim(),
            unit: '',
            recordedAt: timestamp,
            category: RecordCategory.medication,
            source: 'Manual Entry',
            status: _medicationStatus,
            sourceData: details.withSourceData(null),
            notes: userNote,
          ),
        );
        break;

      case ManualEntryType.custom:
        final ref = _refRangeController.text.trim();
        records.add(
          HealthRecord(
            id: 'manual:custom:$nowMs',
            name: _customNameController.text.trim(),
            value: _valueController.text.trim(),
            unit: _customUnitController.text.trim(),
            recordedAt: timestamp,
            category: _customCategory,
            source: 'Manual Entry',
            referenceRange: ref.isEmpty ? null : ref,
            notes: userNote,
          ),
        );
        break;
    }

    widget.onSave(records);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateStr =
        MaterialLocalizations.of(context).formatMediumDate(_recordedAt);
    final timeStr = MaterialLocalizations.of(context)
        .formatTimeOfDay(TimeOfDay.fromDateTime(_recordedAt));

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.edit_note,
                    color: theme.colorScheme.primary,
                    size: 28,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _selectedType == ManualEntryType.medication
                        ? 'Log Medication'
                        : 'Log Health Measurement',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Preset type selector chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final type in ManualEntryType.values)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          selected: _selectedType == type,
                          label: Text(type.label),
                          avatar: Icon(type.icon, size: 16),
                          onSelected: (_) => _onTypeChanged(type),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Date/time trigger
              InkWell(
                onTap: _pickDateTime,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _selectedType == ManualEntryType.medication
                            ? 'Started: $dateStr, $timeStr'
                            : 'Recorded at: $dateStr, $timeStr',
                        style: theme.textTheme.bodyMedium,
                      ),
                      const Spacer(),
                      Text(
                        'Change',
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Fields specific to selected type
              if (_selectedType == ManualEntryType.bloodPressure) ...[
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _systolicController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Systolic (mmHg)',
                          hintText: '120',
                          border: OutlineInputBorder(),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Required';
                          }
                          if (double.tryParse(val.trim()) == null) {
                            return 'Invalid number';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _diastolicController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Diastolic (mmHg)',
                          hintText: '80',
                          border: OutlineInputBorder(),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Required';
                          }
                          if (double.tryParse(val.trim()) == null) {
                            return 'Invalid number';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
              ] else if (_selectedType == ManualEntryType.medication) ...[
                TextFormField(
                  key: const ValueKey('manual-medication-name'),
                  controller: _customNameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Medication name',
                    hintText: 'e.g. Medication name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter a medication name'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const ValueKey('manual-medication-dose'),
                  controller: _valueController,
                  decoration: const InputDecoration(
                    labelText: 'Dose / instructions',
                    hintText: 'e.g. 10 mg or 1 tablet',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter the dose or instructions'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const ValueKey('manual-medication-frequency'),
                  controller: _medicationFrequencyController,
                  decoration: const InputDecoration(
                    labelText: 'Frequency',
                    hintText: 'e.g. once daily or as needed',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter the reported frequency'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const ValueKey('manual-medication-route'),
                  controller: _medicationRouteController,
                  decoration: const InputDecoration(
                    labelText: 'Route (optional)',
                    hintText: 'e.g. oral, topical, inhaled',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: const ValueKey('manual-medication-status'),
                  initialValue: _medicationStatus,
                  decoration: const InputDecoration(
                    labelText: 'Status',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'active', child: Text('Active')),
                    DropdownMenuItem(value: 'stopped', child: Text('Stopped')),
                    DropdownMenuItem(value: 'on-hold', child: Text('On hold')),
                    DropdownMenuItem(
                      value: 'completed',
                      child: Text('Completed'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _medicationStatus = value;
                      if (value == 'active' || value == 'on-hold') {
                        _medicationEndDate = null;
                      }
                    });
                  },
                  validator: (value) =>
                      (value == 'stopped' || value == 'completed') &&
                              _medicationEndDate == null
                          ? 'Choose an end date'
                          : null,
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  key: const ValueKey('manual-medication-end-date'),
                  onPressed: _medicationStatus == 'active' ||
                          _medicationStatus == 'on-hold'
                      ? null
                      : _pickMedicationEndDate,
                  icon: const Icon(Icons.event_outlined),
                  label: Text(
                    _medicationEndDate == null
                        ? 'Choose end date'
                        : 'Ended: ${MaterialLocalizations.of(context).formatMediumDate(_medicationEndDate!)}',
                  ),
                ),
              ] else if (_selectedType == ManualEntryType.custom) ...[
                TextFormField(
                  controller: _customNameController,
                  decoration: const InputDecoration(
                    labelText: 'Measurement Name',
                    hintText: 'e.g. Total Cholesterol, Ferritin',
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) =>
                      val == null || val.trim().isEmpty ? 'Enter a name' : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _valueController,
                        decoration: const InputDecoration(
                          labelText: 'Value',
                          border: OutlineInputBorder(),
                        ),
                        validator: (val) => val == null || val.trim().isEmpty
                            ? 'Required'
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _customUnitController,
                        decoration: const InputDecoration(
                          labelText: 'Unit',
                          hintText: 'mg/dL, %',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('Category: '),
                    ChoiceChip(
                      label: const Text('Vital'),
                      selected: _customCategory == RecordCategory.vital,
                      onSelected: (_) => setState(
                        () => _customCategory = RecordCategory.vital,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Lab'),
                      selected: _customCategory == RecordCategory.lab,
                      onSelected: (_) =>
                          setState(() => _customCategory = RecordCategory.lab),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _refRangeController,
                  decoration: const InputDecoration(
                    labelText: 'Reference Range (optional)',
                    hintText: 'e.g. 100 – 199 mg/dL',
                    border: OutlineInputBorder(),
                  ),
                ),
              ] else ...[
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _valueController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText:
                              'Value (${_getUnitForType(_selectedType)})',
                          border: const OutlineInputBorder(),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Required';
                          }
                          if (double.tryParse(val.trim()) == null) {
                            return 'Invalid number';
                          }
                          return null;
                        },
                      ),
                    ),
                    if (_selectedType == ManualEntryType.weight) ...[
                      const SizedBox(width: 12),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'lbs', label: Text('lbs')),
                          ButtonSegment(value: 'kg', label: Text('kg')),
                        ],
                        selected: {_weightUnit},
                        onSelectionChanged: (set) =>
                            setState(() => _weightUnit = set.first),
                      ),
                    ] else if (_selectedType ==
                        ManualEntryType.temperature) ...[
                      const SizedBox(width: 12),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: '°F', label: Text('°F')),
                          ButtonSegment(value: '°C', label: Text('°C')),
                        ],
                        selected: {_tempUnit},
                        onSelectionChanged: (set) {
                          setState(() {
                            _tempUnit = set.first;
                            _refRangeController.text = _tempUnit == '°F'
                                ? '97.0 – 99.0 °F'
                                : '36.1 – 37.2 °C';
                          });
                        },
                      ),
                    ],
                  ],
                ),
                if (_selectedType == ManualEntryType.glucose) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text('Context:'),
                      for (final ctx in ['Fasting', 'Random', 'Postprandial'])
                        ChoiceChip(
                          label: Text(ctx),
                          selected: _glucoseContext == ctx,
                          onSelected: (_) =>
                              setState(() => _glucoseContext = ctx),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                TextFormField(
                  controller: _refRangeController,
                  decoration: const InputDecoration(
                    labelText: 'Reference Range (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],

              const SizedBox(height: 16),
              // Personal Notes Field
              TextFormField(
                controller: _notesController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Personal Notes / Context (optional)',
                  hintText:
                      'e.g. Taken after 15 min rest, fasting 12h, post-workout',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.note_add_outlined),
                ),
              ),

              const SizedBox(height: 20),
              FilledButton.icon(
                icon: const Icon(Icons.check),
                label: Text(
                  _selectedType == ManualEntryType.medication
                      ? 'Save Medication to Vault'
                      : 'Save Measurement to Vault',
                ),
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getUnitForType(ManualEntryType type) => switch (type) {
        ManualEntryType.glucose => 'mg/dL',
        ManualEntryType.heartRate => 'bpm',
        ManualEntryType.weight => _weightUnit,
        ManualEntryType.temperature => _tempUnit,
        ManualEntryType.oxygen => '%',
        _ => '',
      };
}
