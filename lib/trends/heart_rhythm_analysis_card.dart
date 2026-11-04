import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/health_record.dart';
import 'health_trend.dart';

/// Longitudinal cardiac rhythm and heart rate analysis summary.
/// Compares resting heart rate, walking average, and workout peak,
/// and aggregates Heart Rate Variability (HRV / SDNN) and irregular rhythm notifications.
class HeartRhythmAnalysisCard extends StatelessWidget {
  const HeartRhythmAnalysisCard({
    super.key,
    required this.allRecords,
    required this.selectedSeries,
    this.onRecordTap,
  });

  final List<HealthRecord> allRecords;
  final HealthTrendSeries selectedSeries;
  final ValueChanged<HealthRecord>? onRecordTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    // Filter relevant cardiac records
    final restingRecords = <HealthRecord>[];
    final walkingRecords = <HealthRecord>[];
    final generalHeartRateRecords = <HealthRecord>[];
    final hrvRecords = <HealthRecord>[];
    final irregularRhythmRecords = <HealthRecord>[];

    for (final r in allRecords) {
      final lowerName = r.name.toLowerCase();
      final code = r.code?.toLowerCase();

      if (lowerName.contains('resting heart rate') || code == '40443-4') {
        restingRecords.add(r);
      } else if (lowerName.contains('walking') &&
          lowerName.contains('heart rate')) {
        walkingRecords.add(r);
      } else if (lowerName.contains('heart rate variability') ||
          lowerName.contains('hrv') ||
          lowerName.contains('sdnn')) {
        hrvRecords.add(r);
      } else if (lowerName.contains('irregular') &&
          lowerName.contains('rhythm')) {
        irregularRhythmRecords.add(r);
      } else if (lowerName.contains('heart rate') || code == '8867-4') {
        generalHeartRateRecords.add(r);
      }
    }

    // Performance optimization: Replace repeated RegExp evaluation and intermediate list
    // allocations (`.map().whereType().toList()`, `[...a, ...b, ...c]`) with single-pass
    // inline accumulation using `_extractNumericValue` (fast-path `parseHealthRecordValue`).
    // Eliminates multiple temporary list allocations and regex instantiations per build frame.
    final (
      latest: latestRestingFound,
      avg: avgRestingFound,
      peak: peakRestingFound,
    ) = _computeStats(
      restingRecords,
    );

    final (
      latest: latestGeneralFound,
      avg: avgGeneralFound,
      peak: peakGeneralFound,
    ) = _computeStats(
      generalHeartRateRecords,
    );

    final (latest: _, avg: avgWalking, peak: peakWalkingFound) = _computeStats(
      walkingRecords,
    );

    final double? latestResting;
    final double? avgResting;
    if (restingRecords.isNotEmpty) {
      latestResting = latestRestingFound;
      avgResting = avgRestingFound;
    } else if (generalHeartRateRecords.isNotEmpty) {
      latestResting = latestGeneralFound;
      avgResting = avgGeneralFound;
    } else {
      latestResting = null;
      avgResting = null;
    }

    // Determine workout / peak heart rate from general, resting, or walking
    double? peakHeartRate;
    for (final p in [peakRestingFound, peakGeneralFound, peakWalkingFound]) {
      if (p != null) {
        peakHeartRate = peakHeartRate == null ? p : math.max(peakHeartRate, p);
      }
    }

    // Determine HRV (SDNN) average and latest
    final (latest: latestHrv, avg: avgHrv, peak: _) = _computeStats(hrvRecords);

