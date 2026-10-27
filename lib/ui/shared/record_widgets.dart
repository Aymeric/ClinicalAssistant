import 'package:flutter/material.dart';

import '../../guidelines/clinical_guideline_catalog.dart';
import '../../models/clinical_panel.dart';
import '../../models/health_record.dart';
import '../../sync/import_progress.dart';
import '../../trends/health_trend.dart';

String categoryLabel(RecordCategory category) => switch (category) {
  RecordCategory.lab => 'Labs',
  RecordCategory.vital => 'Vitals',
  RecordCategory.activity => 'Activity',
  RecordCategory.sleep => 'Sleep',
  RecordCategory.nutrition => 'Nutrition',
  RecordCategory.cycleTracking => 'Cycle tracking',
  RecordCategory.medication => 'Medications',
  RecordCategory.condition => 'Conditions',
  RecordCategory.allergy => 'Allergies',
  RecordCategory.immunization => 'Immunizations',
};

String formatRecordDate(DateTime date) {
  final local = date.toLocal();
  return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
}

String displayError(Object error) {
  if (error is StateError) return error.message.toString();
  if (error is FormatException) return error.message;
  return error.toString().replaceFirst('Exception: ', '');
}

IconData categoryIcon(RecordCategory category) => switch (category) {
  RecordCategory.lab => Icons.science_outlined,
  RecordCategory.vital => Icons.monitor_heart_outlined,
  RecordCategory.activity => Icons.directions_walk_outlined,
  RecordCategory.sleep => Icons.bedtime_outlined,
  RecordCategory.nutrition => Icons.restaurant_outlined,
  RecordCategory.cycleTracking => Icons.water_drop_outlined,
  RecordCategory.medication => Icons.medication_outlined,
  RecordCategory.condition => Icons.health_and_safety_outlined,
  RecordCategory.allergy => Icons.warning_amber_outlined,
  RecordCategory.immunization => Icons.vaccines_outlined,
};

Color categoryColor(RecordCategory category, ColorScheme colors) {
  return switch (category) {
    RecordCategory.lab => colors.tertiary,
    RecordCategory.vital => colors.primary,
    RecordCategory.activity => Colors.orange.shade700,
    RecordCategory.sleep => Colors.indigo.shade600,
    RecordCategory.nutrition => Colors.teal.shade700,
    RecordCategory.cycleTracking => Colors.pink.shade600,
    RecordCategory.medication => Colors.purple.shade600,
    RecordCategory.condition => Colors.amber.shade800,
    RecordCategory.allergy => Colors.redAccent.shade700,
    RecordCategory.immunization => Colors.cyan.shade700,
  };
}

class OperationProgressIndicator extends StatelessWidget {
  const OperationProgressIndicator({super.key, required this.progress});

  final ImportProgress progress;

  @override
  Widget build(BuildContext context) {
    final fraction = progress.fraction.clamp(0, 1).toDouble();
    final percentage = (fraction * 100).round();
    return Semantics(
      liveRegion: true,
      label: '${progress.message}: $percentage percent',
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      progress.message,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '$percentage%',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              LinearProgressIndicator(value: fraction, minHeight: 4),
            ],
          ),
        ),
      ),
    );
  }
}

class SourcePanel extends StatelessWidget {
  const SourcePanel({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.count,
    this.rawCount,
    required this.connected,
    required this.busy,
    required this.buttonLabel,
    required this.onPressed,
    this.onResetAnchor,
    this.hasAnchor = false,
  });

