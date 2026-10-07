import 'package:flutter/material.dart';

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
    required this.connected,
    required this.busy,
    required this.buttonLabel,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String description;
  final int count;
  final bool connected;
  final bool busy;
  final String buttonLabel;
  final VoidCallback? onPressed;

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
                if (count > 0) CountPill(count: count),
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

    final trimmedValue = record.displayValue.trim();
    final isLongValue =
        trimmedValue.length > 18 ||
        trimmedValue.contains(' · ') ||
        trimmedValue.contains('\n');

    final semanticParts = [
      record.name,
      if (trimmedValue.isNotEmpty) trimmedValue,
      if (isOutOfRange)
        status == HealthReferenceStatus.above
            ? 'High (out of range)'
            : 'Low (out of range)',
      formatRecordDate(record.recordedAt),
      record.source,
    ];

    return Semantics(
      button: onTap != null,
      enabled: onTap != null,
      label: semanticParts.join(', '),
      child: ExcludeSemantics(
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
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
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
  const CountPill({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text('$count imported'),
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
