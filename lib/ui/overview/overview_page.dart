import 'package:flutter/material.dart';

import '../../models/health_record.dart';
import '../../sync/foreground_sync_state.dart';
import '../../trends/health_trend.dart';
import '../shared/record_widgets.dart';

String formatRecordsSpan(List<HealthRecord> records) {
  if (records.isEmpty) return 'No records';
  DateTime min = records.first.recordedAt;
  DateTime max = records.first.recordedAt;
  for (final r in records) {
    if (r.recordedAt.isBefore(min)) min = r.recordedAt;
    if (r.recordedAt.isAfter(max)) max = r.recordedAt;
  }
  final days = max.difference(min).inDays;
  if (days <= 1) return '1 day';
  if (days < 30) return '$days d';
  if (days < 365) return '${(days / 30).round()} mos';
  final years = (days / 365).toStringAsFixed(1).replaceAll('.0', '');
  return '$years yrs';
}

String formatSyncTimestamp(DateTime? value) {
  if (value == null) return 'Not synced yet';
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final period = local.hour < 12 ? 'AM' : 'PM';
  return '$month/$day/${local.year} at $hour:$minute $period';
}

class OverviewPage extends StatelessWidget {
  const OverviewPage({
    super.key,
    required this.records,
    required this.loading,
    required this.error,
    required this.onConnect,
    required this.onSeeAll,
    required this.onRetry,
    this.syncState,
    this.syncing = false,
    this.pinnedSeries = const {},
    this.onSelectCategory,
    this.onRecordTap,
    this.onSyncNow,
    this.onOpenTrends,
    this.onViewInTrends,
    this.onOpenRecords,
    this.onOpenExport,
    this.onOpenGuidelines,
    this.onLogMeasurement,
    this.onViewOutOfRangeLabs,
    this.onOpenMedications,
  });

  final List<HealthRecord> records;
  final bool loading;
  final Object? error;
  final VoidCallback onConnect;
  final VoidCallback onSeeAll;
  final VoidCallback onRetry;
  final ForegroundSyncState? syncState;
  final bool syncing;
  final Set<String> pinnedSeries;
  final ValueChanged<RecordCategory>? onSelectCategory;
  final ValueChanged<HealthRecord>? onRecordTap;
  final VoidCallback? onSyncNow;
  final VoidCallback? onOpenTrends;
  final ValueChanged<HealthRecord>? onViewInTrends;
  final VoidCallback? onOpenRecords;
  final VoidCallback? onOpenExport;
  final VoidCallback? onOpenGuidelines;
  final VoidCallback? onLogMeasurement;
  final VoidCallback? onViewOutOfRangeLabs;
  final VoidCallback? onOpenMedications;

