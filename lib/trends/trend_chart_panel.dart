import 'package:flutter/material.dart';

import '../models/health_record.dart';
import 'health_trend.dart';
import 'trend_chart_painter.dart';

/// Interactive chart panel rendering time-series measurements with inspection support,
/// optional moving average overlay, and source reference ranges.
class TrendChartPanel extends StatefulWidget {
  const TrendChartPanel({
    super.key,
    required this.points,
    required this.showMovingAverage,
    required this.onMovingAverageChanged,
    this.referenceBand,
    this.secondaryPoints = const [],
    this.primaryName,
    this.secondaryName,
    this.onRecordTap,
  });

  final List<HealthTrendPoint> points;
  final bool showMovingAverage;
  final ValueChanged<bool> onMovingAverageChanged;
  final HealthReferenceRange? referenceBand;
  final List<HealthTrendPoint> secondaryPoints;
  final String? primaryName;
  final String? secondaryName;
  final ValueChanged<HealthRecord>? onRecordTap;

  @override
  State<TrendChartPanel> createState() => _TrendChartPanelState();
}

class _TrendChartPanelState extends State<TrendChartPanel> {
  int? _inspectedIndex;

  @override
  void didUpdateWidget(covariant TrendChartPanel oldWidget) {
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
    final secondaryPoints = widget.secondaryPoints;
    final hasSecondary = secondaryPoints.isNotEmpty;
    final secondaryChartIndexes = hasSecondary
        ? sampleHealthTrendIndexes(secondaryPoints)
        : null;
    final secondaryChartPoints = hasSecondary
        ? [for (final index in secondaryChartIndexes!) secondaryPoints[index]]
        : null;
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
    final firstDate = MaterialLocalizations.of(
      context,
    ).formatShortDate(points.first.record.recordedAt.toLocal());
    final lastDate = MaterialLocalizations.of(
      context,
    ).formatShortDate(points.last.record.recordedAt.toLocal());

    final inspectedPoint =
        _inspectedIndex != null && _inspectedIndex! < points.length
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
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
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
                          painter: TrendChartPainter(
                            points: chartPoints,
                            pointIndexes: chartIndexes,
                            referenceMarks: referenceMarks,
                            referenceBand: widget.referenceBand,
                            secondaryPoints: secondaryChartPoints,
                            secondaryIndexes: secondaryChartIndexes,
                            secondaryColor: Theme.of(
                              context,
                            ).colorScheme.tertiary,
                            averages: averages,
                            totalPoints: points.length,
                            inspectedIndex: _inspectedIndex,
                            inspectedPoint: inspectedPoint,
                            color: Theme.of(context).colorScheme.primary,
                            averageColor: Theme.of(
                              context,
                            ).colorScheme.secondary,
                            referenceColor: Theme.of(
                              context,
                            ).colorScheme.tertiary,
                            gridColor: Theme.of(
                              context,
                            ).colorScheme.outlineVariant,
                            textColor: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
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
              ChartInspectionBanner(
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
            if (showMovingAverage ||
                referenceMarks.isNotEmpty ||
                widget.referenceBand != null ||
                hasSecondary) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (hasSecondary) ...[
                    LegendDot(color: Theme.of(context).colorScheme.primary),
                    Text(
                      widget.primaryName ?? 'Systolic',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    const SizedBox(width: 8),
                    LegendDot(color: Theme.of(context).colorScheme.tertiary),
                    Text(
                      widget.secondaryName ?? 'Diastolic',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (showMovingAverage) ...[
                    LegendDot(color: Theme.of(context).colorScheme.primary),
                    Text(
                      'Reading',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    const SizedBox(width: 8),
                    LegendDot(color: Theme.of(context).colorScheme.secondary),
                    Text(
                      '3-reading average',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                  if (widget.referenceBand != null) ...[
                    Container(
                      width: 12,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.tertiary.withValues(alpha: 0.25),
                        border: Border.all(
                          color: Theme.of(
                            context,
                          ).colorScheme.tertiary.withValues(alpha: 0.6),
                          width: 0.8,
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Text(
                      'Target band (${widget.referenceBand!.sourceText})',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (referenceMarks.isNotEmpty) ...[
                    if (showMovingAverage) const SizedBox(width: 8),
                    ReferenceRangeLegend(
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

/// Banner showing detail of the point currently being inspected via touch or drag.
class ChartInspectionBanner extends StatelessWidget {
  const ChartInspectionBanner({
    super.key,
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
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.65,
        ),
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

/// Circular legend dot for chart annotations.
class LegendDot extends StatelessWidget {
  const LegendDot({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 9,
    height: 9,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

/// Legend symbol showing reference range markers.
class ReferenceRangeLegend extends StatelessWidget {
  const ReferenceRangeLegend({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 12,
    height: 14,
    child: CustomPaint(painter: ReferenceRangeLegendPainter(color)),
  );
}
