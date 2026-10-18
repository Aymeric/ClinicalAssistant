import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'clinical_guideline.dart';
import 'guideline_pdf_export_service.dart';
import 'guideline_source.dart';
import 'guideline_storage_service.dart';

class GuidelineViewerPage extends StatefulWidget {
  const GuidelineViewerPage({
    super.key,
    required this.guideline,
    this.storageService,
    this.pdfExportService,
    this.initialIsDownloaded,
    this.onDownloadChanged,
  });

  final ClinicalGuideline guideline;
  final GuidelineStorageService? storageService;
  final GuidelinePdfExportService? pdfExportService;
  final bool? initialIsDownloaded;
  final VoidCallback? onDownloadChanged;

  @override
  State<GuidelineViewerPage> createState() => _GuidelineViewerPageState();
}

class _GuidelineViewerPageState extends State<GuidelineViewerPage> {
  late final GuidelineStorageService _storageService;
  late final GuidelinePdfExportService _pdfExportService;

  bool _isDownloaded = false;
  DownloadedGuideline? _downloadedInfo;
  bool _isDownloading = false;
  bool _isFavorite = false;
  String? _patientNotes;
  bool _isExportingPdf = false;
  double _fontScale = 1.0;
  final _searchController = TextEditingController();
  String _filterQuery = '';

  final _keyOverview = GlobalKey();
  final _keyNotes = GlobalKey();
  final _keyRecommendations = GlobalKey();
  final _keySections = GlobalKey();
  final _keyCitation = GlobalKey();

