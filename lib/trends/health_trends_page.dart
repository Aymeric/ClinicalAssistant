import 'package:flutter/material.dart';

import '../models/health_record.dart';
import '../ui/shared/record_widgets.dart';
import 'health_trend.dart';
import 'measurement_picker_sheet.dart';
import 'trend_chart_panel.dart';
import 'trend_indicators.dart';

/// Interactive clinical trends page displaying measurements over time with
/// category filtering, customizable time ranges, and moving average overlays.
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
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        _categoryChip('All', null, allSeries.length),
                        for (final category in RecordCategory.values)
                          if (allSeries.any(
                                (series) => series.category == category,
                              ) ||
                              _category == category)
                            _categoryChip(
                              categoryLabel(category),
                              category,
                              allSeries
                                  .where(
                                    (series) => series.category == category,
                                  )
                                  .length,
                            ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    MeasurementSelector(
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
                      const TrendEmptyState(
                        title: 'No numeric readings to chart',
                        message:
                            'Import lab results, vital measurements, or activity totals to explore their recorded values over time.',
                      )
                    else if (visibleSeries.isEmpty)
                      TrendEmptyState(
                        title:
                            'No ${categoryLabel(_category!).toLowerCase()} with numeric readings',
                        message:
                            'Choose another record type or import more readings.',
                      )
                    else if (orderedPoints.isEmpty)
                      TrendEmptyState(
                        title: 'No readings in this time range',
                        message:
                            'Try a longer range to include earlier measurements.',
                        action: TextButton(
                          onPressed: () =>
                              setState(() => _range = _TrendRange.all),
                          child: const Text('Show all time'),
                        ),
                      )
                    else ...[
                      SelectedReadingHeading(
                        series: selectedSeries!,
                        summary: summary!,
                      ),
                      const SizedBox(height: 14),
                      TrendChartPanel(
                        points: orderedPoints,
                        showMovingAverage: _showMovingAverage,
                        onMovingAverageChanged: (value) =>
                            setState(() => _showMovingAverage = value),
                        referenceBand: selectedSeries.referenceBand,
                        secondaryPoints: selectedSeries.hasSecondarySeries
                            ? pointsWithinRange(
                                selectedSeries.secondaryPoints,
                                now: DateTime.now(),
                                days: _range.days,
                              )
                            : const [],
                        primaryName: selectedSeries.hasSecondarySeries
                            ? 'Systolic'
                            : null,
                        secondaryName: selectedSeries.secondaryName,
                        onRecordTap: widget.onRecordTap,
                      ),
                      const SizedBox(height: 16),
                      TrendIndicators(
                        summary: summary,
                        count: orderedPoints.length,
                      ),
                      const SizedBox(height: 24),
                      RecentTrendReadings(
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
      builder: (context) => MeasurementPickerSheet(
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

enum _TrendRange {
  days30('30 days', 30),
  days90('90 days', 90),
  year('1 year', 365),
  all('All time', null);

  const _TrendRange(this.label, this.days);

  final String label;
  final int? days;
}
