import 'package:flutter/material.dart';

import '../models/health_record.dart';
import '../ui/shared/record_widgets.dart';
import 'health_trend.dart';

/// Top heading displaying the selected measurement name, latest reading value, date, and source.
class SelectedReadingHeading extends StatelessWidget {
  const SelectedReadingHeading({
    super.key,
    required this.series,
    required this.summary,
  });

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
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              latest.displayValue,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.7,
              ),
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
          '${categoryLabel(series.category)} · ${latest.source}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Responsive grid of summary metrics: Change, Average, Observed Range, Readings count.
class TrendIndicators extends StatelessWidget {
  const TrendIndicators({
    super.key,
    required this.summary,
    required this.count,
  });

  final HealthTrendSummary summary;
  final int count;

  @override
  Widget build(BuildContext context) {
    final change = summary.change;
    final changeValue = change == null
        ? '—'
        : summary.percentChange == null
        ? '${change >= 0 ? '+' : ''}${formatSensibleNumber(change)}'
        : '${change >= 0 ? '+' : ''}${summary.percentChange!.toStringAsFixed(1)}%';
    final changeLabel = summary.previous == null
        ? 'Need another reading'
        : 'Since previous reading';
    final fields = [
      ('Change', changeValue, changeLabel),
      ('Average', formatSensibleNumber(summary.average), 'In this range'),
      (
        'Observed range',
        '${formatSensibleNumber(summary.minimum)}–${formatSensibleNumber(summary.maximum)}',
        'Lowest to highest',
      ),
      ('Readings', '$count', 'In this range'),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 500 ? 2 : 4;
        const spacing = 6.0;
        final width =
            (constraints.maxWidth - (columns - 1) * spacing) / columns;
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
                    color: Theme.of(
                      context,
                    ).colorScheme.outlineVariant.withValues(alpha: 0.6),
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
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
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
                                : Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      fields[index].$2,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      fields[index].$3,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
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

/// List of recent chronological readings for the active measurement series.
class RecentTrendReadings extends StatelessWidget {
  const RecentTrendReadings({
    super.key,
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
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
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
                      ReferenceStatusBadge(status: status),
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
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
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

/// Placeholder container when no measurements or series data are available.
class TrendEmptyState extends StatelessWidget {
  const TrendEmptyState({
    super.key,
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
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
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

/// Badge indicating whether a reading falls within, above, or below reference range.
class ReferenceStatusBadge extends StatelessWidget {
  const ReferenceStatusBadge({super.key, required this.status});

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
