import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'guideline_source.dart';

class GuidelinesLibraryPage extends StatefulWidget {
  const GuidelinesLibraryPage({super.key});

  @override
  State<GuidelinesLibraryPage> createState() => _GuidelinesLibraryPageState();
}

class _GuidelinesLibraryPageState extends State<GuidelinesLibraryPage> {
  final _searchController = TextEditingController();
  GuidelineTopic _topic = GuidelineTopic.all;
  GuidelineJurisdiction _jurisdiction = GuidelineJurisdiction.all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    final sources = GuidelineCatalog.filter(
      query: _searchController.text,
      topic: _topic,
      jurisdiction: _jurisdiction,
    );

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
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Browse guideline publishers and indexes. Each source has its own '
            'scope, review process, and jurisdiction.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                    color: Theme.of(context).colorScheme.primary,
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
          Text(
            'Topic',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
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
          const SizedBox(height: 20),
          Text(
            '${sources.length} ${sources.length == 1 ? 'source' : 'sources'}',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          if (sources.isEmpty)
            const _NoGuidelineSources()
          else
            for (final source in sources)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _GuidelineSourceCard(
                  source: source,
                  onOpen: () => _openSource(source),
                ),
              ),
          const SizedBox(height: 8),
          Text(
            'Directory links last checked ${_formatDate(GuidelineCatalog.lastLinkCheck)}. '
            'This date reflects a link check, not a clinical update review of '
            'every document on a publisher’s site.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
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
          Text(
            status.label,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _NoGuidelineSources extends StatelessWidget {
  const _NoGuidelineSources();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.search_off,
              size: 32,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 10),
            const Text(
              'No matching sources',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Try another search or change the filters.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
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