  @override
  void initState() {
    super.initState();
    _storageService = widget.storageService ?? GuidelineStorageService();
    _pdfExportService =
        widget.pdfExportService ?? const GuidelinePdfExportService();
    _isDownloaded = widget.initialIsDownloaded ?? false;
    _loadMetadata();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadMetadata() async {
    final id = widget.guideline.id;
    final downloaded = await _storageService.isDownloaded(id);
    DownloadedGuideline? info;
    if (downloaded) {
      info = await _storageService.getDownloadedGuideline(id);
    }
    final favorite = await _storageService.isFavorite(id);
    final notes = await _storageService.getGuidelineNotes(id);

    if (!mounted) return;
    setState(() {
      _isDownloaded = downloaded;
      _downloadedInfo = info;
      _isFavorite = favorite;
      _patientNotes = notes;
    });
  }

  Future<void> _toggleFavorite() async {
    final id = widget.guideline.id;
    final newState = await _storageService.toggleFavorite(id);
    if (!mounted) return;
    setState(() => _isFavorite = newState);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            newState
                ? 'Added "${widget.guideline.shortTitle}" to saved favorites.'
                : 'Removed from saved favorites.',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  Future<void> _toggleDownload() async {
    if (_isDownloading) return;

    if (_isDownloaded) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Remove offline guideline?'),
          content: Text(
            'This will delete the offline copy of "${widget.guideline.shortTitle}" '
            'from your device storage. You can re-download it at any time.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Remove'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      await _storageService.deleteDownloadedGuideline(widget.guideline.id);
      if (!mounted) return;
      setState(() {
        _isDownloaded = false;
        _downloadedInfo = null;
      });
      widget.onDownloadChanged?.call();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Removed offline guideline copy.')),
        );
    } else {
      setState(() => _isDownloading = true);
      try {
        final info = await _storageService.downloadGuideline(widget.guideline);
        if (!mounted) return;
        setState(() {
          _isDownloaded = true;
          _downloadedInfo = info;
          _isDownloading = false;
        });
        widget.onDownloadChanged?.call();
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                'Downloaded "${widget.guideline.shortTitle}" for offline reading.',
              ),
            ),
          );
      } catch (e) {
        if (!mounted) return;
        setState(() => _isDownloading = false);
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text('Could not download the guideline.')),
          );
      }
    }
  }

  Future<void> _openOfficialSource() async {
    try {
      final opened = await launchUrl(
        widget.guideline.webUrl,
        mode: LaunchMode.externalApplication,
      );
      if (!mounted || opened) return;
    } on PlatformException {
      if (!mounted) return;
    } on MissingPluginException {
      if (!mounted) return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Could not open the official website.')),
      );
  }

  void _shareGuideline() {
    final text =
        '${widget.guideline.title}\n'
        'Issued by: ${widget.guideline.publisher} (${widget.guideline.identifier})\n\n'
        '${widget.guideline.summary}\n\n'
        'Official source: ${widget.guideline.webUrl}';
    SharePlus.instance.share(
      ShareParams(
        text: text,
        subject: widget.guideline.shortTitle,
      ),
    );
  }

  Future<void> _exportPdf() async {
    if (_isExportingPdf) return;
    setState(() => _isExportingPdf = true);
    try {
      final file = await _pdfExportService.generateGuidelinePdf(
        guideline: widget.guideline,
        patientNotes: _patientNotes,
      );
      if (!mounted) return;
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text:
              'Evidence-based guideline summary: ${widget.guideline.shortTitle}',
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Could not generate the PDF summary.')),
        );
    } finally {
      if (mounted) {
        setState(() => _isExportingPdf = false);
      }
    }
  }

  Future<void> _editPatientNotes() async {
    final controller = TextEditingController(text: _patientNotes ?? '');
    final updatedText = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Doctor Visit Questions & Notes'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Record questions or personal context to discuss with your healthcare professional regarding this guideline.',
                style: Theme.of(ctx).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('guideline-notes-input'),
                controller: controller,
                maxLines: 5,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText:
                      'e.g. Does my recent LDL test suggest statin therapy? What are the benefits vs side effects?',
                ),
              ),
            ],
          ),
        ),
        actions: [
          if (_patientNotes != null && _patientNotes!.isNotEmpty)
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(''),
              child: const Text('Clear', style: TextStyle(color: Colors.red)),
            ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('Save Note'),
          ),
        ],
      ),
    );

    if (updatedText == null) return;

    await _storageService.saveGuidelineNotes(widget.guideline.id, updatedText);
    if (!mounted) return;
    setState(() {
      _patientNotes = updatedText.trim().isEmpty ? null : updatedText.trim();
    });
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            _patientNotes == null
                ? 'Cleared consultation notes.'
                : 'Saved appointment questions & notes.',
          ),
        ),
      );
  }

  void _showEvidenceGradeExplainer() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final colors = theme.colorScheme;
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.65,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          builder: (sheetContext, scrollController) {
            return ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(
                      Icons.military_tech_outlined,
                      color: colors.primary,
                      size: 24,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Understanding Evidence Grades',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      key: const ValueKey('close-evidence-guide-button'),
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Trusted health agencies evaluate clinical trials and research rigorously before publishing guidelines. Here is what common grading systems mean:',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                _buildGradeCard(
                  theme,
                  colors,
                  title: 'USPSTF Letter Grades (United States)',
                  items: const [
                    'Grade A: High certainty that the net benefit is substantial. (Offer or provide service)',
                    'Grade B: High certainty of moderate benefit or moderate certainty of moderate-to-substantial benefit. (Offer or provide service)',
                    'Grade C: Clinicians may selectively offer service based on professional judgment and patient preferences.',
                    'Grade D: Recommends against service. High/moderate certainty that service has no net benefit or harms outweigh benefits.',
                    'Grade I Statement: Current evidence is insufficient to assess the balance of benefits and harms.',
                  ],
                ),
                const SizedBox(height: 12),
                _buildGradeCard(
                  theme,
                  colors,
                  title: 'NICE Recommendations (United Kingdom)',
                  items: const [
                    'Offer / Recommend: Strong recommendation where evidence clearly demonstrates clinical and cost benefit.',
                    'Consider: Conditional recommendation where benefit exists but choice depends on patient values and individual risk profile.',
                    'Do not offer: Interventions where evidence shows harm or lack of benefit.',
                  ],
                ),
                const SizedBox(height: 12),
                _buildGradeCard(
                  theme,
                  colors,
                  title: 'WHO & GRADE Framework (Global)',
                  items: const [
                    'Strong Recommendation: Most people should receive the recommended course of action.',
                    'Conditional Recommendation: Different choices may be appropriate for different patients; requires shared decision-making.',
                    'Evidence Quality (High, Moderate, Low, Very Low): Reflects confidence that true effect lies close to the estimate.',
                  ],
                ),
                const SizedBox(height: 16),
                FilledButton.tonal(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildGradeCard(
    ThemeData theme,
    ColorScheme colors, {
    required String title,
    required List<String> items,
  }) {
    return Card(
      elevation: 0,
      color: colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: colors.primary,
              ),
            ),
            const SizedBox(height: 8),
            for (final item in items) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• ', style: TextStyle(color: colors.primary)),
                    Expanded(
                      child: Text(
                        item,
                        style: theme.textTheme.bodySmall?.copyWith(
                          height: 1.4,
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
    );
  }

  void _showTableOfContents() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final colors = theme.colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Table of Contents',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('Overview & Clinical Scope'),
                  dense: true,
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _scrollToKey(_keyOverview);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.edit_note),
                  title: const Text('Doctor Appointment Notes'),
                  subtitle: Text(_patientNotes == null
                      ? 'No notes recorded'
                      : 'Notes added'),
                  dense: true,
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _scrollToKey(_keyNotes);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.check_box_outlined),
                  title: Text(
                    'Key Recommendations (${widget.guideline.recommendations.length})',
                  ),
                  dense: true,
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _scrollToKey(_keyRecommendations);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.format_list_bulleted),
                  title: Text(
                    'Guidance Sections (${widget.guideline.sections.length})',
                  ),
                  dense: true,
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _scrollToKey(_keySections);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.menu_book_outlined),
                  title: const Text('Citation & Sources'),
                  dense: true,
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _scrollToKey(_keyCitation);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _scrollToKey(GlobalKey key) {
    final currentContext = key.currentContext;
    if (currentContext != null) {
      Scrollable.ensureVisible(
        currentContext,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final guideline = widget.guideline;

    final query = _filterQuery.trim().toLowerCase();
    final matchingRecommendations = query.isEmpty
        ? guideline.recommendations
        : guideline.recommendations.where((r) {
            return r.title.toLowerCase().contains(query) ||
                r.text.toLowerCase().contains(query) ||
                (r.category?.toLowerCase().contains(query) ?? false);
          }).toList();

    final matchingSections = query.isEmpty
        ? guideline.sections
        : guideline.sections.where((s) {
            return s.title.toLowerCase().contains(query) ||
                s.content.toLowerCase().contains(query);
          }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(guideline.identifier),
        actions: [
          IconButton(
            tooltip: _isFavorite
                ? 'Remove from favorites'
                : 'Save to favorites',
            icon: Icon(
              _isFavorite ? Icons.star : Icons.star_outline,
              color: _isFavorite ? Colors.amber[700] : null,
            ),
            onPressed: _toggleFavorite,
          ),
          IconButton(
            tooltip: _isDownloaded ? 'Remove offline copy' : 'Download guideline',
            icon: _isDownloading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    _isDownloaded
                        ? Icons.offline_pin
                        : Icons.download_for_offline_outlined,
                  ),
            onPressed: _isDownloading ? null : _toggleDownload,
          ),
          PopupMenuButton<String>(
            tooltip: 'More actions',
            icon: const Icon(Icons.more_vert),
            onSelected: (val) {
              if (val == 'toc') _showTableOfContents();
              if (val == 'pdf') _exportPdf();
              if (val == 'share') _shareGuideline();
              if (val == 'notes') _editPatientNotes();
              if (val == 'explainer') _showEvidenceGradeExplainer();
              if (val == 'browser') _openOfficialSource();
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'toc',
                child: Row(
                  children: [
                    Icon(Icons.toc_rounded, size: 20),
                    SizedBox(width: 12),
                    Text('Table of Contents'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'pdf',
                child: Row(
                  children: [
                    _isExportingPdf
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.picture_as_pdf_outlined, size: 20),
                    const SizedBox(width: 12),
                    const Text('Export Doctor Visit PDF'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'notes',
                child: Row(
                  children: [
                    Icon(Icons.edit_note, size: 20),
                    const SizedBox(width: 12),
                    Text('Appointment Questions'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'explainer',
                child: Row(
                  children: [
                    Icon(Icons.military_tech_outlined, size: 20),
                    const SizedBox(width: 12),
                    Text('Evidence Grade Guide'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'share',
                child: Row(
                  children: [
                    Icon(Icons.share_outlined, size: 20),
                    const SizedBox(width: 12),
                    Text('Share Summary Text'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'browser',
                child: Row(
                  children: [
                    Icon(Icons.open_in_new, size: 20),
                    const SizedBox(width: 12),
                    Text('Open in Browser'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
        children: [
          // Header card
          Card(
            key: _keyOverview,
            elevation: 0,
            color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: colors.outlineVariant.withValues(alpha: 0.6),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: colors.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          guideline.identifier,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colors.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: colors.secondaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          guideline.topic.label,
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        guideline.jurisdiction.label,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    guideline.title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: (theme.textTheme.titleLarge?.fontSize ?? 22) *
                          _fontScale,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    guideline.publisher,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Published: ${_formatDate(guideline.publishedDate)}'
                    '${guideline.lastUpdatedDate != null ? ' · Updated: ${_formatDate(guideline.lastUpdatedDate!)}' : ''}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Download / Offline banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _isDownloaded
                  ? colors.primaryContainer.withValues(alpha: 0.35)
                  : colors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isDownloaded
                    ? colors.primary.withValues(alpha: 0.4)
                    : colors.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _isDownloaded ? Icons.check_circle : Icons.cloud_download_outlined,
                  size: 22,
                  color: _isDownloaded ? colors.primary : colors.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isDownloaded
                            ? 'Available offline on this device'
                            : 'Online preview',
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        _isDownloaded
                            ? 'Downloaded ${_formatDate(_downloadedInfo?.downloadedAt ?? DateTime.now())} · ${_downloadedInfo?.formattedSize ?? '${(guideline.fileSizeBytes / 1024).round()} KB'}'
                            : 'Save this guideline locally for offline reading',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  key: const ValueKey('guideline-viewer-download-toggle'),
                  onPressed: _isDownloading ? null : _toggleDownload,
                  icon: _isDownloading
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          _isDownloaded ? Icons.delete_outline : Icons.download,
                          size: 16,
                        ),
                  label: Text(_isDownloaded ? 'Remove' : 'Download'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Patient Consultation Notes & Questions Card
          Card(
            key: _keyNotes,
            elevation: 0,
            color: colors.tertiaryContainer.withValues(alpha: 0.25),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(
                color: colors.tertiary.withValues(alpha: 0.35),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.edit_note_rounded,
                        color: colors.tertiary,
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Doctor Visit Discussion Notes',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colors.onSurface,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: _patientNotes == null ? 'Add notes' : 'Edit notes',
                        icon: Icon(
                          _patientNotes == null
                              ? Icons.add_circle_outline
                              : Icons.edit_outlined,
                          size: 20,
                          color: colors.tertiary,
                        ),
                        onPressed: _editPatientNotes,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (_patientNotes != null && _patientNotes!.isNotEmpty) ...[
                    Text(
                      _patientNotes!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontStyle: FontStyle.italic,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Included in exported Doctor Visit PDF',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ] else ...[
                    Text(
                      'No appointment questions recorded yet. Tap the button to write questions for your next consultation.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Search and font size controls
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const ValueKey('guideline-viewer-search'),
                  controller: _searchController,
                  onChanged: (val) => setState(() => _filterQuery = val),
                  decoration: InputDecoration(
                    hintText: 'Search within guideline...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _filterQuery.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _filterQuery = '');
                            },
                          ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Tooltip(
                message: 'Decrease font size',
                child: IconButton.outlined(
                  icon: const Icon(Icons.text_decrease, size: 18),
                  onPressed: _fontScale > 0.85
                      ? () => setState(() => _fontScale -= 0.15)
                      : null,
                ),
              ),
              Tooltip(
                message: 'Increase font size',
                child: IconButton.outlined(
                  icon: const Icon(Icons.text_increase, size: 18),
                  onPressed: _fontScale < 1.45
                      ? () => setState(() => _fontScale += 0.15)
                      : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Target audience and summary
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Text(
                'Overview & Clinical Scope',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colors.primary,
                ),
              ),
              TextButton.icon(
                onPressed: _showEvidenceGradeExplainer,
                icon: const Icon(Icons.help_outline, size: 16),
                label: const Text('Evidence Guide'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    guideline.summary,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: (theme.textTheme.bodyMedium?.fontSize ?? 14) *
                          _fontScale,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.group_outlined,
                        size: 18,
                        color: colors.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Target population & scope: ${guideline.targetAudience}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: _showEvidenceGradeExplainer,
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.military_tech_outlined,
                            size: 18,
                            color: colors.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Evidence assessment: ${guideline.evidenceGrade} (tap to learn more)',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),

          // Key Recommendations Section
          Text(
            key: _keyRecommendations,
            'Key Recommendations (${matchingRecommendations.length})',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: colors.primary,
            ),
          ),
          const SizedBox(height: 10),
          if (matchingRecommendations.isEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'No recommendations match your search.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            )
          else
            for (final rec in matchingRecommendations)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Card(
                  elevation: 0,
                  color: colors.surfaceContainerLow,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: colors.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (rec.category != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: colors.tertiaryContainer,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  rec.category!,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: colors.onTertiaryContainer,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: colors.secondaryContainer,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                rec.strength,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Text(
                              'Evidence: ${rec.evidenceLevel}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          rec.title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize:
                                (theme.textTheme.titleSmall?.fontSize ?? 14) *
                                    _fontScale,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          rec.text,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontSize:
                                (theme.textTheme.bodyMedium?.fontSize ?? 14) *
                                    _fontScale,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          const SizedBox(height: 18),

          // Structured Full Guidance Sections
          Text(
            key: _keySections,
            'Full Clinical Guidance (${matchingSections.length} sections)',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: colors.primary,
            ),
          ),
          const SizedBox(height: 10),
          if (matchingSections.isEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'No sections match your search.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            )
          else
            for (final section in matchingSections)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          section.title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize:
                                (theme.textTheme.titleSmall?.fontSize ?? 14) *
                                    _fontScale,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          section.content,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontSize:
                                (theme.textTheme.bodyMedium?.fontSize ?? 14) *
                                    _fontScale,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          const SizedBox(height: 16),

          // Source & Citation Card
          Card(
            key: _keyCitation,
            color: colors.surfaceContainerLow,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.menu_book,
                        size: 18,
                        color: colors.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Citation & Provenance',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    guideline.citation,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      TextButton.icon(
                        onPressed: () {
                          Clipboard.setData(
                            ClipboardData(text: guideline.citation),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Citation copied to clipboard.'),
                            ),
                          );
                        },
                        icon: const Icon(Icons.copy, size: 16),
                        label: const Text('Copy citation'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: _openOfficialSource,
                        icon: const Icon(Icons.open_in_new, size: 16),
                        label: const Text('Official site'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Disclaimer banner
          Card(
            color: colors.errorContainer.withValues(alpha: 0.15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: colors.error.withValues(alpha: 0.25),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    color: colors.error,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      guideline.disclaimer,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onErrorContainer,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatDate(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