    return Card(
      key: const ValueKey('heart-rhythm-analysis-card'),
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.monitor_heart, color: colors.primary, size: 22),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Heart Rhythm & Rate',
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: colors.primaryContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Longitudinal Vitals',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colors.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Comparative resting, walking, and workout rates alongside autonomic nervous system markers (HRV / SDNN).',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                // If width is constrained (e.g. mobile display or widget test viewport < 480px),
                // use a vertical column of metric rows to avoid any horizontal overflow.
                final isCompact = constraints.maxWidth < 480;
                final boxes = [
                  _MetricBox(
                    label: 'Resting Rate',
                    value: latestResting != null
                        ? '${latestResting.round()} bpm'
                        : '—',
                    subtitle: avgResting != null
                        ? 'Avg: ${avgResting.round()} bpm'
                        : 'No resting data',
                    icon: Icons.bed_outlined,
                    color: colors.primary,
                  ),
                  _MetricBox(
                    label: 'Walking Avg',
                    value: avgWalking != null
                        ? '${avgWalking.round()} bpm'
                        : '—',
                    subtitle: walkingRecords.isNotEmpty
                        ? '${walkingRecords.length} reading${walkingRecords.length == 1 ? '' : 's'}'
                        : 'No walking data',
                    icon: Icons.directions_walk,
                    color: colors.secondary,
                  ),
                  _MetricBox(
                    label: 'Peak Rate',
                    value: peakHeartRate != null
                        ? '${peakHeartRate.round()} bpm'
                        : '—',
                    subtitle: 'Recorded peak',
                    icon: Icons.fitness_center,
                    color: colors.tertiary,
                  ),
                ];

                if (isCompact) {
                  return Column(
                    children: [
                      for (final b in boxes)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: SizedBox(width: double.infinity, child: b),
                        ),
                    ],
                  );
                }

                return Row(
                  children: [
                    for (var i = 0; i < boxes.length; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      Expanded(child: boxes[i]),
                    ],
                  ],
                );
              },
            ),
            const SizedBox(height: 14),
            // Heart Rate Variability (HRV / SDNN)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: colors.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.graphic_eq, size: 20, color: colors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Heart Rate Variability (HRV / SDNN)',
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          latestHrv != null
                              ? 'Latest: ${latestHrv.round()} ms${avgHrv != null ? ' · Longitudinal Avg: ${avgHrv.round()} ms' : ''}'
                              : 'No HRV readings available in current range',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (hrvRecords.isNotEmpty && onRecordTap != null)
                    IconButton(
                      icon: const Icon(Icons.chevron_right, size: 18),
                      tooltip: 'View HRV readings',
                      onPressed: () => onRecordTap!(hrvRecords.last),
                    ),
                ],
              ),
            ),
            if (irregularRhythmRecords.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.errorContainer.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: colors.error.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 20,
                      color: colors.error,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Irregular Rhythm Notification History',
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colors.error,
                            ),
                          ),
                          Text(
                            '${irregularRhythmRecords.length} imported notification${irregularRhythmRecords.length == 1 ? '' : 's'} recorded from Apple Health / Health Connect. Discuss with your physician.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

final _nonDigitPattern = RegExp(r'[^\d.]');

/// Fast-path extraction of numeric value from health record without regex execution
/// when standard float parsing succeeds.
double? _extractNumericValue(HealthRecord record) {
  final direct = parseHealthRecordValue(record.value);
  if (direct != null) return direct;
  final stripped = record.value.replaceAll(_nonDigitPattern, '');
  return double.tryParse(stripped);
}

/// Computes latest, average, and peak numeric values in a single pass over [records],
/// avoiding intermediate list allocations and multiple traversal loops.
({double? latest, double? avg, double? peak}) _computeStats(
  List<HealthRecord> records,
) {
  if (records.isEmpty) {
    return (latest: null, avg: null, peak: null);
  }

  double? latest;
  double? peak;
  var sum = 0.0;
  var count = 0;

  for (final r in records) {
    final v = _extractNumericValue(r);
    if (v != null) {
      latest = v;
      sum += v;
      count++;
      if (peak == null || v > peak) {
        peak = v;
      }
    }
  }

  if (count == 0) {
    return (latest: null, avg: null, peak: null);
  }

  return (latest: latest, avg: sum / count, peak: peak);
}

class _MetricBox extends StatelessWidget {
  const _MetricBox({
    required this.label,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: 10,
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
