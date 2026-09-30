import 'package:flutter/material.dart';

import '../models/health_record.dart';
import '../models/manual_medication_details.dart';

List<HealthRecord> applyManualRecordEdits(
  List<HealthRecord> currentRecords,
  List<HealthRecord> editedRecords,
) {
  if (editedRecords.isEmpty) {
    throw ArgumentError.value(
      editedRecords,
      'editedRecords',
      'Must not be empty.',
    );
  }

  final currentById = {for (final record in currentRecords) record.id: record};
  final editedById = <String, HealthRecord>{};
  for (final edited in editedRecords) {
    if (editedById.containsKey(edited.id)) {
      throw ArgumentError.value(
        edited.id,
        'editedRecords',
        'Record IDs must be unique.',
      );
    }
    final current = currentById[edited.id];
    if (current == null || !current.isManual || !edited.isManual) {
      throw StateError('Only existing manual records can be edited.');
    }
    editedById[edited.id] = edited;
  }

  for (final editedId in editedById.keys) {
    final match = RegExp(r'^manual:(sys|dia):(.+)$').firstMatch(editedId);
    if (match == null) continue;
    final siblingType = match[1] == 'sys' ? 'dia' : 'sys';
    final siblingId = 'manual:$siblingType:${match[2]}';
    final sibling = currentById[siblingId];
    if (sibling != null && sibling.isManual) {
      final siblingEdit = editedById[siblingId];
      if (siblingEdit == null) {
        throw StateError('Blood-pressure records must be edited together.');
      }
      if (siblingEdit.recordedAt != editedById[editedId]!.recordedAt) {
        throw StateError('Blood-pressure records must share a recorded time.');
      }
    }
  }

  final updated = currentRecords.map((current) {
    final edit = editedById[current.id];
    if (edit == null) return current;
    if (current.category == RecordCategory.medication) {
      final details = ManualMedicationDetails.fromRecord(edit);
      if (edit.value.trim().isEmpty) {
        throw StateError('Medication dose or instructions are required.');
      }
      if (details.frequency.trim().isEmpty) {
        throw StateError('Medication frequency is required.');
      }
      if (!const {
        'active',
        'stopped',
        'on-hold',
        'completed',
      }.contains(edit.status)) {
        throw StateError('Medication status is not supported.');
      }
      if ((edit.status == 'stopped' || edit.status == 'completed') &&
          details.endDate == null) {
        throw StateError('Stopped medications need an end date.');
      }
      if ((edit.status == 'active' || edit.status == 'on-hold') &&
          details.endDate != null) {
        throw StateError(
          'Active or on-hold medications cannot have an end date.',
        );
      }
      if (details.endDate != null &&
          DateUtils.dateOnly(details.endDate!.toLocal())
              .isBefore(DateUtils.dateOnly(edit.recordedAt.toLocal()))) {
        throw StateError(
          'Medication end date cannot be before its start date.',
        );
      }
      return current.copyWith(
        value: edit.value,
        recordedAt: edit.recordedAt,
        status: edit.status,
        sourceData: details.withSourceData(current.sourceData),
      );
    }
    return current.copyWith(value: edit.value, recordedAt: edit.recordedAt);
  }).toList()
    ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
  return updated;
}

class ManualRecordEditSheet extends StatefulWidget {
  const ManualRecordEditSheet({
    super.key,
    required this.records,
    required this.onSave,
  }) : assert(records.length > 0);

  final List<HealthRecord> records;
  final Future<void> Function(List<HealthRecord> records) onSave;

  @override
  State<ManualRecordEditSheet> createState() => _ManualRecordEditSheetState();
}

class _ManualRecordEditSheetState extends State<ManualRecordEditSheet> {
  late final TextEditingController _valueController;
  late final TextEditingController _systolicController;
  late final TextEditingController _diastolicController;
  late final TextEditingController _medicationFrequencyController;
  late final TextEditingController _medicationRouteController;
  late DateTime _recordedAt;
  DateTime? _medicationEndDate;
  late String _medicationStatus;
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;
  String? _error;

  bool get _isBloodPressurePair =>
      widget.records.length == 2 &&
      widget.records.any(
        (record) => record.name == 'Systolic Blood Pressure',
      ) &&
      widget.records.any((record) => record.name == 'Diastolic Blood Pressure');

  bool get _isMedication =>
      widget.records.length == 1 &&
      widget.records.single.category == RecordCategory.medication;

  bool get _medicationNeedsEndDate =>
      _medicationStatus == 'stopped' || _medicationStatus == 'completed';

  HealthRecord get _systolic => widget.records.firstWhere(
        (record) => record.name == 'Systolic Blood Pressure',
      );

  HealthRecord get _diastolic => widget.records.firstWhere(
        (record) => record.name == 'Diastolic Blood Pressure',
      );

