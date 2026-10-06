import 'package:flutter/material.dart';

import '../../models/health_record.dart';
import '../../trends/health_trend.dart';
import '../shared/record_widgets.dart';
import 'record_details_sheet.dart';

enum RecordSortOrder {
  newestFirst('Newest first', Icons.arrow_downward),
  oldestFirst('Oldest first', Icons.arrow_upward),
  nameAsc('Name (A–Z)', Icons.sort_by_alpha),
  nameDesc('Name (Z–A)', Icons.sort_by_alpha);

  const RecordSortOrder(this.label, this.icon);
  final String label;
  final IconData icon;
}

class RecordsPage extends StatefulWidget {
  const RecordsPage({
    super.key,
    required this.records,
    this.initialCategory,
    this.initialOutOfRangeOnly = false,
    this.onViewInTrends,
    this.onRecordTap,
    this.onRefresh,
    this.onLogRecord,
  });

  final List<HealthRecord> records;
  final RecordCategory? initialCategory;
  final bool initialOutOfRangeOnly;
  final ValueChanged<HealthRecord>? onViewInTrends;
  final ValueChanged<HealthRecord>? onRecordTap;
  final Future<void> Function()? onRefresh;
  final VoidCallback? onLogRecord;

  @override
  State<RecordsPage> createState() => RecordsPageState();
}

class RecordsPageState extends State<RecordsPage> {
  final _searchController = TextEditingController();
  RecordCategory? _filter;
  bool _filterOutOfRange = false;
  String? _sourceFilter;
  DateTimeRange? _selectedDateRange;
  String _searchQuery = '';
  RecordSortOrder _sortOrder = RecordSortOrder.newestFirst;

  // Memoized metadata to prevent re-mapping, set-creating, and sorting
  // on every UI build (e.g. per keystroke during search typing).
  List<DateTime> _availableDates = const [];
  List<String> _availableSources = const [];

  @override
  void initState() {
    super.initState();
    _filter = widget.initialCategory;
    _filterOutOfRange = widget.initialOutOfRangeOnly;
    _updateAvailableMetadata();
  }

  void _updateAvailableMetadata() {
    _availableDates =
        widget.records
            .map((record) => DateUtils.dateOnly(record.recordedAt.toLocal()))
            .toSet()
            .toList()
          ..sort((a, b) => b.compareTo(a));

    _availableSources = widget.records.map((r) => r.source).toSet().toList()
      ..sort();
  }