  @override
  Widget build(BuildContext context) {
    final labs = records.where(
      (record) => record.category == RecordCategory.lab,
    );
    final latest = [...records]
      ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    final trendSeries = buildHealthTrendSeries(records)
      ..sort((a, b) {
        final latestDateOrder = b.points.last.record.recordedAt.compareTo(
          a.points.last.record.recordedAt,
        );
        return latestDateOrder != 0
            ? latestDateOrder
            : a.name.compareTo(b.name);
      });

    final outOfRangeLabs = buildLatestLabResultSummaries(records)
        .where(
          (summary) =>
              summary.latestStatus == HealthReferenceStatus.above ||
              summary.latestStatus == HealthReferenceStatus.below,
        )
        .toList();

    final activeMeds = records
        .where(
          (r) =>
              r.category == RecordCategory.medication &&
              (r.referenceRange == null ||
                  r.referenceRange!.isEmpty ||
                  r.referenceRange == 'active'),
        )
        .toList();

    // Pinned metrics
    final pinnedRecords = <HealthRecord>[];
    for (final seriesId in pinnedSeries) {
      final matches = records
          .where((r) => healthTrendSeriesId(r) == seriesId)
          .toList();
      if (matches.isNotEmpty) {
        matches.sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
        pinnedRecords.add(matches.first);
      }
    }

    return RefreshIndicator(
      onRefresh: () async => onSyncNow?.call(),
      child: PageContent(
        children: [
          if (error != null)
            ErrorNotice(message: error.toString(), onRetry: onRetry),
          const SizedBox(height: 8),
          Text(
            'Your health history,\nall together.',
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
              fontWeight: FontWeight.w700,
              height: 1.06,
              letterSpacing: -1.1,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Bring records from your health platforms and care providers into one private place.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              key: const ValueKey('overview-guidelines-shortcut'),
              onTap: onOpenGuidelines,
              leading: CircleAvatar(
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.secondaryContainer,
                child: Icon(
                  Icons.menu_book_outlined,
                  color: Theme.of(context).colorScheme.onSecondaryContainer,
                ),
              ),
              title: const Text(
                'Evidence-based guidelines',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: const Text(
                'Browse trusted sources by topic and region',
              ),
              trailing: const Icon(Icons.chevron_right),
            ),
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconStamp(
                        icon: Icons.lock_outline,
                        background: Theme.of(
                          context,
                        ).colorScheme.primaryContainer,
                        foreground: Theme.of(
                          context,
                        ).colorScheme.onPrimaryContainer,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          'Kept on this device',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    loading
                        ? 'Opening your encrypted record vault...'
                        : '${records.length} ${records.length == 1 ? 'record' : 'records'} saved  ·  ${labs.length} lab ${labs.length == 1 ? 'result' : 'results'}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (syncState?.hasAutoSync == true) ...[
                    const SizedBox(height: 14),
                    OverviewSyncStatusBar(
                      syncState: syncState!,
                      syncing: syncing,
                      onSyncNow: onSyncNow,
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (records.isEmpty)
                    FilledButton.icon(
                      onPressed: loading ? null : onConnect,
                      icon: const Icon(Icons.add_link),
                      label: const Text('Connect a health source'),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: onConnect,
                          icon: const Icon(Icons.add_link),
                          label: const Text('Add another source'),
                        ),
                        if (onLogMeasurement != null)
                          FilledButton.tonalIcon(
                            key: const ValueKey(
                              'overview-log-measurement-button',
                            ),
                            onPressed: onLogMeasurement,
                            icon: const Icon(Icons.edit_note),
                            label: const Text('Log measurement'),
                          ),
                        if (onOpenMedications != null)
                          FilledButton.tonalIcon(
                            key: const ValueKey('overview-medications-button'),
                            onPressed: onOpenMedications,
                            icon: const Icon(Icons.medication_outlined),
                            label: const Text('Medications'),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),

          // Pinned Metrics Section
          if (pinnedRecords.isNotEmpty) ...[
            const SizedBox(height: 24),
            const SectionHeading(title: 'Pinned metrics'),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final record in pinnedRecords)
                    Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: InkWell(
                        onTap: () => onRecordTap?.call(record),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          width: 170,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest
                                .withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(16),
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
                                  Icon(
                                    Icons.push_pin,
                                    size: 14,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      record.name,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                record.displayValue,
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                MaterialLocalizations.of(
                                  context,
                                ).formatShortDate(record.recordedAt.toLocal()),
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],

          if (activeMeds.isNotEmpty) ...[
            const SizedBox(height: 24),
            SectionHeading(
              title: 'Current medications',
              trailing: onOpenMedications != null
                  ? TextButton(
                      key: const ValueKey('overview-manage-meds-button'),
                      onPressed: onOpenMedications,
                      child: const Text('Manage all'),
                    )
                  : null,
            ),
            const SizedBox(height: 10),
            Card(
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: activeMeds.take(3).length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (ctx, index) {
                  final med = activeMeds[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.primaryContainer,
                      foregroundColor: Theme.of(
                        context,
                      ).colorScheme.onPrimaryContainer,
                      child: const Icon(Icons.medication_outlined, size: 20),
                    ),
                    title: Text(
                      med.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      med.value.isNotEmpty ? med.value : 'No dose instructions',
                    ),
                    trailing: const Icon(Icons.chevron_right, size: 18),
                    onTap: onOpenMedications,
                  );
                },
              ),
            ),
          ],

          // Out-of-Range Labs Section
          if (outOfRangeLabs.isNotEmpty) ...[
            const SizedBox(height: 24),
            SectionHeading(
              title: 'Flagged lab results',
              trailing: InkWell(
                key: const ValueKey('overview-view-out-of-range-button'),
                onTap: onViewOutOfRangeLabs,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${outOfRangeLabs.length} currently out of range',
                        style: TextStyle(
                          color: Colors.red.shade900,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                      if (onViewOutOfRangeLabs != null) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward,
                          size: 12,
                          color: Colors.red.shade900,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Card(
              color: Colors.red.withValues(alpha: 0.04),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.red.withValues(alpha: 0.25)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    for (final summary in outOfRangeLabs.take(3))
                      ListTile(
                        dense: true,
                        isThreeLine: true,
                        minVerticalPadding: 10,
                        key: ValueKey(
                          'flagged-lab-${summary.latest.record.id}',
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 4,
                        ),
                        onTap: () => onRecordTap?.call(summary.latest.record),
                        leading: Icon(
                          summary.latestStatus == HealthReferenceStatus.above
                              ? Icons.arrow_upward
                              : Icons.arrow_downward,
                          color:
                              summary.latestStatus ==
                                  HealthReferenceStatus.above
                              ? Colors.deepOrange
                              : Colors.blueGrey,
                        ),
                        title: Text(
                          summary.latest.record.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${MaterialLocalizations.of(context).formatShortDate(summary.latest.record.recordedAt.toLocal())} · ${summary.latest.record.displayValue}',
                            ),
                            Text(
                              'Reference range: ${summary.latestRange!.sourceText}',
                            ),
                            if (summary.previous case final previous?)
                              Text(
                                'Previous ${MaterialLocalizations.of(context).formatShortDate(previous.record.recordedAt.toLocal())}: ${previous.record.displayValue} · Ref: ${summary.previousRange?.sourceText ?? "unavailable"}',
                              ),
                            Text(
                              summary.previous == null
                                  ? 'No earlier comparable result'
                                  : summary.direction.label,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        trailing: const Icon(Icons.chevron_right, size: 18),
                      ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 24),
          SectionHeading(
            title: 'Trends',
            trailing: TextButton.icon(
              key: const ValueKey('overview-trends-view-all'),
              onPressed: onOpenTrends,
              icon: const Icon(Icons.arrow_forward, size: 16),
              label: const Text('View all'),
            ),
          ),
          const SizedBox(height: 10),
          if (trendSeries.isEmpty)
            Card(
              child: ListTile(
                leading: Icon(
                  Icons.insights_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: const Text('No numeric readings yet'),
                subtitle: const Text(
                  'Import or log measurements to explore recorded values over time.',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: onOpenTrends,
              ),
            )
          else
            Card(
              key: const ValueKey('overview-trends-list'),
              child: Column(
                children: [
                  for (
                    var index = 0;
                    index < trendSeries.take(3).length;
                    index++
                  ) ...[
                    OverviewTrendRow(
                      series: trendSeries[index],
                      onTap: onViewInTrends == null
                          ? null
                          : () => onViewInTrends!(
                              trendSeries[index].points.last.record,
                            ),
                    ),
                    if (index < trendSeries.take(3).length - 1)
                      Divider(
                        height: 1,
                        indent: 68,
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                  ],
                ],
              ),
            ),

          const SizedBox(height: 26),
          SectionHeading(
            title: 'Recent records',
            trailing: TextButton(
              onPressed: onSeeAll,
              child: const Text('See all'),
            ),
          ),
          if (records.isEmpty && !loading)
            const QuietEmptyState(
              icon: Icons.notes_outlined,
              title: 'Your timeline starts here',
              message:
                  'Imported health records and lab results will appear here with their source and date.',
            )
          else
            RecordLedger(
              records: latest.take(4).toList(),
              onTapRecord: onRecordTap,
            ),
          if (records.isNotEmpty) ...[
            const SizedBox(height: 20),
            OverviewMetricStrip(records: records),
            const SizedBox(height: 24),
            OverviewCategoryBreakdown(
              records: records,
              onSelectCategory: onSelectCategory,
            ),
            const SizedBox(height: 24),
            const SectionHeading(title: 'Quick actions'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OverviewQuickButton(
                    key: const ValueKey('overview-action-trends'),
                    icon: Icons.insights_outlined,
                    label: 'Trends',
                    subtitle: 'Vitals & labs',
                    onTap: onOpenTrends,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: OverviewQuickButton(
                    key: const ValueKey('overview-action-records'),
                    icon: Icons.folder_outlined,
                    label: 'Records',
                    subtitle: 'All entries',
                    onTap: onOpenRecords ?? onSeeAll,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: OverviewQuickButton(
                    key: const ValueKey('overview-action-export'),
                    icon: Icons.share_outlined,
                    label: 'Export',
                    subtitle: 'PDF, CSV, FHIR',
                    onTap: onOpenExport,
                  ),
                ),
                if (onLogMeasurement != null) ...[
                  const SizedBox(width: 6),
                  Expanded(
                    child: OverviewQuickButton(
                      key: const ValueKey('overview-action-log'),
                      icon: Icons.edit_note,
                      label: 'Log',
                      subtitle: 'Add reading',
                      onTap: onLogMeasurement,
                    ),
                  ),
                ],
              ],
            ),
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class OverviewMetricStrip extends StatelessWidget {
  const OverviewMetricStrip({super.key, required this.records});

  final List<HealthRecord> records;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final categoriesCount = records
        .map((record) => record.category)
        .toSet()
        .length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: MetricItem(
              label: 'Records',
              value: records.length.toString(),
              icon: Icons.receipt_long_outlined,
            ),
          ),
          Container(
            height: 22,
            width: 1,
            color: colors.outlineVariant.withValues(alpha: 0.4),
          ),
          Expanded(
            child: MetricItem(
              label: 'Types',
              value: categoriesCount.toString(),
              icon: Icons.category_outlined,
            ),
          ),
          Container(
            height: 22,
            width: 1,
            color: colors.outlineVariant.withValues(alpha: 0.4),
          ),
          Expanded(
            child: MetricItem(
              label: 'Span',
              value: formatRecordsSpan(records),
              icon: Icons.history_outlined,
            ),
          ),
        ],
      ),
    );
  }
}

class OverviewTrendRow extends StatelessWidget {
  const OverviewTrendRow({
    super.key,
    required this.series,
    required this.onTap,
  });

  final HealthTrendSeries series;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final latest = series.points.last;
    final previous = series.points.length > 1
        ? series.points[series.points.length - 2]
        : null;
    final latestDate = MaterialLocalizations.of(
      context,
    ).formatShortDate(latest.record.recordedAt.toLocal());
    final previousDate = previous == null
        ? null
        : MaterialLocalizations.of(
            context,
          ).formatShortDate(previous.record.recordedAt.toLocal());
    final difference = previous == null ? null : latest.value - previous.value;
    final changeText = switch (difference) {
      null => 'Change unavailable',
      0 => 'No change',
      final value =>
        'Change: ${value > 0 ? '+' : '−'}${formatSensibleNumber(value.abs())}${series.unit.isEmpty ? '' : ' ${series.unit}'}',
    };
    final trendIcon = switch (difference) {
      null || 0 => Icons.trending_flat,
      final value when value > 0 => Icons.trending_up,
      _ => Icons.trending_down,
    };
    final previousText = previous == null
        ? '${categoryLabel(series.category)} · One reading so far'
        : '${categoryLabel(series.category)} · Previous ${previous.record.displayValue} on $previousDate';

    return ListTile(
      key: ValueKey('overview-trend-${latest.record.id}'),
      minVerticalPadding: 12,
      leading: Icon(trendIcon, color: colors.primary),
      onTap: onTap,
      title: Text(
        series.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(previousText, maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(changeText),
        ],
      ),
      trailing: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            latest.record.displayValue,
            textAlign: TextAlign.end,
            style: theme.textTheme.titleSmall?.copyWith(
              color: colors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            latestDate,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class MetricItem extends StatelessWidget {
  const MetricItem({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 13, color: theme.colorScheme.primary),
                const SizedBox(width: 3),
                Text(
                  value,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class OverviewQuickButton extends StatelessWidget {
  const OverviewQuickButton({
    super.key,
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Material(
      color: colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: colors.primary),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 10,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class OverviewCategoryBreakdown extends StatelessWidget {
  const OverviewCategoryBreakdown({
    super.key,
    required this.records,
    this.onSelectCategory,
  });

  final List<HealthRecord> records;
  final ValueChanged<RecordCategory>? onSelectCategory;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final availableCategories = RecordCategory.values
        .where((cat) => records.any((r) => r.category == cat))
        .toList();

    if (availableCategories.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Categories',
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final category in availableCategories)
              CategorySummaryBadge(
                category: category,
                count: records.where((r) => r.category == category).length,
                onTap: onSelectCategory == null
                    ? null
                    : () => onSelectCategory!(category),
              ),
          ],
        ),
      ],
    );
  }
}

class CategorySummaryBadge extends StatelessWidget {
  const CategorySummaryBadge({
    super.key,
    required this.category,
    required this.count,
    this.onTap,
  });

  final RecordCategory category;
  final int count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final catColor = categoryColor(category, colors);
    final catIcon = categoryIcon(category);

    return Material(
      color: colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.7)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(catIcon, size: 16, color: catColor),
              const SizedBox(width: 6),
              Text(
                categoryLabel(category),
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: catColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: catColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class OverviewSyncStatusBar extends StatelessWidget {
  const OverviewSyncStatusBar({
    super.key,
    required this.syncState,
    required this.syncing,
    this.onSyncNow,
  });

  final ForegroundSyncState syncState;
  final bool syncing;
  final VoidCallback? onSyncNow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final latestSync =
        syncState.lastHealthSyncAt != null && syncState.lastFhirSyncAt != null
        ? (syncState.lastHealthSyncAt!.isAfter(syncState.lastFhirSyncAt!)
              ? syncState.lastHealthSyncAt
              : syncState.lastFhirSyncAt)
        : syncState.lastHealthSyncAt ?? syncState.lastFhirSyncAt;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(Icons.sync, size: 16, color: colors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Last synced: ${formatSyncTimestamp(latestSync)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
          if (onSyncNow != null)
            TextButton.icon(
              onPressed: syncing ? null : onSyncNow,
              icon: syncing
                  ? const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh, size: 14),
              label: Text(syncing ? 'Syncing...' : 'Sync now'),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
            ),
        ],
      ),
    );
  }
}
