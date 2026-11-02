import 'package:flutter/material.dart';

import '../../exports/fhir_export_validator.dart';

/// Modal preflight review sheet for validating and previewing FHIR Bundles before sharing.
class FhirPreflightSheet extends StatelessWidget {
  const FhirPreflightSheet({
    super.key,
    required this.report,
    required this.onConfirmExport,
  });

  final FhirPreflightReport report;
  final VoidCallback onConfirmExport;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        maxWidth: 680,
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.rule_folder_outlined, color: colors.primary, size: 26),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'FHIR Export Preflight',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Close review',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Target profile badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: colors.primaryContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: colors.primary.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified_outlined, size: 16, color: colors.primary),
                const SizedBox(width: 6),
                Text(
                  'Target: ${report.targetProfile}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colors.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Resource breakdown overview
          Text(
            'Included resources (${report.totalResources})',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final entry in report.resourceCounts.entries)
                Chip(
                  label: Text('${entry.key}: ${entry.value}'),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Conformance review card
          _buildStatusBanner(context),
          const SizedBox(height: 10),

          // Scrollable issues list if any exist
          if (report.hasIssues)
            Flexible(
              child: Container(
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: colors.outlineVariant),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  itemCount: report.issues.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final issue = report.issues[index];
                    final (icon, iconColor) = switch (issue.severity) {
                      FhirIssueSeverity.error => (
                        Icons.error_outline,
                        colors.error,
                      ),
                      FhirIssueSeverity.warning => (
                        Icons.warning_amber_rounded,
                        Colors.amber.shade800,
                      ),
                      FhirIssueSeverity.info => (
                        Icons.info_outline,
                        colors.onSurfaceVariant,
                      ),
                    };

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(icon, size: 18, color: iconColor),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              issue.message,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colors.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),

          const SizedBox(height: 12),
          // Provider acceptance disclaimer
          Text(
            'Preflight confirms structural compliance with HL7 FHIR Release 4 (R4 v4.0.1). '
            'Provider portals and EHR systems may enforce custom profile requirements or specific terminology bindings; universal acceptance is not guaranteed.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
              fontStyle: FontStyle.italic,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 16),

          // Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                key: const ValueKey('fhir-preflight-confirm-button'),
                icon: const Icon(Icons.share, size: 18),
                label: const Text('Share FHIR Bundle'),
                onPressed: report.canExport
                    ? () {
                        Navigator.of(context).pop();
                        onConfirmExport();
                      }
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBanner(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    if (!report.canExport) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.errorContainer.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: colors.error),
        ),
        child: Row(
          children: [
            Icon(Icons.cancel_outlined, color: colors.error, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Validation failed: ${report.errors.length} fatal error(s) must be resolved before sharing.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colors.onErrorContainer,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (report.hasWarnings || report.hasIssues) {
      final count = report.warnings.length + report.infos.length;
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.amber.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.amber.shade400),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.amber.shade900, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Ready to export with $count conformance notice(s).',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.amber.shade900,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.teal.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.teal.shade400),
      ),
      child: Row(
        children: [
          Icon(
            Icons.check_circle_outline,
            color: Colors.teal.shade800,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'All FHIR R4 structural and field checks passed.',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.teal.shade900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
