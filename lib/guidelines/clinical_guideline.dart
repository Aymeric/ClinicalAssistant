import 'guideline_source.dart';

class GuidelineRecommendation {
  const GuidelineRecommendation({
    required this.id,
    required this.title,
    required this.text,
    required this.strength,
    required this.evidenceLevel,
    this.category,
  });

  final String id;
  final String title;
  final String text;
  final String strength;
  final String evidenceLevel;
  final String? category;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'text': text,
    'strength': strength,
    'evidenceLevel': evidenceLevel,
    if (category != null) 'category': category,
  };

  factory GuidelineRecommendation.fromJson(Map<String, dynamic> json) {
    return GuidelineRecommendation(
      id: json['id'] as String,
      title: json['title'] as String,
      text: json['text'] as String,
      strength: json['strength'] as String,
      evidenceLevel: json['evidenceLevel'] as String,
      category: json['category'] as String?,
    );
  }
}

class GuidelineSection {
  const GuidelineSection({
    required this.id,
    required this.title,
    required this.content,
  });

  final String id;
  final String title;
  final String content;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'content': content,
  };

  factory GuidelineSection.fromJson(Map<String, dynamic> json) {
    return GuidelineSection(
      id: json['id'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
    );
  }
}

class ClinicalGuideline {
  const ClinicalGuideline({
    required this.id,
    required this.title,
    required this.shortTitle,
    required this.identifier,
    required this.publisher,
    required this.sourceId,
    required this.jurisdiction,
    required this.topic,
    required this.publishedDate,
    this.lastUpdatedDate,
    required this.summary,
    required this.targetAudience,
    required this.evidenceGrade,
    required this.recommendations,
    required this.sections,
    required this.webUrl,
    required this.downloadUrl,
    required this.fileSizeBytes,
    required this.citation,
    this.disclaimer =
        'This clinical guideline is intended for informational and educational purposes. '
        'It does not substitute for professional medical judgment, diagnosis, or individualized patient care.',
  });

  final String id;
  final String title;
  final String shortTitle;
  final String identifier;
  final String publisher;
  final String sourceId;
  final GuidelineJurisdiction jurisdiction;
  final GuidelineTopic topic;
  final DateTime publishedDate;
  final DateTime? lastUpdatedDate;
  final String summary;
  final String targetAudience;
  final String evidenceGrade;
  final List<GuidelineRecommendation> recommendations;
  final List<GuidelineSection> sections;
  final Uri webUrl;
  final Uri downloadUrl;
  final int fileSizeBytes;
  final String citation;
  final String disclaimer;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'shortTitle': shortTitle,
    'identifier': identifier,
    'publisher': publisher,
    'sourceId': sourceId,
    'jurisdiction': jurisdiction.name,
    'topic': topic.name,
    'publishedDate': publishedDate.toIso8601String(),
    if (lastUpdatedDate != null)
      'lastUpdatedDate': lastUpdatedDate!.toIso8601String(),
    'summary': summary,
    'targetAudience': targetAudience,
    'evidenceGrade': evidenceGrade,
    'recommendations': recommendations.map((r) => r.toJson()).toList(),
    'sections': sections.map((s) => s.toJson()).toList(),
    'webUrl': webUrl.toString(),
    'downloadUrl': downloadUrl.toString(),
    'fileSizeBytes': fileSizeBytes,
    'citation': citation,
    'disclaimer': disclaimer,
  };

  factory ClinicalGuideline.fromJson(Map<String, dynamic> json) {
    return ClinicalGuideline(
      id: json['id'] as String,
      title: json['title'] as String,
      shortTitle: json['shortTitle'] as String,
      identifier: json['identifier'] as String,
      publisher: json['publisher'] as String,
      sourceId: json['sourceId'] as String,
      jurisdiction: GuidelineJurisdiction.values.byName(
        json['jurisdiction'] as String,
      ),
      topic: GuidelineTopic.values.byName(json['topic'] as String),
      publishedDate: DateTime.parse(json['publishedDate'] as String),
      lastUpdatedDate: json['lastUpdatedDate'] != null
          ? DateTime.parse(json['lastUpdatedDate'] as String)
          : null,
      summary: json['summary'] as String,
      targetAudience: json['targetAudience'] as String,
      evidenceGrade: json['evidenceGrade'] as String,
      recommendations: (json['recommendations'] as List)
          .map(
            (r) => GuidelineRecommendation.fromJson(r as Map<String, dynamic>),
          )
          .toList(),
      sections: (json['sections'] as List)
          .map((s) => GuidelineSection.fromJson(s as Map<String, dynamic>))
          .toList(),
      webUrl: Uri.parse(json['webUrl'] as String),
      downloadUrl: Uri.parse(json['downloadUrl'] as String),
      fileSizeBytes: (json['fileSizeBytes'] as num).toInt(),
      citation: json['citation'] as String,
      disclaimer:
          json['disclaimer'] as String? ??
          'This clinical guideline is intended for informational and educational purposes. '
              'It does not substitute for professional medical judgment, diagnosis, or individualized patient care.',
    );
  }
}

class DownloadedGuideline {
  const DownloadedGuideline({
    required this.guideline,
    required this.downloadedAt,
    required this.localFilePath,
    required this.fileSizeBytes,
  });

  final ClinicalGuideline guideline;
  final DateTime downloadedAt;
  final String localFilePath;
  final int fileSizeBytes;

  String get formattedSize {
    if (fileSizeBytes < 1024) return '$fileSizeBytes B';
    if (fileSizeBytes < 1024 * 1024) {
      return '${(fileSizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Map<String, dynamic> toJson() => {
    'guideline': guideline.toJson(),
    'downloadedAt': downloadedAt.toIso8601String(),
    'localFilePath': localFilePath,
    'fileSizeBytes': fileSizeBytes,
  };

  factory DownloadedGuideline.fromJson(Map<String, dynamic> json) {
    return DownloadedGuideline(
      guideline: ClinicalGuideline.fromJson(
        json['guideline'] as Map<String, dynamic>,
      ),
      downloadedAt: DateTime.parse(json['downloadedAt'] as String),
      localFilePath: json['localFilePath'] as String,
      fileSizeBytes: (json['fileSizeBytes'] as num).toInt(),
    );
  }
}
