import 'package:flutter/material.dart';

import 'clinical_guideline.dart';
import 'clinical_guideline_catalog.dart';
import 'guideline_source.dart';
import 'guideline_storage_service.dart';
import 'guideline_viewer_page.dart';
import 'guidelines_library_page.dart';

/// Contextual evidence-based guidelines section for a measurement or trend series.
///
/// Promotes educational reference and doctor-patient dialogue regarding recognized
/// clinical standards. Does not provide clinical diagnosis or automated decision-making.
class RelatedGuidelinesSection extends StatelessWidget {
  const RelatedGuidelinesSection({
    super.key,
    required this.measurementName,
    this.categoryLabel,
    this.loincCode,
    this.storageService,
    this.onOpenGuideline,
    this.onBrowseAllGuidelines,
    this.padding = EdgeInsets.zero,
  });

  final String measurementName;
  final String? categoryLabel;
  final String? loincCode;
  final GuidelineStorageService? storageService;
  final ValueChanged<ClinicalGuideline>? onOpenGuideline;
  final VoidCallback? onBrowseAllGuidelines;
  final EdgeInsetsGeometry padding;

  void _handleOpenGuideline(BuildContext context, ClinicalGuideline guideline) {
    if (onOpenGuideline != null) {
      onOpenGuideline!(guideline);
      return;
    }
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => GuidelineViewerPage(
          guideline: guideline,
          storageService: storageService,
        ),
      ),
    );
  }

  void _handleBrowseAll(BuildContext context, GuidelineTopic topic) {
    if (onBrowseAllGuidelines != null) {
      onBrowseAllGuidelines!();
      return;
    }
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => GuidelinesLibraryPage(
          initialTopic: topic,
          storageService: storageService,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final related = ClinicalGuidelineCatalog.findRelatedGuidelines(
      measurementName: measurementName,
      category: categoryLabel,
      loincCode: loincCode,
    );

    if (related.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final primaryTopic = related.first.topic;

    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.menu_book_outlined,
                size: 18,
                color: colors.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Evidence-Based Guidelines',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: colors.secondaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Educational',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.onSecondaryContainer,
                    fontWeight: FontWeight.w600,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Authoritative guidance for shared decision-making with your doctor. '
            'These general reference standards do not interpret your personal reading.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          for (final guideline in related)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                key: ValueKey('related-guideline-${guideline.id}'),
                elevation: 0,
                color: colors.surfaceContainerHighest.withValues(alpha: 0.45),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(
                    color: colors.outlineVariant.withValues(alpha: 0.6),
                  ),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => _handleOpenGuideline(context, guideline),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: colors.primaryContainer,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                guideline.identifier,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: colors.onPrimaryContainer,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                            Text(
                              guideline.jurisdiction.label,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colors.onSurfaceVariant,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          guideline.title,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                guideline.publisher,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: colors.onSurfaceVariant,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.arrow_forward_ios,
                              size: 12,
                              color: colors.primary,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const ValueKey('browse-related-guidelines-button'),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 4),
              ),
              onPressed: () => _handleBrowseAll(context, primaryTopic),
              icon: const Icon(Icons.open_in_new, size: 14),
              label: Text(
                'Browse ${primaryTopic.label} guidelines (${related.length})',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
