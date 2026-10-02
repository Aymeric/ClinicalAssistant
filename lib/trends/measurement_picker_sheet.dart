import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../ui/shared/record_widgets.dart';
import 'health_trend.dart';

/// Interactive button/card that presents the currently selected measurement
/// and triggers the measurement picker bottom sheet.
class MeasurementSelector extends StatelessWidget {
  const MeasurementSelector({
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
                        '${categoryLabel(selected!.category)} · $latest · ${selected!.points.length} readings',
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

/// Searchable modal bottom sheet allowing user to choose from available measurements.
class MeasurementPickerSheet extends StatefulWidget {
  const MeasurementPickerSheet({
    super.key,
    required this.series,
    required this.selectedSeriesId,
  });

  final List<HealthTrendSeries> series;
  final String? selectedSeriesId;

  @override
  State<MeasurementPickerSheet> createState() => _MeasurementPickerSheetState();
}

class _MeasurementPickerSheetState extends State<MeasurementPickerSheet> {
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
          categoryLabel(series.category).toLowerCase().contains(query);
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
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
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
                              '${categoryLabel(series.category)} · ${series.unit.isEmpty ? 'No unit' : series.unit} · ${series.points.length} readings',
                            ),
                            trailing: selected
                                ? Icon(
                                    Icons.check,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
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
