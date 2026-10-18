import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'clinical_guideline.dart';
import 'clinical_guideline_catalog.dart';
import 'guideline_source.dart';
import 'guideline_storage_service.dart';
import 'guideline_viewer_page.dart';

enum GuidelineViewMode {
  all,
  guidelines,
  favorites,
  downloaded,
  publishers,
}

extension GuidelineViewModeLabel on GuidelineViewMode {
  String get label => switch (this) {
    GuidelineViewMode.all => 'All',
    GuidelineViewMode.guidelines => 'Guidelines',
    GuidelineViewMode.favorites => 'Favorites',
    GuidelineViewMode.downloaded => 'Downloaded',
    GuidelineViewMode.publishers => 'Directories',
  };
}

class GuidelinesLibraryPage extends StatefulWidget {
  const GuidelinesLibraryPage({
    super.key,
    this.storageService,
    this.initialTopic,
    this.initialQuery,
  });

  final GuidelineStorageService? storageService;
  final GuidelineTopic? initialTopic;
  final String? initialQuery;

  @override
  State<GuidelinesLibraryPage> createState() => _GuidelinesLibraryPageState();
}

class _GuidelinesLibraryPageState extends State<GuidelinesLibraryPage> {
  late final TextEditingController _searchController;
  late final GuidelineStorageService _storageService;
  GuidelineTopic _topic = GuidelineTopic.all;
  GuidelineJurisdiction _jurisdiction = GuidelineJurisdiction.all;
  GuidelineViewMode _viewMode = GuidelineViewMode.all;