  @override
  void didUpdateWidget(covariant RecordsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialCategory != oldWidget.initialCategory &&
        widget.initialCategory != null) {
      _filter = widget.initialCategory;
    }
    if (widget.initialOutOfRangeOnly != oldWidget.initialOutOfRangeOnly) {
      _filterOutOfRange = widget.initialOutOfRangeOnly;
    }
    if (widget.records != oldWidget.records) {
      _updateAvailableMetadata();
    }
    if (_selectedDateRange != null &&
        !widget.records.any((record) {
          final date = DateUtils.dateOnly(record.recordedAt.toLocal());
          return !date.isBefore(_selectedDateRange!.start) &&
              !date.isAfter(_selectedDateRange!.end);
        })) {
      _selectedDateRange = null;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void setOutOfRangeFilter(bool active) {
    setState(() => _filterOutOfRange = active);
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchQuery.trim().toLowerCase();
    final availableDates = _availableDates;
    final availableSources = _availableSources;

    final filtered = widget.records.where((record) {
      if (_filter != null && record.category != _filter) return false;
      if (_sourceFilter != null && record.source != _sourceFilter) return false;
      if (_filterOutOfRange) {
        if (record.category != RecordCategory.lab ||
            record.referenceRange == null ||
            record.referenceRange!.isEmpty) {
          return false;
        }
        final range = HealthReferenceRange.tryParse(record.referenceRange);
        final numVal = parseHealthRecordValue(record.value);
        if (range == null || numVal == null) return false;
        final status = range.evaluate(numVal);
        if (status != HealthReferenceStatus.above &&
            status != HealthReferenceStatus.below) {
          return false;
        }
      }
      if (_selectedDateRange != null) {
        final date = DateUtils.dateOnly(record.recordedAt.toLocal());
        if (date.isBefore(_selectedDateRange!.start) ||
            date.isAfter(_selectedDateRange!.end)) {
          return false;
        }
      }
      if (query.isEmpty) return true;

      // Lazy short-circuit search check: avoids allocating lists, joining strings,
      // and lowercasing unused fields on every record per keystroke.
      return record.name.toLowerCase().contains(query) ||
          record.displayValue.toLowerCase().contains(query) ||
          record.source.toLowerCase().contains(query) ||
          (record.code?.toLowerCase().contains(query) ?? false) ||
          (record.referenceRange?.toLowerCase().contains(query) ?? false) ||
          (record.status?.toLowerCase().contains(query) ?? false) ||
          (record.notes?.toLowerCase().contains(query) ?? false);
    }).toList();

    switch (_sortOrder) {
      case RecordSortOrder.newestFirst:
        filtered.sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
      case RecordSortOrder.oldestFirst:
        filtered.sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
      case RecordSortOrder.nameAsc:
        filtered.sort((a, b) {
          final cmp = a.name.toLowerCase().compareTo(b.name.toLowerCase());
          return cmp != 0 ? cmp : b.recordedAt.compareTo(a.recordedAt);
        });
      case RecordSortOrder.nameDesc:
        filtered.sort((a, b) {
          final cmp = b.name.toLowerCase().compareTo(a.name.toLowerCase());
          return cmp != 0 ? cmp : b.recordedAt.compareTo(a.recordedAt);
        });
    }

    final hasActiveFilter =
        _filter != null ||
        _filterOutOfRange ||
        _sourceFilter != null ||
        _selectedDateRange != null ||
        query.isNotEmpty;

    final scrollView = CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 16, 22, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'A dated trail of what you’ve collected.',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    if (widget.onLogRecord != null)
                      FilledButton.icon(
                        key: const ValueKey('records-log-record-button'),
                        onPressed: widget.onLogRecord,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Log'),
                        style: FilledButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 4,
                  children: [
                    IconButton(
                      tooltip: 'Older records',
                      onPressed: _stepDateRange(availableDates, -1),
                      icon: const Icon(Icons.chevron_left),
                    ),
                    OutlinedButton.icon(
                      key: const ValueKey('record-date-picker'),
                      onPressed: availableDates.isEmpty
                          ? null
                          : () => _chooseDateRange(availableDates),
                      icon: const Icon(Icons.calendar_month_outlined),
                      label: Text(_dateRangeLabel(context)),
                    ),
                    IconButton(
                      tooltip: 'Newer records',
                      onPressed: _stepDateRange(availableDates, 1),
                      icon: const Icon(Icons.chevron_right),
                    ),
                    if (_selectedDateRange != null)
                      TextButton(
                        key: const ValueKey('record-date-clear'),
                        onPressed: () =>
                            setState(() => _selectedDateRange = null),
                        child: const Text('All dates'),
                      ),
                    const SizedBox(width: 8),
                    PopupMenuButton<RecordSortOrder>(
                      key: const ValueKey('record-sort-button'),
                      tooltip: 'Sort: ${_sortOrder.label}',
                      initialValue: _sortOrder,
                      onSelected: (order) => setState(() => _sortOrder = order),
                      itemBuilder: (context) => [
                        for (final order in RecordSortOrder.values)
                          PopupMenuItem(
                            value: order,
                            child: Row(
                              children: [
                                Icon(order.icon, size: 18),
                                const SizedBox(width: 8),
                                Text(order.label),
                              ],
                            ),
                          ),
                      ],
                      icon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_sortOrder.icon, size: 18),
                          const SizedBox(width: 4),
                          const Icon(Icons.arrow_drop_down, size: 18),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      DatePresetChip(
                        key: const ValueKey('record-preset-all'),
                        label: 'All time',
                        selected: _selectedDateRange == null,
                        onSelected: () =>
                            setState(() => _selectedDateRange = null),
                      ),
                      const SizedBox(width: 6),
                      DatePresetChip(
                        key: const ValueKey('record-preset-7d'),
                        label: '7D',
                        selected: _isPresetSelected(7),
                        onSelected: () => _applyDaysPreset(7),
                      ),
                      const SizedBox(width: 6),
                      DatePresetChip(
                        key: const ValueKey('record-preset-30d'),
                        label: '30D',
                        selected: _isPresetSelected(30),
                        onSelected: () => _applyDaysPreset(30),
                      ),
                      const SizedBox(width: 6),
                      DatePresetChip(
                        key: const ValueKey('record-preset-90d'),
                        label: '90D',
                        selected: _isPresetSelected(90),
                        onSelected: () => _applyDaysPreset(90),
                      ),
                      const SizedBox(width: 6),
                      DatePresetChip(
                        key: const ValueKey('record-preset-1y'),
                        label: '1Y',
                        selected: _isPresetSelected(365),
                        onSelected: () => _applyDaysPreset(365),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const ValueKey('record-search'),
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  onChanged: (value) => setState(() => _searchQuery = value),
                  decoration: InputDecoration(
                    hintText: 'Search records, values, or sources',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isEmpty
                        ? null
                        : IconButton(
                            key: const ValueKey('record-search-clear'),
                            tooltip: 'Clear search',
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                            icon: const Icon(Icons.close),
                          ),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FilterChip(
                        label: const Text('All'),
                        selected:
                            _filter == null &&
                            !_filterOutOfRange &&
                            _sourceFilter == null,
                        onSelected: (_) => setState(() {
                          _filter = null;
                          _filterOutOfRange = false;
                          _sourceFilter = null;
                        }),
                      ),
                      const SizedBox(width: 6),
                      for (final category in RecordCategory.values) ...[
                        FilterChip(
                          label: Text(categoryLabel(category)),
                          selected: _filter == category,
                          onSelected: (_) => setState(() => _filter = category),
                        ),
                        const SizedBox(width: 6),
                      ],
                      FilterChip(
                        key: const ValueKey('records-out-of-range-filter'),
                        avatar: Icon(
                          Icons.warning_amber_rounded,
                          size: 16,
                          color: _filterOutOfRange
                              ? Theme.of(context).colorScheme.onErrorContainer
                              : Theme.of(context).colorScheme.error,
                        ),
                        label: const Text('Out of range only'),
                        selected: _filterOutOfRange,
                        selectedColor: Theme.of(
                          context,
                        ).colorScheme.errorContainer,
                        onSelected: (selected) =>
                            setState(() => _filterOutOfRange = selected),
                      ),
                      if (availableSources.length > 1) ...[
                        const SizedBox(width: 6),
                        for (final src in availableSources) ...[
                          FilterChip(
                            label: Text('Source: $src'),
                            selected: _sourceFilter == src,
                            onSelected: (_) => setState(() {
                              _sourceFilter = _sourceFilter == src ? null : src;
                            }),
                          ),
                          const SizedBox(width: 6),
                        ],
                      ],
                    ],
                  ),
                ),
                if (hasActiveFilter && filtered.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    children: [
                      Text(
                        'Showing ${filtered.length} of ${widget.records.length} records',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                            _filter = null;
                            _filterOutOfRange = false;
                            _sourceFilter = null;
                            _selectedDateRange = null;
                          });
                        },
                        child: const Text('Reset filters'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        if (filtered.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 28),
              child: widget.records.isEmpty
                  ? const QuietEmptyState(
                      icon: Icons.manage_search,
                      title: 'No records in this view',
                      message:
                          'Connect Apple Health, Health Connect, or a FHIR-enabled provider portal to import records.',
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const QuietEmptyState(
                          icon: Icons.manage_search,
                          title: 'No matching records',
                          message:
                              'Try another search term, category, or date range.',
                        ),
                        TextButton.icon(
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                              _filter = null;
                              _filterOutOfRange = false;
                              _sourceFilter = null;
                              _selectedDateRange = null;
                            });
                          },
                          icon: const Icon(Icons.filter_alt_off_outlined),
                          label: const Text(
                            'Clear search, filters, and date range',
                          ),
                        ),
                      ],
                    ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 28),
            sliver: SliverList.builder(
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final current = filtered[index];
                var isNewSection = false;
                var sectionTitle = '';

                if (_sortOrder == RecordSortOrder.newestFirst ||
                    _sortOrder == RecordSortOrder.oldestFirst) {
                  final curDate = current.recordedAt.toLocal();
                  if (index == 0) {
                    isNewSection = true;
                  } else {
                    final prevDate = filtered[index - 1].recordedAt.toLocal();
                    if (curDate.year != prevDate.year ||
                        curDate.month != prevDate.month) {
                      isNewSection = true;
                    }
                  }
                  if (isNewSection) {
                    sectionTitle = formatSectionMonthYear(curDate);
                  }
                } else {
                  final curLetter = current.name.isNotEmpty
                      ? current.name[0].toUpperCase()
                      : '#';
                  if (index == 0) {
                    isNewSection = true;
                  } else {
                    final prevLetter = filtered[index - 1].name.isNotEmpty
                        ? filtered[index - 1].name[0].toUpperCase()
                        : '#';
                    if (curLetter != prevLetter) {
                      isNewSection = true;
                    }
                  }
                  if (isNewSection) {
                    sectionTitle = curLetter;
                  }
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isNewSection)
                      DateSectionHeader(
                        title: sectionTitle,
                        isFirst: index == 0,
                      ),
                    RecordRow(
                      key: ValueKey(filtered[index].id),
                      record: filtered[index],
                      isLast: index == filtered.length - 1,
                      onTap: () {
                        if (widget.onRecordTap != null) {
                          widget.onRecordTap!(filtered[index]);
                        } else {
                          _showRecordDetails(filtered[index]);
                        }
                      },
                    ),
                  ],
                );
              },
            ),
          ),
      ],
    );

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: widget.onRefresh != null
            ? RefreshIndicator(onRefresh: widget.onRefresh!, child: scrollView)
            : scrollView,
      ),
    );
  }

  void _applyDaysPreset(int days) {
    final now = DateTime.now();
    final end = DateUtils.dateOnly(now);
    final start = end.subtract(Duration(days: days));
    setState(() {
      _selectedDateRange = DateTimeRange(start: start, end: end);
    });
  }

  bool _isPresetSelected(int days) {
    if (_selectedDateRange == null) return false;
    final now = DateTime.now();
    final end = DateUtils.dateOnly(now);
    final start = end.subtract(Duration(days: days));
    return DateUtils.isSameDay(_selectedDateRange!.start, start) &&
        DateUtils.isSameDay(_selectedDateRange!.end, end);
  }

  String _dateRangeLabel(BuildContext context) {
    final range = _selectedDateRange;
    if (range == null) return 'Choose date range';
    final localizations = MaterialLocalizations.of(context);
    final start = localizations.formatMediumDate(range.start);
    if (DateUtils.isSameDay(range.start, range.end)) return start;
    return '$start – ${localizations.formatMediumDate(range.end)}';
  }

  VoidCallback? _stepDateRange(List<DateTime> availableDates, int direction) {
    final range = _selectedDateRange;
    if (range == null || availableDates.length < 2) return null;
    final duration = range.end.difference(range.start);
    final target = direction < 0
        ? availableDates.firstWhere(
            (date) => date.isBefore(range.start),
            orElse: () => range.start,
          )
        : availableDates.firstWhere(
            (date) => date.isAfter(range.end),
            orElse: () => range.end,
          );
    if (DateUtils.isSameDay(target, direction < 0 ? range.start : range.end)) {
      return null;
    }
    final newStart = direction < 0 ? target : target.subtract(duration);
    final newEnd = direction < 0 ? target.add(duration) : target;
    return () => setState(
      () => _selectedDateRange = DateTimeRange(start: newStart, end: newEnd),
    );
  }

  Future<void> _chooseDateRange(List<DateTime> availableDates) async {
    DateTimeRange? validInitialRange = _selectedDateRange;
    if (validInitialRange != null) {
      if (validInitialRange.start.isBefore(availableDates.last) ||
          validInitialRange.start.isAfter(availableDates.first) ||
          validInitialRange.end.isBefore(availableDates.last) ||
          validInitialRange.end.isAfter(availableDates.first)) {
        validInitialRange = null;
      }
    }
    final selectedRange = await showDateRangePicker(
      context: context,
      initialDateRange: validInitialRange,
      firstDate: availableDates.last,
      lastDate: availableDates.first,
      helpText: 'Choose a date range',
      builder: (context, child) {
        final theme = Theme.of(context);
        return Theme(
          data: theme.copyWith(
            datePickerTheme: theme.datePickerTheme.copyWith(
              rangePickerHeaderHeadlineStyle:
                  MediaQuery.sizeOf(context).width < 420
                  ? theme.textTheme.titleMedium
                  : null,
            ),
          ),
          child: child!,
        );
      },
    );
    if (!mounted || selectedRange == null) return;
    setState(
      () => _selectedDateRange = DateTimeRange(
        start: DateUtils.dateOnly(selectedRange.start),
        end: DateUtils.dateOnly(selectedRange.end),
      ),
    );
  }

  Future<void> _showRecordDetails(HealthRecord record) async {
    final isNumeric = parseHealthRecordValue(record.value) != null;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => RecordDetailsSheet(
        record: record,
        isNumeric: isNumeric,
        onViewInTrends: isNumeric && widget.onViewInTrends != null
            ? () {
                Navigator.pop(sheetContext);
                widget.onViewInTrends!(record);
              }
            : null,
      ),
    );
  }
}

String formatSectionMonthYear(DateTime dt) {
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return '${months[dt.month - 1]} ${dt.year}';
}

class DatePresetChip extends StatelessWidget {
  const DatePresetChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Material(
      color: selected ? colors.primaryContainer : colors.surface,
      shape: StadiumBorder(
        side: BorderSide(
          color: selected
              ? colors.primary
              : colors.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: InkWell(
        onTap: onSelected,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected
                  ? colors.onPrimaryContainer
                  : colors.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class DateSectionHeader extends StatelessWidget {
  const DateSectionHeader({
    super.key,
    required this.title,
    this.isFirst = false,
  });

  final String title;
  final bool isFirst;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Padding(
      padding: EdgeInsets.only(top: isFirst ? 4 : 20, bottom: 8),
      child: Row(
        children: [
          Text(
            title,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: colors.primary,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Divider(
              color: colors.outlineVariant.withValues(alpha: 0.4),
              thickness: 1,
            ),
          ),
        ],
      ),
    );
  }
}
