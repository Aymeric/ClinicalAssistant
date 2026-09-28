import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/health_record.dart';
import 'health_trend.dart';

class HealthTrendsPage extends StatefulWidget {
  const HealthTrendsPage({
    super.key,
    required this.records,
    this.loading = false,
    this.initialSeriesId,
    this.onRecordTap,
  });

  final List<HealthRecord> records;
  final bool loading;
  final String? initialSeriesId;
  final ValueChanged<HealthRecord>? onRecordTap;

  @override
  State<HealthTrendsPage> createState() => _HealthTrendsPageState();
}

class _HealthTrendsPageState extends State<HealthTrendsPage> {
  RecordCategory? _category;
  _TrendRange _range = _TrendRange.all;
  String? _selectedSeriesId;
  bool _showMovingAverage = false;

  @override
  void initState() {
    super.initState();
    _selectedSeriesId = widget.initialSeriesId;
  }

  @override
  void didUpdateWidget(covariant HealthTrendsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialSeriesId != null &&
        widget.initialSeriesId != oldWidget.initialSeriesId) {
      setState(() {
        _selectedSeriesId = widget.initialSeriesId;
        _category = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final allSeries = buildHealthTrendSeries(widget.records);
    final visibleSeries = _category == null
        ? allSeries
        : allSeries.where((series) => series.category == _category).toList();
    final selectedSeries = visibleSeries.cast<HealthTrendSeries?>().firstWhere(
      (series) => series?.id == _selectedSeriesId,
      orElse: () => visibleSeries.isEmpty ? null : visibleSeries.first,
    );
    final selectedPoints = selectedSeries == null
        ? const <HealthTrendPoint>[]
        : pointsWithinRange(
            selectedSeries.points,
            now: DateTime.now(),
            days: _range.days,
          );
    final orderedPoints = [...selectedPoints]
      ..sort((a, b) => a.record.recordedAt.compareTo(b.record.recordedAt));
    final summary = orderedPoints.isEmpty
        ? null
        : summarizeHealthTrend(orderedPoints);

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: CustomScrollView(
          key: const ValueKey('health-trends-page'),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Follow a reading over time.',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Recorded values are shown as collected, without clinical interpretation.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Record type',
                      style: Theme.of(context).textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        _categoryChip('All', null, allSeries.length),
                        for (final category in RecordCategory.values)
                          if (allSeries.any((series) => series.category == category) ||
                              _category == category)
                            _categoryChip(
                              _categoryLabel(category),
                              category,
                              allSeries
                                  .where((series) => series.category == category)
                                  .length,
                            ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _MeasurementSelector(
                      key: const ValueKey('trend-measurement-picker'),
                      selected: selectedSeries,
                      onPressed: visibleSeries.length < 2
                          ? null
                          : () => _chooseMeasurement(visibleSeries),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        for (final range in _TrendRange.values)
                          ChoiceChip(
                            key: ValueKey('trend-range-${range.name}'),
                            label: Text(range.label),
                            selected: _range == range,
                            onSelected: (_) => setState(() => _range = range),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    if (widget.loading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(36),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else if (allSeries.isEmpty)
                      const _TrendEmptyState(
                        title: 'No numeric readings to chart',
                        message: 'Import lab results, vital measurements, or activity totals to explore their recorded values over time.',
                      )
                    else if (visibleSeries.isEmpty)
                      _TrendEmptyState(
                        title:
                            'No ${_categoryLabel(_category!).toLowerCase()} with numeric readings',
                        message: 'Choose another record type or import more readings.',
                      )
                    else if (orderedPoints.isEmpty)
                      _TrendEmptyState(
                        title: 'No readings in this time range',
                        message: 'Try a longer range to include earlier measurements.',
                        action: TextButton(
                          onPressed: () =>
                              setState(() => _range = _TrendRange.all),
                          child: const Text('Show all time'),
                        ),
                      )
                    else ...[
                      _SelectedReadingHeading(
                        series: selectedSeries!,
                        summary: summary!,
                      ),
                      const SizedBox(height: 14),
                      _TrendChartPanel(
                        points: orderedPoints,
                        showMovingAverage: _showMovingAverage,
                        onMovingAverageChanged: (value) =>
                            setState(() => _showMovingAverage = value),
                        onRecordTap: widget.onRecordTap,
                      ),
                      const SizedBox(height: 16),
                      _TrendIndicators(
                        summary: summary,
                        count: orderedPoints.length,
                      ),
                      const SizedBox(height: 24),
                      _RecentTrendReadings(
                        points: orderedPoints,
                        onRecordTap: widget.onRecordTap,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _categoryChip(String label, RecordCategory? category, int count) {
    final selected = _category == category;
    return ChoiceChip(
      key: ValueKey('trend-category-${category?.name ?? 'all'}'),
      label: Text('$label ($count)'),
      selected: selected,
      onSelected: (_) => setState(() {
        _category = category;
        _selectedSeriesId = null;
        _showMovingAverage = false;
      }),
    );
  }

  Future<void> _chooseMeasurement(List<HealthTrendSeries> visibleSeries) async {
    final selectedId = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _MeasurementPickerSheet(
        series: visibleSeries,
        selectedSeriesId: _selectedSeriesId,
      ),
    );
    if (!mounted || selectedId == null) return;
    setState(() {
      _selectedSeriesId = selectedId;
      _showMovingAverage = false;
    });
  }
}

class _MeasurementSelector extends StatelessWidget {
  const _MeasurementSelector({
    super.key,
    required this.selected,
    required this.onPressed,
  });

  final HealthTrendSeries? selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final latest = selected?.points.last.record.displayValue;
    return Material(
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(14),
      ),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(
                Icons.search,
                color: onPressed == null
                    ? theme.colorScheme.onSurfaceVariant
                    : theme.colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Measurement',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      selected?.label ?? 'No measurements available',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (selected != null)
                      Text(
                        '${_categoryLabel(selected!.category)} · $latest · ${selected!.points.length} readings',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.expand_more,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MeasurementPickerSheet extends StatefulWidget {
  const _MeasurementPickerSheet({
    required this.series,
    required this.selectedSeriesId,
  });

  final List<HealthTrendSeries> series;
  final String? selectedSeriesId;

  @override
  State<_MeasurementPickerSheet> createState() =>
      _MeasurementPickerSheetState();
}

class _MeasurementPickerSheetState extends State<_MeasurementPickerSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final results = widget.series.where((series) {
      if (query.isEmpty) return true;
      return series.name.toLowerCase().contains(query) ||
          series.unit.toLowerCase().contains(query) ||
          _categoryLabel(series.category).toLowerCase().contains(query);
    }).toList();
    final media = MediaQuery.of(context);
    final availableHeight = media.size.height - media.viewInsets.bottom;
    final sheetHeight = math.min(availableHeight * 0.88, 720.0).toDouble();

    return SizedBox(
      key: const ValueKey('measurement-picker-sheet'),
      height: sheetHeight,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Choose a measurement',
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 14),
              TextField(
                key: const ValueKey('measurement-search'),
                controller: _searchController,
                textInputAction: TextInputAction.search,
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  hintText: 'Search name, category, or unit',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear measurement search',
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                          icon: const Icon(Icons.close),
                        ),
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: results.isEmpty
                    ? Center(
                        child: Text(
                          'No measurements match “$_query”.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      )
                    : ListView.separated(
                        key: const ValueKey('measurement-search-results'),
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        itemCount: results.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final series = results[index];
                          final selected = series.id == widget.selectedSeriesId;
                          return ListTile(
                            key: ValueKey('measurement-option-${series.id}'),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 4,
                            ),
                            title: Text(series.name),
                            subtitle: Text(
                              '${_categoryLabel(series.category)} · ${series.unit.isEmpty ? 'No unit' : series.unit} · ${series.points.length} readings',
                            ),
                            trailing: selected
                                ? Icon(
                                    Icons.check,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary,
                                  )
                                : null,
                            onTap: () => Navigator.of(context).pop(series.id),
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
}

class _SelectedReadingHeading extends StatelessWidget {
  const _SelectedReadingHeading({required this.series, required this.summary});

  final HealthTrendSeries series;
  final HealthTrendSummary summary;

  @override
  Widget build(BuildContext context) {
    final latest = summary.latest.record;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          series.name,
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              latest.displayValue,
              style: Theme.of(context).textTheme.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.7),
            ),
            Text(
              'Latest · ${MaterialLocalizations.of(context).formatMediumDate(latest.recordedAt.toLocal())}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        Text(
          '${_categoryLabel(series.category)} · ${latest.source}',
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _TrendChartPanel extends StatefulWidget {
  const _TrendChartPanel({
    required this.points,
    required this.showMovingAverage,
    required this.onMovingAverageChanged,
    this.onRecordTap,
  });

  final List<HealthTrendPoint> points;
  final bool showMovingAverage;
  final ValueChanged<bool> onMovingAverageChanged;
  final ValueChanged<HealthRecord>? onRecordTap;

  @override
  State<_TrendChartPanel> createState() => _TrendChartPanelState();
}

class _TrendChartPanelState extends State<_TrendChartPanel> {
  int? _inspectedIndex;

  @override
  void didUpdateWidget(covariant _TrendChartPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_inspectedIndex != null &&
        (_inspectedIndex! >= widget.points.length ||
            oldWidget.points != widget.points)) {
      _inspectedIndex = null;
    }
  }

  void _inspectAt(double localX, double totalWidth) {
    const left = 58.0;
    const right = 10.0;
    final plotWidth = totalWidth - left - right;
    if (plotWidth <= 0 || widget.points.isEmpty) return;
    final fraction = ((localX - left) / plotWidth).clamp(0.0, 1.0);
    final index = (fraction * (widget.points.length - 1)).round();
    if (index != _inspectedIndex) {
      setState(() => _inspectedIndex = index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final points = widget.points;
    final showMovingAverage = widget.showMovingAverage;
    final onMovingAverageChanged = widget.onMovingAverageChanged;
    final chartIndexes = sampleHealthTrendIndexes(points);
    final chartPoints = [for (final index in chartIndexes) points[index]];
    final referenceMarks = buildHealthTrendReferenceMarks(
      points,
      unit: points.first.record.unit,
    );
    final suppliedRangeCount = points
        .where((point) => point.record.referenceRange != null)
        .length;
    final unplottedRangeCount = suppliedRangeCount - referenceMarks.length;
    final averages = showMovingAverage
        ? _sampleValues(movingAverageValues(points))
        : const <double>[];
    final firstDate = MaterialLocalizations.of(context)
        .formatShortDate(points.first.record.recordedAt.toLocal());
    final lastDate = MaterialLocalizations.of(context)
        .formatShortDate(points.last.record.recordedAt.toLocal());

    final inspectedPoint = _inspectedIndex != null &&
            _inspectedIndex! < points.length
        ? points[_inspectedIndex!]
        : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Recorded values',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                FilterChip(
                  key: const ValueKey('trend-moving-average'),
                  label: const Text('3-reading average'),
                  selected: showMovingAverage,
                  onSelected: points.length < 3 ? null : onMovingAverageChanged,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Semantics(
              label: _chartDescription(
                points,
                showMovingAverage,
                referenceMarks.length,
              ),
              child: ExcludeSemantics(
                child: SizedBox(
                  height: 214,
                  width: double.infinity,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return GestureDetector(
                        key: const ValueKey('trend-chart-canvas'),
                        behavior: HitTestBehavior.opaque,
                        onTapDown: (details) => _inspectAt(
                          details.localPosition.dx,
                          constraints.maxWidth,
                        ),
                        onTapUp: (details) => _inspectAt(
                          details.localPosition.dx,
                          constraints.maxWidth,
                        ),
                        onHorizontalDragStart: (details) => _inspectAt(
                          details.localPosition.dx,
                          constraints.maxWidth,
                        ),
                        onHorizontalDragUpdate: (details) => _inspectAt(
                          details.localPosition.dx,
                          constraints.maxWidth,
                        ),
                        child: CustomPaint(
                          painter: _TrendChartPainter(
                            points: chartPoints,
                            pointIndexes: chartIndexes,
                            referenceMarks: referenceMarks,
                            averages: averages,
                            totalPoints: points.length,
                            inspectedIndex: _inspectedIndex,
                            inspectedPoint: inspectedPoint,
                            color: Theme.of(context).colorScheme.primary,
                            averageColor:
                                Theme.of(context).colorScheme.secondary,
                            referenceColor:
                                Theme.of(context).colorScheme.tertiary,
                            gridColor:
                                Theme.of(context).colorScheme.outlineVariant,
                            textColor:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            if (inspectedPoint != null) ...[
              const SizedBox(height: 10),
              _ChartInspectionBanner(
                point: inspectedPoint,
                onDismiss: () => setState(() => _inspectedIndex = null),
                onViewDetails: widget.onRecordTap != null
                    ? () => widget.onRecordTap!(inspectedPoint.record)
                    : null,
              ),
            ],
            const SizedBox(height: 4),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              runSpacing: 2,
              children: [
                Text(firstDate, style: Theme.of(context).textTheme.labelSmall),
                Text(lastDate, style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _chartNote(
                referenceMarks: referenceMarks.length,
                unplottedRanges: unplottedRangeCount,
              ),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            if (showMovingAverage || referenceMarks.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (showMovingAverage) ...[
                    _LegendDot(color: Theme.of(context).colorScheme.primary),
                    Text(
                      'Reading',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    const SizedBox(width: 8),
                    _LegendDot(color: Theme.of(context).colorScheme.secondary),
                    Text(
                      '3-reading average',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                  if (referenceMarks.isNotEmpty) ...[
                    if (showMovingAverage) const SizedBox(width: 8),
                    _ReferenceRangeLegend(
                      color: Theme.of(context).colorScheme.tertiary,
                    ),
                    Text(
                      'Source reference ranges',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  static List<double> _sampleValues(List<double> values) {
    if (values.length <= 120) return values;
    return [
      for (var index = 0; index < 120; index++)
        values[(index * (values.length - 1) / 119).round()],
    ];
  }

  static String _chartDescription(
    List<HealthTrendPoint> points,
    bool showMovingAverage,
    int referenceRangeCount,
  ) {
    final trend = summarizeHealthTrend(points);
    final latest = trend.latest.record;
    return 'Chart with ${points.length} recorded values. '
        'Latest is ${latest.displayValue} on '
        '${latest.recordedAt.toLocal().toString().split(' ').first}. '
        '${showMovingAverage ? 'Includes a three-reading moving average. ' : ''}'
        '${referenceRangeCount == 0 ? '' : 'Shows source reference ranges for $referenceRangeCount readings.'}';
  }

  static String _chartNote({
    required int referenceMarks,
    required int unplottedRanges,
  }) {
    if (referenceMarks == 0 && unplottedRanges == 0) {
      return 'Each point is one numeric reading. Values and units are kept as imported.';
    }
    if (referenceMarks == 0) {
      return 'Reference-range text is not numeric or uses other units; see the source range with each reading below.';
    }
    return unplottedRanges == 0
        ? 'Each point is one numeric reading. Range markers show limits reported by the source for that reading.'
        : 'Range markers show numeric limits reported by the source. Other range text appears with each reading below.';
  }
}

class _ChartInspectionBanner extends StatelessWidget {
  const _ChartInspectionBanner({
    required this.point,
    required this.onDismiss,
    this.onViewDetails,
  });

  final HealthTrendPoint point;
  final VoidCallback onDismiss;
  final VoidCallback? onViewDetails;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final record = point.record;
    final localizations = MaterialLocalizations.of(context);
    final dateStr = localizations.formatMediumDate(record.recordedAt.toLocal());
    final localTime = record.recordedAt.toLocal();
    final hour = localTime.hour % 12 == 0 ? 12 : localTime.hour % 12;
    final minute = localTime.minute.toString().padLeft(2, '0');
    final period = localTime.hour < 12 ? 'AM' : 'PM';
    final timeStr = '$hour:$minute $period';

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.25),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onViewDetails,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
            child: Row(
              children: [
                Icon(
                  Icons.touch_app_outlined,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${record.displayValue} · $dateStr at $timeStr',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Source: ${record.source}${record.referenceRange != null ? ' · Ref: ${record.referenceRange}' : ''}${onViewDetails != null ? ' · Tap for details' : ''}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onViewDetails != null)
                  IconButton(
                    key: const ValueKey('trend-inspect-view-details'),
                    icon: const Icon(Icons.open_in_new, size: 18),
                    tooltip: 'View details',
                    onPressed: onViewDetails,
                  ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  tooltip: 'Dismiss',
                  onPressed: onDismiss,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TrendChartPainter extends CustomPainter {
  const _TrendChartPainter({
    required this.points,
    required this.pointIndexes,
    required this.referenceMarks,
    required this.averages,
    required this.totalPoints,
    this.inspectedIndex,
    this.inspectedPoint,
    required this.color,
    required this.averageColor,
    required this.referenceColor,
    required this.gridColor,
    required this.textColor,
  });

  final List<HealthTrendPoint> points;
  final List<int> pointIndexes;
  final List<HealthTrendReferenceMark> referenceMarks;
  final List<double> averages;
  final int totalPoints;
  final int? inspectedIndex;
  final HealthTrendPoint? inspectedPoint;
  final Color color;
  final Color averageColor;
  final Color referenceColor;
  final Color gridColor;
  final Color textColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty || size.isEmpty) return;
    const left = 58.0;
    const right = 10.0;
    const top = 12.0;
    const bottom = 8.0;
    final plot = Rect.fromLTRB(
      left,
      top,
      size.width - right < left + 1 ? left + 1 : size.width - right,
      size.height - bottom < top + 1 ? top + 1 : size.height - bottom,
    );
    final values = [
      ...points.map((point) => point.value),
      ...averages,
      for (final mark in referenceMarks) ?mark.range.lowerBound,
      for (final mark in referenceMarks) ?mark.range.upperBound,
    ];
    var minimum = values.reduce((a, b) => a < b ? a : b);
    var maximum = values.reduce((a, b) => a > b ? a : b);
    final padding = maximum == minimum
        ? math.max(maximum.abs() * 0.06, 0.5)
        : (maximum - minimum) * 0.12;
    minimum -= padding;
    maximum += padding;

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    final labelStyle = TextStyle(color: textColor, fontSize: 11);
    for (var index = 0; index <= 3; index++) {
      final fraction = index / 3;
      final y = plot.top + plot.height * fraction;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), gridPaint);
      final value = maximum - (maximum - minimum) * fraction;
      final textPainter = TextPainter(
        text: TextSpan(text: _formatTrendValue(value), style: labelStyle),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout(maxWidth: left - 8);
      textPainter.paint(canvas, Offset(0, y - textPainter.height / 2));
    }

    Offset pointOffset(double index, double value) {
      final x =
          plot.left +
          (totalPoints <= 1 ? 0.5 : index / (totalPoints - 1)) * plot.width;
      final y =
          plot.bottom - (value - minimum) / (maximum - minimum) * plot.height;
      return Offset(x, y);
    }

    final referenceLinePaint = Paint()
      ..color = referenceColor
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    final referenceFillPaint = Paint()
      ..color = referenceColor.withValues(alpha: 0.14)
      ..style = PaintingStyle.fill;
    for (final mark in referenceMarks) {
      final x = pointOffset(mark.index.toDouble(), minimum).dx;
      final lower = mark.range.lowerBound;
      final upper = mark.range.upperBound;
      if (lower != null && upper != null) {
        final lowerY = pointOffset(mark.index.toDouble(), lower).dy;
        final upperY = pointOffset(mark.index.toDouble(), upper).dy;
        final top = math.min(lowerY, upperY);
        final bottom = math.max(lowerY, upperY);
        canvas.drawRect(
          Rect.fromLTRB(x - 3, top, x + 3, math.max(top + 2, bottom)),
          referenceFillPaint,
        );
        canvas.drawLine(Offset(x, top), Offset(x, bottom), referenceLinePaint);
        canvas.drawLine(
          Offset(x - 4, lowerY),
          Offset(x + 4, lowerY),
          referenceLinePaint,
        );
        canvas.drawLine(
          Offset(x - 4, upperY),
          Offset(x + 4, upperY),
          referenceLinePaint,
        );
      } else {
        final bound = lower ?? upper!;
        final y = pointOffset(mark.index.toDouble(), bound).dy;
        canvas.drawLine(Offset(x - 5, y), Offset(x + 5, y), referenceLinePaint);
      }
    }

    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final line = Path();
    for (var index = 0; index < points.length; index++) {
      final offset = pointOffset(
        pointIndexes[index].toDouble(),
        points[index].value,
      );
      if (index == 0) {
        line.moveTo(offset.dx, offset.dy);
      } else {
        line.lineTo(offset.dx, offset.dy);
      }
    }
    if (points.length == 1) {
      canvas.drawCircle(
        pointOffset(pointIndexes.single.toDouble(), points.single.value),
        4.5,
        Paint()..color = color,
      );
    } else {
      canvas.drawPath(line, linePaint);
      final markerPaint = Paint()..color = color;
      for (var index = 0; index < points.length; index++) {
        if (index % 8 == 0 || index == points.length - 1) {
          final offset = pointOffset(
            pointIndexes[index].toDouble(),
            points[index].value,
          );
          canvas.drawCircle(offset, 3.2, markerPaint);
        }
      }
    }

    if (averages.isNotEmpty && totalPoints >= 3) {
      final averageLine = Path();
      for (var index = 0; index < averages.length; index++) {
        final averageIndex =
            2.0 +
            (averages.length == 1
                ? 0.0
                : index * (totalPoints - 3) / (averages.length - 1));
        final offset = pointOffset(averageIndex, averages[index]);
        if (index == 0) {
          averageLine.moveTo(offset.dx, offset.dy);
        } else {
          averageLine.lineTo(offset.dx, offset.dy);
        }
      }
      canvas.drawPath(
        averageLine,
        Paint()
          ..color = averageColor
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    if (inspectedIndex != null && inspectedPoint != null) {
      final inspectedOffset = pointOffset(
        inspectedIndex!.toDouble(),
        inspectedPoint!.value,
      );
      final guidePaint = Paint()
        ..color = color.withValues(alpha: 0.45)
        ..strokeWidth = 1.2;
      canvas.drawLine(
        Offset(inspectedOffset.dx, plot.top),
        Offset(inspectedOffset.dx, plot.bottom),
        guidePaint,
      );
      canvas.drawCircle(
        inspectedOffset,
        8.0,
        Paint()..color = color.withValues(alpha: 0.22),
      );
      canvas.drawCircle(
        inspectedOffset,
        4.5,
        Paint()..color = color,
      );
      canvas.drawCircle(
        inspectedOffset,
        4.5,
        Paint()
          ..color = Colors.white
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TrendChartPainter oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.pointIndexes != pointIndexes ||
      oldDelegate.referenceMarks != referenceMarks ||
      oldDelegate.averages != averages ||
      oldDelegate.totalPoints != totalPoints ||
      oldDelegate.inspectedIndex != inspectedIndex ||
      oldDelegate.inspectedPoint != inspectedPoint ||
      oldDelegate.color != color ||
      oldDelegate.averageColor != averageColor ||
      oldDelegate.referenceColor != referenceColor ||
      oldDelegate.gridColor != gridColor ||
      oldDelegate.textColor != textColor;
}

class _TrendIndicators extends StatelessWidget {
  const _TrendIndicators({required this.summary, required this.count});

  final HealthTrendSummary summary;
  final int count;

  @override
  Widget build(BuildContext context) {
    final change = summary.change;
    final changeValue = change == null
        ? '—'
        : summary.percentChange == null
        ? '${change >= 0 ? '+' : ''}${_formatTrendValue(change)}'
        : '${change >= 0 ? '+' : ''}${summary.percentChange!.toStringAsFixed(1)}%';
    final changeLabel = summary.previous == null
        ? 'Need another reading'
        : 'Since previous reading';
    final fields = [
      ('Change', changeValue, changeLabel),
      ('Average', _formatTrendValue(summary.average), 'In this range'),
      (
        'Observed range',
        '${_formatTrendValue(summary.minimum)}–${_formatTrendValue(summary.maximum)}',
        'Lowest to highest',
      ),
      ('Readings', '$count', 'In this range'),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 500 ? 2 : 4;
        const spacing = 6.0;
        final width = (constraints.maxWidth - (columns - 1) * spacing) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (var index = 0; index < fields.length; index++)
              Container(
                width: width,
                constraints: const BoxConstraints(minHeight: 84),
                padding: const EdgeInsets.fromLTRB(14, 12, 10, 10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Theme.of(context)
                        .colorScheme
                        .outlineVariant
                        .withValues(alpha: 0.6),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            fields[index].$1,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .labelMedium
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                        if (index == 0 && change != null) ...[
                          const SizedBox(width: 4),
                          Icon(
                            change > 0
                                ? Icons.trending_up
                                : change < 0
                                ? Icons.trending_down
                                : Icons.trending_flat,
                            size: 16,
                            color: change > 0
                                ? Theme.of(context).colorScheme.primary
                                : change < 0
                                ? Theme.of(context).colorScheme.secondary
                                : Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      fields[index].$2,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      fields[index].$3,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _RecentTrendReadings extends StatelessWidget {
  const _RecentTrendReadings({
    required this.points,
    this.onRecordTap,
  });

  final List<HealthTrendPoint> points;
  final ValueChanged<HealthRecord>? onRecordTap;

  @override
  Widget build(BuildContext context) {
    final recent = points.reversed.take(5).toList();
    final unit = points.isNotEmpty ? points.first.record.unit : '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Latest readings',
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        for (final point in recent) ...[
          Builder(
            builder: (context) {
              final parsedRange = parseHealthReferenceRange(
                point.record.referenceRange,
                expectedUnit: unit,
              );
              final status = parsedRange?.evaluate(point.value);
              return ListTile(
                key: ValueKey('trend-record-${point.record.id}'),
                contentPadding: EdgeInsets.zero,
                onTap: onRecordTap != null
                    ? () => onRecordTap!(point.record)
                    : null,
                title: Row(
                  children: [
                    Expanded(child: Text(point.record.displayValue)),
                    if (status != null &&
                        status != HealthReferenceStatus.unspecified)
                      _ReferenceStatusBadge(status: status),
                  ],
                ),
                subtitle: Text(
                  [
                    '${MaterialLocalizations.of(context).formatMediumDate(point.record.recordedAt.toLocal())} · ${point.record.source}',
                    if (point.record.referenceRange case final range?)
                      'Source reference range: $range',
                  ].join('\n'),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (point.record.status != null)
                      Text(
                        point.record.status!,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    if (onRecordTap != null)
                      const Icon(Icons.chevron_right, size: 18),
                  ],
                ),
              );
            },
          ),
        ],
        if (points.length > recent.length)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Showing the latest ${recent.length} of ${points.length} readings in this range.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}

class _TrendEmptyState extends StatelessWidget {
  const _TrendEmptyState({
    required this.title,
    required this.message,
    this.action,
  });

  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          if (action != null) ...[const SizedBox(height: 8), action!],
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 9,
    height: 9,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

class _ReferenceRangeLegend extends StatelessWidget {
  const _ReferenceRangeLegend({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 12,
    height: 14,
    child: CustomPaint(painter: _ReferenceRangeLegendPainter(color)),
  );
}

class _ReferenceRangeLegendPainter extends CustomPainter {
  const _ReferenceRangeLegendPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5;
    final center = size.width / 2;
    canvas.drawLine(Offset(center, 1), Offset(center, size.height - 1), paint);
    canvas.drawLine(Offset(1, 1), Offset(size.width - 1, 1), paint);
    canvas.drawLine(
      Offset(1, size.height - 1),
      Offset(size.width - 1, size.height - 1),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _ReferenceRangeLegendPainter oldDelegate) =>
      oldDelegate.color != color;
}

enum _TrendRange {
  days30('30 days', 30),
  days90('90 days', 90),
  year('1 year', 365),
  all('All time', null);

  const _TrendRange(this.label, this.days);

  final String label;
  final int? days;
}

String _categoryLabel(RecordCategory category) => switch (category) {
  RecordCategory.lab => 'Labs',
  RecordCategory.vital => 'Vitals',
  RecordCategory.activity => 'Activities',
  RecordCategory.sleep => 'Sleep',
  RecordCategory.nutrition => 'Nutrition',
  RecordCategory.cycleTracking => 'Cycle tracking',
  RecordCategory.medication => 'Medications',
  RecordCategory.condition => 'Conditions',
  RecordCategory.allergy => 'Allergies',
  RecordCategory.immunization => 'Immunizations',
};

String _formatTrendValue(double value) => formatSensibleNumber(value);

class _ReferenceStatusBadge extends StatelessWidget {
  const _ReferenceStatusBadge({required this.status});

  final HealthReferenceStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (color, label) = switch (status) {
      HealthReferenceStatus.within => (colors.primary, 'Within range'),
      HealthReferenceStatus.above => (Colors.amber.shade800, 'Above range'),
      HealthReferenceStatus.below => (colors.tertiary, 'Below range'),
      HealthReferenceStatus.unspecified => (colors.outline, 'Unspecified'),
    };

    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
