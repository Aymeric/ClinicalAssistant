enum GuidelineTopic {
  all,
  publicHealth,
  prevention,
  immunization,
  conditionCare,
  evidenceSearch,
}

extension GuidelineTopicLabel on GuidelineTopic {
  String get label => switch (this) {
        GuidelineTopic.all => 'All topics',
        GuidelineTopic.publicHealth => 'Public health',
        GuidelineTopic.prevention => 'Prevention',
        GuidelineTopic.immunization => 'Immunization',
        GuidelineTopic.conditionCare => 'Condition care',
        GuidelineTopic.evidenceSearch => 'Guideline discovery',
      };
}

enum GuidelineJurisdiction {
  all,
  global,
  unitedKingdom,
  unitedStates,
  australia,
  canada,
  internationalIndex,
}

extension GuidelineJurisdictionLabel on GuidelineJurisdiction {
  String get label => switch (this) {
        GuidelineJurisdiction.all => 'All jurisdictions',
        GuidelineJurisdiction.global => 'Global',
        GuidelineJurisdiction.unitedKingdom => 'United Kingdom',
        GuidelineJurisdiction.unitedStates => 'United States',
        GuidelineJurisdiction.australia => 'Australia',
        GuidelineJurisdiction.canada => 'Canada',
        GuidelineJurisdiction.internationalIndex => 'International index',
      };
}

enum GuidelineSourceStatus { currentPortal, archive, discoveryIndex }

extension GuidelineSourceStatusLabel on GuidelineSourceStatus {
  String get label => switch (this) {
        GuidelineSourceStatus.currentPortal => 'Official source portal',
        GuidelineSourceStatus.archive => 'Published-guideline archive',
        GuidelineSourceStatus.discoveryIndex => 'Discovery index',
      };
}

class GuidelineSource {
  const GuidelineSource({
    required this.id,
    required this.name,
    required this.publisher,
    required this.jurisdiction,
    required this.topics,
    required this.audience,
    required this.description,
    required this.status,
    required this.statusNote,
    required this.url,
    required this.verifiedOn,
  });

  final String id;
  final String name;
  final String publisher;
  final GuidelineJurisdiction jurisdiction;
  final Set<GuidelineTopic> topics;
  final String audience;
  final String description;
  final GuidelineSourceStatus status;
  final String statusNote;
  final Uri url;
  final DateTime verifiedOn;
}

abstract final class GuidelineCatalog {
  static final DateTime lastLinkCheck = DateTime.utc(2026, 9, 29);