  final IconData icon;
  final String title;
  final String description;
  final int count;
  final int? rawCount;
  final bool connected;
  final bool busy;
  final String buttonLabel;
  final VoidCallback? onPressed;
  final VoidCallback? onResetAnchor;
  final bool hasAnchor;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconStamp(
                  icon: icon,
                  background: Theme.of(context).colorScheme.primaryContainer,
                  foreground: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (count > 0) CountPill(count: count, rawCount: rawCount),
              ],
            ),
            if (connected) ...[
              const SizedBox(height: 8),
              const ConnectionStatusPill(),
            ],
            const SizedBox(height: 14),
            Text(description),
            const SizedBox(height: 8),
            Text(
              'Data types available depend on your device, permissions, and connected apps.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: onPressed,
                  icon: busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sync),
                  label: Text(busy ? 'Importing...' : buttonLabel),
                ),
                if (hasAnchor && onResetAnchor != null)
                  OutlinedButton.icon(
                    key: const ValueKey('reset-health-sync-anchor-button'),
                    onPressed: busy ? null : onResetAnchor,
                    icon: const Icon(Icons.restart_alt, size: 18),
                    label: const Text('Reset sync anchor'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ConnectionStatusPill extends StatelessWidget {
  const ConnectionStatusPill({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, size: 14, color: colors.onPrimaryContainer),
          const SizedBox(width: 4),
          Text(
            'Connected',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colors.onPrimaryContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class RecordLedger extends StatelessWidget {
  const RecordLedger({super.key, required this.records, this.onTapRecord});

  final List<HealthRecord> records;
  final ValueChanged<HealthRecord>? onTapRecord;

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) {
      return const QuietEmptyState(
        icon: Icons.timeline_outlined,
        title: 'No records yet',
        message:
            'When you connect a source, its records will be organized here by date.',
      );
    }
    return Column(
      children: [
        for (var index = 0; index < records.length; index++)
          RecordRow(
            record: records[index],
            isLast: index == records.length - 1,
            onTap: onTapRecord != null
                ? () => onTapRecord!(records[index])
                : null,
          ),
      ],
    );
  }
}

class RecordRow extends StatelessWidget {
  const RecordRow({
    super.key,
    required this.record,
    required this.isLast,
    this.onTap,
  });

  final HealthRecord record;
  final bool isLast;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = categoryColor(record.category, colors);

    HealthReferenceStatus? status;
    if (record.category == RecordCategory.lab &&
        record.referenceRange != null &&
        record.referenceRange!.isNotEmpty) {
      final range = HealthReferenceRange.tryParse(record.referenceRange);
      final numVal = parseHealthRecordValue(record.value);
      if (range != null && numVal != null) {
        status = range.evaluate(numVal);
      }
    }

    final isOutOfRange =
        status == HealthReferenceStatus.above ||
        status == HealthReferenceStatus.below;

    final hasGuideline = ClinicalGuidelineCatalog.hasRelatedGuidelines(
      measurementName: record.name,
      category: categoryLabel(record.category),
      loincCode: record.code,
    );

    final trimmedValue = record.displayValue.trim();
    final isLongValue =
        trimmedValue.length > 18 ||
        trimmedValue.contains(' · ') ||
        trimmedValue.contains('\n');

    final semanticParts = <String>[
      record.name,
      if (trimmedValue.isNotEmpty) trimmedValue,
      if (isOutOfRange)
        status == HealthReferenceStatus.above
            ? "Out of range: High"
            : "Out of range: Low",
      categoryLabel(record.category),
      "Recorded ${formatRecordDate(record.recordedAt)}",
      "Source ${record.source}",
      if (hasGuideline) "Clinical guideline available",
    ];

    return Semantics(
      button: onTap != null,
      label: semanticParts.join(", "),
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 40,
                child: Column(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      margin: const EdgeInsets.only(top: 5),
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    if (!isLast)
                      Container(
                        width: 1,
                        height: 50,
                        margin: const EdgeInsets.only(top: 5),
                        color: colors.outlineVariant,
                      ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            record.name,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (isOutOfRange) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: colors.errorContainer,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              status == HealthReferenceStatus.above
                                  ? 'High'
                                  : 'Low',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: colors.onErrorContainer,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 10,
                                  ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (isLongValue && trimmedValue.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        trimmedValue,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colors.onSurface,
                        ),
                      ),
                    ],
                    const SizedBox(height: 3),
                    Text(
                      '${formatRecordDate(record.recordedAt)}  ·  ${record.source}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    if (hasGuideline) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          color: colors.primaryContainer.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.menu_book_outlined,
                              size: 10,
                              color: colors.onPrimaryContainer,
                            ),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                'Guideline',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: colors.onPrimaryContainer,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 10,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (!isLongValue && trimmedValue.isNotEmpty) ...[
                const SizedBox(width: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 130),
                  child: Text(
                    trimmedValue,
                    textAlign: TextAlign.end,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class ClinicalPanelCard extends StatefulWidget {
  const ClinicalPanelCard({
    super.key,
    required this.panel,
    required this.isLast,
    this.onTapRecord,
    this.initiallyExpanded = false,
  });

  final ClinicalPanel panel;
  final bool isLast;
  final ValueChanged<HealthRecord>? onTapRecord;
  final bool initiallyExpanded;

  @override
  State<ClinicalPanelCard> createState() => _ClinicalPanelCardState();
}

class _ClinicalPanelCardState extends State<ClinicalPanelCard> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = categoryColor(RecordCategory.lab, colors);
    final outOfRange = widget.panel.outOfRangeCount;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 40,
            child: Column(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  margin: const EdgeInsets.only(top: 12),
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                if (!widget.isLast)
                  Container(
                    width: 1,
                    height: _expanded
                        ? (60.0 + widget.panel.records.length * 48.0)
                        : 60,
                    margin: const EdgeInsets.only(top: 4),
                    color: colors.outlineVariant,
                  ),
              ],
            ),
          ),
          Expanded(
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: outOfRange > 0
                      ? colors.error.withValues(alpha: 0.5)
                      : colors.outlineVariant,
                ),
              ),
              color: colors.surfaceContainerLow,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => setState(() => _expanded = !_expanded),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.table_rows_outlined,
                            size: 20,
                            color: color,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              widget.panel.name,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: colors.secondaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${widget.panel.analyteCount} tests',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: colors.onSecondaryContainer,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                          if (outOfRange > 0) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: colors.errorContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.warning_amber_rounded,
                                    size: 13,
                                    color: colors.onErrorContainer,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    '$outOfRange out of range',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: colors.onErrorContainer,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(width: 4),
                          IconButton(
                            icon: Icon(
                              _expanded ? Icons.expand_less : Icons.expand_more,
                            ),
                            tooltip: _expanded
                                ? 'Collapse panel'
                                : 'Expand panel',
                            onPressed: () =>
                                setState(() => _expanded = !_expanded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${formatRecordDate(widget.panel.recordedAt)}  ·  ${widget.panel.source}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      if (_expanded) ...[
                        const SizedBox(height: 12),
                        const Divider(height: 1),
                        const SizedBox(height: 8),
                        for (final record in widget.panel.records)
                          _buildAnalyteRow(context, record, colors),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyteRow(
    BuildContext context,
    HealthRecord record,
    ColorScheme colors,
  ) {
    HealthReferenceStatus? status;
    if (record.referenceRange != null && record.referenceRange!.isNotEmpty) {
      final range = HealthReferenceRange.tryParse(record.referenceRange);
      final numVal = parseHealthRecordValue(record.value);
      if (range != null && numVal != null) {
        status = range.evaluate(numVal);
      }
    }
    final isOutOfRange =
        status == HealthReferenceStatus.above ||
        status == HealthReferenceStatus.below;

    return InkWell(
      key: ValueKey('clinical-panel-analyte-${record.name}'),
      onTap: widget.onTapRecord != null
          ? () => widget.onTapRecord!(record)
          : null,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.name,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (record.referenceRange != null &&
                      record.referenceRange!.isNotEmpty)
                    Text(
                      'Ref: ${record.referenceRange}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.outline,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
            if (isOutOfRange) ...[
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 1.5,
                ),
                decoration: BoxDecoration(
                  color: colors.errorContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  status == HealthReferenceStatus.above ? 'High' : 'Low',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colors.onErrorContainer,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
            Text(
              record.displayValue,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 16, color: colors.outlineVariant),
          ],
        ),
      ),
    );
  }
}

class PageContent extends StatelessWidget {
  const PageContent({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 28),
          children: children,
        ),
      ),
    );
  }
}

class QuietEmptyState extends StatelessWidget {
  const QuietEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 22,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ErrorNotice extends StatelessWidget {
  const ErrorNotice({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Could not open your records',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
            TextButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}

class SectionHeading extends StatelessWidget {
  const SectionHeading({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

class IconStamp extends StatelessWidget {
  const IconStamp({
    super.key,
    required this.icon,
    required this.background,
    required this.foreground,
  });

  final IconData icon;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: foreground),
    );
  }
}

class CountPill extends StatelessWidget {
  const CountPill({super.key, required this.count, this.rawCount});

  final int count;
  final int? rawCount;

  @override
  Widget build(BuildContext context) {
    final label = (rawCount != null && rawCount! > count)
        ? '$count imported ($rawCount raw)'
        : '$count imported';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label),
    );
  }
}

class PrivacyNote extends StatelessWidget {
  const PrivacyNote({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.lock_outline, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(text)),
      ],
    );
  }
}

class AppFilterChip extends StatelessWidget {
  const AppFilterChip({
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
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
    );
  }
}

class DetailLine extends StatelessWidget {
  const DetailLine({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 116,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