  Set<String> _downloadedIds = const {};
  Set<String> _favoriteIds = const {};
  final Set<String> _downloadingIds = {};
  int _totalDownloadedBytes = 0;
  bool _loadingDownloads = true;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialQuery ?? '');
    if (widget.initialTopic != null) {
      _topic = widget.initialTopic!;
    }
    _storageService = widget.storageService ?? GuidelineStorageService();
    _loadStorageData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadStorageData() async {
    final downloaded = await _storageService.getDownloadedGuidelines();
    final favIds = await _storageService.getFavoriteIds();
    final ids = downloaded.map((d) => d.guideline.id).toSet();
    var bytes = 0;
    for (final item in downloaded) {
      bytes += item.fileSizeBytes;
    }
    if (!mounted) return;
    setState(() {
      _downloadedIds = ids;
      _favoriteIds = favIds;
      _totalDownloadedBytes = bytes;
      _loadingDownloads = false;
    });
  }

  Future<void> _toggleFavorite(ClinicalGuideline guideline) async {
    final newState = await _storageService.toggleFavorite(guideline.id);
    await _loadStorageData();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            newState
                ? 'Saved "${guideline.shortTitle}" to favorites.'
                : 'Removed from favorites.',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  Future<void> _downloadGuideline(ClinicalGuideline guideline) async {
    setState(() => _downloadingIds.add(guideline.id));
    try {
      await _storageService.downloadGuideline(guideline);
      await _loadStorageData();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'Downloaded "${guideline.shortTitle}" for offline reading.',
            ),
          ),
        );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Could not download guideline.')),
        );
    } finally {
      if (mounted) {
        setState(() => _downloadingIds.remove(guideline.id));
      }
    }
  }

  Future<void> _removeDownload(ClinicalGuideline guideline) async {
    await _storageService.deleteDownloadedGuideline(guideline.id);
    await _loadStorageData();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'Removed "${guideline.shortTitle}" from offline storage.',
          ),
        ),
      );
  }

  Future<void> _openGuidelineViewer(ClinicalGuideline guideline) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GuidelineViewerPage(
          guideline: guideline,
          storageService: _storageService,
          initialIsDownloaded: _downloadedIds.contains(guideline.id),
          onDownloadChanged: _loadStorageData,
        ),
      ),
    );
    if (mounted) {
      _loadStorageData();
    }
  }

  Future<void> _openSource(GuidelineSource source) async {
    try {
      final opened = await launchUrl(
        source.url,
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
        const SnackBar(content: Text('Could not open the source website.')),
      );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final query = _searchController.text;

    var matchingGuidelines = ClinicalGuidelineCatalog.filter(
      query: query,
      topic: _topic,
      jurisdiction: _jurisdiction,
      downloadedIds: _downloadedIds,
      downloadedOnly: _viewMode == GuidelineViewMode.downloaded,
    );

    if (_viewMode == GuidelineViewMode.favorites) {
      matchingGuidelines = matchingGuidelines
          .where((g) => _favoriteIds.contains(g.id))
          .toList();
    }

    final showGuidelines =
        _viewMode == GuidelineViewMode.all ||
        _viewMode == GuidelineViewMode.guidelines ||
        _viewMode == GuidelineViewMode.favorites ||
        _viewMode == GuidelineViewMode.downloaded;

    final showSources =
        _viewMode == GuidelineViewMode.all ||
        _viewMode == GuidelineViewMode.publishers;

    final sources = showSources
        ? GuidelineCatalog.filter(
            query: query,
            topic: _topic,
            jurisdiction: _jurisdiction,
          )
        : <GuidelineSource>[];

    final hasContent =
        (showGuidelines && matchingGuidelines.isNotEmpty) ||
        (showSources && sources.isNotEmpty);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Guidelines'),
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        children: [
          Text(
            'Evidence-based sources',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Browse guideline publishers and indexes. Each source has its own '
            'scope, review process, and jurisdiction.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colors.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    color: colors.primary,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'This is a curated directory, not a complete or live '
                      'guideline feed. The descriptions are general '
                      'information, not personal medical advice. Check the '
                      'publisher’s page for the current document, intended '
                      'population, local applicability, and reuse terms.',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Search Field
          TextField(
            key: const ValueKey('guideline-search'),
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Search guideline sources',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      key: const ValueKey('guideline-search-clear'),
                      tooltip: 'Clear search',
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                      },
                      icon: const Icon(Icons.close),
                    ),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          // View Mode Selector
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final mode in GuidelineViewMode.values)
                ChoiceChip(
                  key: ValueKey('guideline-view-mode-${mode.name}'),
                  label: Text(
                    switch (mode) {
                      GuidelineViewMode.downloaded
                          when _downloadedIds.isNotEmpty =>
                        '${mode.label} (${_downloadedIds.length})',
                      GuidelineViewMode.favorites
                          when _favoriteIds.isNotEmpty =>
                        '${mode.label} (${_favoriteIds.length})',
                      _ => mode.label,
                    },
                  ),
                  selected: _viewMode == mode,
                  onSelected: (_) => setState(() => _viewMode = mode),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Topic Filter Chips
          Text(
            'Topic',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final topic in GuidelineTopic.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(topic.label),
                      selected: _topic == topic,
                      onSelected: (_) => setState(() => _topic = topic),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Jurisdiction Dropdown
          DropdownButtonFormField<GuidelineJurisdiction>(
            key: const ValueKey('guideline-jurisdiction-filter'),
            initialValue: _jurisdiction,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Jurisdiction',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final jurisdiction in GuidelineJurisdiction.values)
                DropdownMenuItem<GuidelineJurisdiction>(
                  value: jurisdiction,
                  child: Text(jurisdiction.label),
                ),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _jurisdiction = value);
            },
          ),
          const SizedBox(height: 16),

          // Offline downloads & favorites summary card
          if (!_loadingDownloads && (_downloadedIds.isNotEmpty || _favoriteIds.isNotEmpty)) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: colors.primaryContainer.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: colors.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _downloadedIds.isNotEmpty
                        ? Icons.offline_pin
                        : Icons.star,
                    color: colors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${_downloadedIds.length} downloaded (${_formatSize(_totalDownloadedBytes)}) · ${_favoriteIds.length} favorite${_favoriteIds.length == 1 ? '' : 's'}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (_viewMode != GuidelineViewMode.downloaded &&
                      _downloadedIds.isNotEmpty)
                    TextButton(
                      key: const ValueKey('guideline-view-downloads-shortcut'),
                      onPressed: () => setState(
                        () => _viewMode = GuidelineViewMode.downloaded,
                      ),
                      child: const Text('Offline'),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          if (!hasContent)
            _NoGuidelineSources(
              isDownloadedFilter: _viewMode == GuidelineViewMode.downloaded,
              isFavoriteFilter: _viewMode == GuidelineViewMode.favorites,
              onClearFilter: () => setState(() {
                _viewMode = GuidelineViewMode.all;
                _topic = GuidelineTopic.all;
                _jurisdiction = GuidelineJurisdiction.all;
                _searchController.clear();
              }),
            )
          else ...[
            // Publisher Directories Section
            if (showSources && sources.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                '${sources.length} publisher source${sources.length == 1 ? '' : 's'}',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 10),
              for (final source in sources)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _GuidelineSourceCard(
                    source: source,
                    onOpen: () => _openSource(source),
                  ),
                ),
            ],

            // Clinical Guidelines Section
            if (showGuidelines && matchingGuidelines.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: [
                  Text(
                    '${matchingGuidelines.length} clinical guideline${matchingGuidelines.length == 1 ? '' : 's'}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (_viewMode == GuidelineViewMode.all)
                    Text(
                      'Available for offline viewing',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              for (final guideline in matchingGuidelines)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ClinicalGuidelineCard(
                    guideline: guideline,
                    isDownloaded: _downloadedIds.contains(guideline.id),
                    isDownloading: _downloadingIds.contains(guideline.id),
                    isFavorite: _favoriteIds.contains(guideline.id),
                    onView: () => _openGuidelineViewer(guideline),
                    onDownload: () => _downloadGuideline(guideline),
                    onRemove: () => _removeDownload(guideline),
                    onToggleFavorite: () => _toggleFavorite(guideline),
                  ),
                ),
            ],
          ],

          const SizedBox(height: 8),
          Text(
            'Directory links last checked ${_formatDate(GuidelineCatalog.lastLinkCheck)}. '
            'This date reflects a link check, not a clinical update review of '
            'every document on a publisher’s site.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ClinicalGuidelineCard extends StatelessWidget {
  const _ClinicalGuidelineCard({
    required this.guideline,
    required this.isDownloaded,
    required this.isDownloading,
    required this.isFavorite,
    required this.onView,
    required this.onDownload,
    required this.onRemove,
    required this.onToggleFavorite,
  });

  final ClinicalGuideline guideline;
  final bool isDownloaded;
  final bool isDownloading;
  final bool isFavorite;
  final VoidCallback onView;
  final VoidCallback onDownload;
  final VoidCallback onRemove;
  final VoidCallback onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Card(
      key: ValueKey('guideline-card-${guideline.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onView,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
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
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: colors.primaryContainer,
                          borderRadius: BorderRadius.circular(6),
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
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: colors.secondaryContainer,
                          borderRadius: BorderRadius.circular(6),
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
                      if (isDownloaded)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: colors.tertiaryContainer,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.check_circle,
                                size: 13,
                                color: colors.onTertiaryContainer,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Downloaded',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: colors.onTertiaryContainer,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    guideline.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    guideline.publisher,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    guideline.summary,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Key guidance: ${guideline.recommendations.first.text}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.primary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 12, 12),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                Text(
                  isDownloaded
                      ? 'Available offline'
                      : '~${(guideline.fileSizeBytes / 1024).round()} KB download',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                  Wrap(
                    spacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      IconButton(
                        key: ValueKey('guideline-favorite-${guideline.id}'),
                        tooltip: isFavorite
                            ? 'Remove from favorites'
                            : 'Save to favorites',
                        icon: Icon(
                          isFavorite ? Icons.star : Icons.star_border,
                          color: isFavorite ? Colors.amber[700] : null,
                          size: 20,
                        ),
                        onPressed: onToggleFavorite,
                      ),
                      if (isDownloaded)
                        IconButton(
                          key: ValueKey('guideline-delete-${guideline.id}'),
                          tooltip: 'Remove download',
                          icon: const Icon(Icons.delete_outline, size: 18),
                          onPressed: onRemove,
                        )
                      else
                        TextButton.icon(
                          key: ValueKey('guideline-download-${guideline.id}'),
                          onPressed: isDownloading ? null : onDownload,
                          icon: isDownloading
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.download, size: 18),
                          label: const Text('Download'),
                        ),
                      FilledButton.tonal(
                        key: ValueKey('guideline-view-${guideline.id}'),
                        onPressed: onView,
                        child: const Text('View'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
  }

class _GuidelineSourceCard extends StatelessWidget {
  const _GuidelineSourceCard({required this.source, required this.onOpen});

  final GuidelineSource source;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _SourceStatusLabel(status: source.status),
                Text(
                  source.jurisdiction.label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              source.name,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              source.publisher,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 10),
            Text(source.description),
            const SizedBox(height: 10),
            Text(
              'Scope: ${source.audience}',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            Text(
              source.statusNote,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onOpen,
                icon: const Icon(Icons.open_in_new, size: 18),
                label: const Text('Open official source'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SourceStatusLabel extends StatelessWidget {
  const _SourceStatusLabel({required this.status});

  final GuidelineSourceStatus status;

  @override
  Widget build(BuildContext context) {
    final icon = switch (status) {
      GuidelineSourceStatus.currentPortal => Icons.verified_outlined,
      GuidelineSourceStatus.archive => Icons.inventory_2_outlined,
      GuidelineSourceStatus.discoveryIndex => Icons.travel_explore_outlined,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              status.label,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoGuidelineSources extends StatelessWidget {
  const _NoGuidelineSources({
    this.isDownloadedFilter = false,
    this.isFavoriteFilter = false,
    this.onClearFilter,
  });

  final bool isDownloadedFilter;
  final bool isFavoriteFilter;
  final VoidCallback? onClearFilter;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final icon = isFavoriteFilter
        ? Icons.star_border
        : (isDownloadedFilter
            ? Icons.download_for_offline_outlined
            : Icons.search_off);

    final title = isFavoriteFilter
        ? 'No favorite guidelines'
        : (isDownloadedFilter
            ? 'No downloaded guidelines'
            : 'No matching sources');

    final message = isFavoriteFilter
        ? 'Tap the star icon on any guideline to save it to your favorites.'
        : (isDownloadedFilter
            ? 'Tap "Download" on any clinical guideline to read it offline.'
            : 'Try another search or change the filters.');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              icon,
              size: 36,
              color: colors.onSurfaceVariant,
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if ((isDownloadedFilter || isFavoriteFilter) &&
                onClearFilter != null) ...[
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: onClearFilter,
                child: const Text('Browse all guidelines'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _formatDate(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