  @override
  void initState() {
    super.initState();
    _recordedAt = widget.records.first.recordedAt.toLocal();
    _valueController = TextEditingController(text: widget.records.first.value);
    _systolicController = TextEditingController(
      text: _isBloodPressurePair ? _systolic.value : '',
    );
    _diastolicController = TextEditingController(
      text: _isBloodPressurePair ? _diastolic.value : '',
    );
    final medicationDetails = ManualMedicationDetails.fromRecord(
      widget.records.first,
    );
    _medicationFrequencyController = TextEditingController(
      text: medicationDetails.frequency,
    );
    _medicationRouteController = TextEditingController(
      text: medicationDetails.route ?? '',
    );
    _medicationEndDate = medicationDetails.endDate?.toLocal();
    final status = widget.records.first.status;
    _medicationStatus =
        const {'active', 'stopped', 'on-hold', 'completed'}.contains(status)
            ? status!
            : 'active';
  }

  @override
  void dispose() {
    _valueController.dispose();
    _systolicController.dispose();
    _diastolicController.dispose();
    _medicationFrequencyController.dispose();
    _medicationRouteController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _recordedAt,
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_recordedAt),
    );
    if (time == null || !mounted) return;
    setState(() {
      _recordedAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
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

  String? _validateValue(String? value, {bool requireNumeric = false}) {
    if (value == null || value.trim().isEmpty) return 'Required';
    if (requireNumeric && parseHealthRecordValue(value) == null) {
      return 'Enter a valid number';
    }
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    final timestamp = _recordedAt.toUtc();
    final edits = _isBloodPressurePair
        ? [
            _systolic.copyWith(
              value: _systolicController.text.trim(),
              recordedAt: timestamp,
            ),
            _diastolic.copyWith(
              value: _diastolicController.text.trim(),
              recordedAt: timestamp,
            ),
          ]
        : _isMedication
            ? [
                widget.records.first.copyWith(
                  value: _valueController.text.trim(),
                  recordedAt: timestamp,
                  status: _medicationStatus,
                  sourceData: ManualMedicationDetails(
                    frequency: _medicationFrequencyController.text.trim(),
                    route: _medicationRouteController.text.trim().isEmpty
                        ? null
                        : _medicationRouteController.text.trim(),
                    endDate: _medicationEndDate,
                  ).withSourceData(widget.records.first.sourceData),
                ),
              ]
            : [
                widget.records.first.copyWith(
                  value: _valueController.text.trim(),
                  recordedAt: timestamp,
                ),
              ];

    try {
      await widget.onSave(edits);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not save changes: $error';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final date =
        MaterialLocalizations.of(context).formatMediumDate(_recordedAt);
    final time = MaterialLocalizations.of(context)
        .formatTimeOfDay(TimeOfDay.fromDateTime(_recordedAt));

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _isBloodPressurePair
                    ? 'Edit Blood Pressure'
                    : 'Edit ${widget.records.first.name}',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              if (_isBloodPressurePair) ...[
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        key: const ValueKey('edit-systolic-value'),
                        controller: _systolicController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Systolic (mmHg)',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) =>
                            _validateValue(value, requireNumeric: true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        key: const ValueKey('edit-diastolic-value'),
                        controller: _diastolicController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Diastolic (mmHg)',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) =>
                            _validateValue(value, requireNumeric: true),
                      ),
                    ),
                  ],
                ),
              ] else
                TextFormField(
                  key: const ValueKey('edit-record-value'),
                  controller: _valueController,
                  keyboardType:
                      parseHealthRecordValue(widget.records.first.value) != null
                          ? const TextInputType.numberWithOptions(decimal: true)
                          : TextInputType.text,
                  decoration: InputDecoration(
                    labelText: _isMedication
                        ? 'Dose / instructions'
                        : 'Value (${widget.records.first.unit})',
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) => _validateValue(
                    value,
                    requireNumeric:
                        parseHealthRecordValue(widget.records.first.value) !=
                            null,
                  ),
                ),
              const SizedBox(height: 12),
              InkWell(
                key: const ValueKey('edit-recorded-at'),
                onTap: _pickDateTime,
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: _isMedication ? 'Started at' : 'Recorded at',
                    border: const OutlineInputBorder(),
                    suffixIcon: const Icon(Icons.calendar_today),
                  ),
                  child: Text('$date, $time'),
                ),
              ),
              if (_isMedication) ...[
                const SizedBox(height: 12),
                TextFormField(
                  key: const ValueKey('edit-medication-frequency'),
                  controller: _medicationFrequencyController,
                  decoration: const InputDecoration(
                    labelText: 'Frequency',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter the reported frequency'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const ValueKey('edit-medication-route'),
                  controller: _medicationRouteController,
                  decoration: const InputDecoration(
                    labelText: 'Route (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: const ValueKey('edit-medication-status'),
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
                  key: const ValueKey('edit-medication-end-date'),
                  onPressed:
                      _medicationNeedsEndDate ? _pickMedicationEndDate : null,
                  icon: const Icon(Icons.event_outlined),
                  label: Text(
                    _medicationEndDate == null
                        ? 'Choose end date'
                        : 'Ended: ${MaterialLocalizations.of(context).formatMediumDate(_medicationEndDate!)}',
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
              ],
              const SizedBox(height: 20),
              FilledButton.icon(
                key: const ValueKey('save-manual-record-edit'),
                onPressed: _saving ? null : _submit,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check),
                label: const Text('Save Changes'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
