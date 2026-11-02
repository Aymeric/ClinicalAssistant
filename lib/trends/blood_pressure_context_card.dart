import 'package:flutter/material.dart';

import '../models/cardiovascular_context.dart';
import '../models/health_record.dart';
import 'health_trend.dart';

/// Card presenting 2017 ACC/AHA blood pressure classifications and
/// morning vs. evening diurnal surge comparison.
///
/// NOTE: Content is strictly informational and observational; does not
/// provide automated clinical diagnoses or treatment advice.
class BloodPressureContextCard extends StatelessWidget {
  const BloodPressureContextCard({
    super.key,
    required this.systolicPoints,
    required this.diastolicPoints,
    this.onRecordTap,
  });

  final List<HealthTrendPoint> systolicPoints;
  final List<HealthTrendPoint> diastolicPoints;
  final ValueChanged<HealthRecord>? onRecordTap;

  @override
  Widget build(BuildContext context) {
    if (systolicPoints.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    // Latest staging
    final latestSys = systolicPoints.last;
    final latestDia = diastolicPoints.isNotEmpty ? diastolicPoints.last : null;
    final latestStaging = BloodPressureStaging.classify(
      systolic: latestSys.value,
      diastolic: latestDia?.value ?? 80,
    );

    // Diurnal stats: Morning vs. Evening
    final morningSys = <double>[];
    final morningDia = <double>[];
    final eveningSys = <double>[];
    final eveningDia = <double>[];

    final diaByTimestamp = {
      for (final p in diastolicPoints) p.record.recordedAt: p.value,
    };

    for (final sys in systolicPoints) {
      final local = sys.record.recordedAt.toLocal();
      final period = BloodPressureDiurnalPeriod.fromDateTime(local);
      final diaVal = diaByTimestamp[sys.record.recordedAt];

      if (period == BloodPressureDiurnalPeriod.morning) {
        morningSys.add(sys.value);
        if (diaVal != null) morningDia.add(diaVal);
      } else if (period == BloodPressureDiurnalPeriod.evening) {
        eveningSys.add(sys.value);
        if (diaVal != null) eveningDia.add(diaVal);
      }
    }

    final morningSysAvg = morningSys.isNotEmpty
        ? morningSys.reduce((a, b) => a + b) / morningSys.length
        : null;
    final morningDiaAvg = morningDia.isNotEmpty
        ? morningDia.reduce((a, b) => a + b) / morningDia.length
        : null;

    final eveningSysAvg = eveningSys.isNotEmpty
        ? eveningSys.reduce((a, b) => a + b) / eveningSys.length
        : null;
    final eveningDiaAvg = eveningDia.isNotEmpty
        ? eveningDia.reduce((a, b) => a + b) / eveningDia.length
        : null;

    final contextMeta = BloodPressureContext.fromRecord(latestSys.record);

    return Card(
      key: const ValueKey('bp-cardiovascular-context-card'),
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.favorite, color: latestStaging.color, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Cardiovascular Context & Staging',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: latestStaging.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: latestStaging.color.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    latestStaging.label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: latestStaging.color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'ACC/AHA 2017 Guidelines: ${latestStaging.description}.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              latestStaging.shortGuidance,
              style: theme.textTheme.bodySmall?.copyWith(
                fontStyle: FontStyle.italic,
                color: latestStaging.color,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (contextMeta != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.accessibility_new,
                      size: 16,
                      color: colors.primary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Latest context: ${contextMeta.formatSummary()}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const Divider(height: 24),
            Text(
              'Diurnal Blood Pressure Pattern',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Comparison between morning and evening readings to assist physician review for morning surges or nocturnal dipping.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _DiurnalSummaryBox(
                    title: 'Morning Average',
                    icon: Icons.wb_sunny_outlined,
                    readingCount: morningSys.length,
                    sysAvg: morningSysAvg,
                    diaAvg: morningDiaAvg,
                    color: colors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DiurnalSummaryBox(
                    title: 'Evening Average',
                    icon: Icons.nightlight_outlined,
                    readingCount: eveningSys.length,
                    sysAvg: eveningSysAvg,
                    diaAvg: eveningDiaAvg,
                    color: colors.tertiary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DiurnalSummaryBox extends StatelessWidget {
  const _DiurnalSummaryBox({
    required this.title,
    required this.icon,
    required this.readingCount,
    required this.sysAvg,
    required this.diaAvg,
    required this.color,
  });

  final String title;
  final IconData icon;
  final int readingCount;
  final double? sysAvg;
  final double? diaAvg;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final hasData = sysAvg != null;
    final readingStr = hasData
        ? '${sysAvg!.round()} / ${diaAvg?.round() ?? '—'} mmHg'
        : 'No readings';

    return Container(
      padding: const EdgeInsets.all(12),
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
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            readingStr,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: hasData ? colors.onSurface : colors.outline,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            hasData
                ? '$readingCount reading${readingCount == 1 ? '' : 's'}'
                : 'Log morning/evening readings',
            style: theme.textTheme.labelSmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