  static final List<GuidelineSource> sources = List.unmodifiable([
    GuidelineSource(
      id: 'who-guidelines',
      name: 'WHO guidelines',
      publisher: 'World Health Organization',
      jurisdiction: GuidelineJurisdiction.global,
      topics: {GuidelineTopic.publicHealth, GuidelineTopic.conditionCare},
      audience: 'Global public health and clinical topics',
      description:
          'Browse WHO-issued guidelines and follow each listing to its '
          'publication record for the document, scope, and status details.',
      status: GuidelineSourceStatus.currentPortal,
      statusNote: 'Check the publication record for the latest edition and any '
          'updates or replacement guidance.',
      url: Uri.parse('https://www.who.int/publications/who-guidelines'),
      verifiedOn: lastLinkCheck,
    ),
    GuidelineSource(
      id: 'nice-guidance',
      name: 'NICE guidance',
      publisher: 'National Institute for Health and Care Excellence (NICE)',
      jurisdiction: GuidelineJurisdiction.unitedKingdom,
      topics: {
        GuidelineTopic.publicHealth,
        GuidelineTopic.prevention,
        GuidelineTopic.conditionCare,
      },
      audience: 'Health and care in England',
      description:
          'Search NICE guidance by topic. Recommendations are developed for '
          'the UK health and care context and may not transfer to other '
          'jurisdictions.',
      status: GuidelineSourceStatus.currentPortal,
      statusNote:
          'Check the individual guidance page for publication, review, and '
          'withdrawal status.',
      url: Uri.parse('https://www.nice.org.uk/guidance'),
      verifiedOn: lastLinkCheck,
    ),
    GuidelineSource(
      id: 'uspstf-recommendations',
      name: 'Preventive service recommendations',
      publisher: 'U.S. Preventive Services Task Force (USPSTF)',
      jurisdiction: GuidelineJurisdiction.unitedStates,
      topics: {GuidelineTopic.prevention},
      audience: 'Preventive services in the United States',
      description: 'Browse USPSTF recommendation statements and their evidence '
          'reviews for screening, counseling, and preventive medication '
          'topics.',
      status: GuidelineSourceStatus.currentPortal,
      statusNote:
          'Open the recommendation and linked evidence review to check its '
          'date, grade, and current status.',
      url: Uri.parse(
        'https://www.uspreventiveservicestaskforce.org/uspstf/'
        'recommendation-topics',
      ),
      verifiedOn: lastLinkCheck,
    ),
    GuidelineSource(
      id: 'australian-immunisation',
      name: 'Australian Immunisation Handbook',
      publisher: 'Australian Government Department of Health and Aged Care',
      jurisdiction: GuidelineJurisdiction.australia,
      topics: {GuidelineTopic.immunization, GuidelineTopic.prevention},
      audience: 'Immunisation in the Australian context',
      description:
          'Browse Australian Government immunisation guidance. Advice is '
          'specific to Australian policy and schedules.',
      status: GuidelineSourceStatus.currentPortal,
      statusNote: 'Check the handbook page for the latest chapter revision and '
          'recommendations.',
      url: Uri.parse('https://immunisationhandbook.health.gov.au/contents'),
      verifiedOn: lastLinkCheck,
    ),
    GuidelineSource(
      id: 'canadian-task-force-archive',
      name: 'Canadian Task Force published guidelines',
      publisher: 'Canadian Task Force on Preventive Health Care',
      jurisdiction: GuidelineJurisdiction.canada,
      topics: {GuidelineTopic.prevention},
      audience: 'Historical preventive-care recommendations for Canada',
      description:
          'An archive of published Task Force recommendations. Use it as a '
          'historical source; verify the current Canadian issuing body and '
          'any successor guidance before relying on an older recommendation.',
      status: GuidelineSourceStatus.archive,
      statusNote:
          'Archive: a listing here does not establish that a recommendation '
          'is current.',
      url: Uri.parse(
        'https://canadiantaskforce.ca/guidelines/published-guidelines/',
      ),
      verifiedOn: lastLinkCheck,
    ),
    GuidelineSource(
      id: 'gin-library',
      name: 'International Guidelines Library',
      publisher: 'Guidelines International Network (G-I-N)',
      jurisdiction: GuidelineJurisdiction.internationalIndex,
      topics: {GuidelineTopic.evidenceSearch},
      audience: 'Guideline discovery across organizations and countries',
      description: 'Use this library to discover guidelines from different '
          'organizations, then follow the record to the original developer. '
          'An index entry is not a substitute for checking the source.',
      status: GuidelineSourceStatus.discoveryIndex,
      statusNote:
          'Discovery index: confirm authorship, current status, and reuse '
          'terms with the original publisher.',
      url: Uri.parse('https://g-i-n.net/international-guidelines-library'),
      verifiedOn: lastLinkCheck,
    ),
    GuidelineSource(
      id: 'pubmed-guidelines',
      name: 'PubMed guideline publications',
      publisher: 'U.S. National Library of Medicine (NLM)',
      jurisdiction: GuidelineJurisdiction.internationalIndex,
      topics: {GuidelineTopic.evidenceSearch},
      audience: 'Bibliographic discovery of guideline publications',
      description:
          'Search biomedical citations, including items indexed as practice '
          'guidelines. A citation alone does not establish that a document '
          'is current, endorsed, or available for reuse.',
      status: GuidelineSourceStatus.discoveryIndex,
      statusNote:
          'Bibliographic index: verify status and full-text access with the '
          'issuing organization or publisher.',
      url: Uri.parse(
        'https://pubmed.ncbi.nlm.nih.gov/?term=practice+guideline',
      ),
      verifiedOn: lastLinkCheck,
    ),
  ]);

  static List<GuidelineSource> filter({
    String query = '',
    GuidelineTopic topic = GuidelineTopic.all,
    GuidelineJurisdiction jurisdiction = GuidelineJurisdiction.all,
  }) {
    final normalizedQuery = query.trim().toLowerCase();
    return sources.where((source) {
      final matchesTopic =
          topic == GuidelineTopic.all || source.topics.contains(topic);
      final matchesJurisdiction = jurisdiction == GuidelineJurisdiction.all ||
          source.jurisdiction == jurisdiction;
      final searchable = [
        source.name,
        source.publisher,
        source.jurisdiction.label,
        source.audience,
        source.description,
      ].join(' ').toLowerCase();
      final matchesQuery =
          normalizedQuery.isEmpty || searchable.contains(normalizedQuery);
      return matchesTopic && matchesJurisdiction && matchesQuery;
    }).toList(growable: false);
  }
}
