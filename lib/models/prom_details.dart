import 'health_record.dart';

/// Supported standardized patient-reported survey instruments.
enum PromInstrument {
  phq9(
    'PHQ-9',
    'Patient Health Questionnaire (Depression screening)',
    '44249-1', // LOINC: PHQ-9 quick depression assessment panel
    [
      'Little interest or pleasure in doing things',
      'Feeling down, depressed, or hopeless',
      'Trouble falling or staying asleep, or sleeping too much',
      'Feeling tired or having little energy',
      'Poor appetite or overeating',
      'Feeling bad about yourself — or that you are a failure or have let yourself or your family down',
      'Trouble concentrating on things, such as reading the newspaper or watching television',
      'Moving or speaking so slowly that other people could have noticed, or the opposite — being so fidgety or restless that you have been moving around a lot more than usual',
      'Thoughts that you would be better off dead, or of hurting yourself in some way',
    ],
    [
      PromChoice('Not at all', 0),
      PromChoice('Several days', 1),
      PromChoice('More than half the days', 2),
      PromChoice('Nearly every day', 3),
    ],
  ),
  gad7(
    'GAD-7',
    'Generalized Anxiety Disorder 7-item scale',
    '69737-5', // LOINC: GAD-7 total score
    [
      'Feeling nervous, anxious, or on edge',
      'Not being able to stop or control worrying',
      'Worrying too much about different things',
      'Trouble relaxing',
      'Being so restless that it is hard to sit still',
      'Becoming easily annoyed or irritable',
      'Feeling afraid, as if something awful might happen',
    ],
    [
      PromChoice('Not at all', 0),
      PromChoice('Several days', 1),
      PromChoice('More than half the days', 2),
      PromChoice('Nearly every day', 3),
    ],
  ),
  cat(
    'CAT',
    'COPD Assessment Test',
    '71991-4', // LOINC: COPD Assessment Test
    [
      'Cough frequency (0: Never cough, 5: Cough all the time)',
      'Phlegm / mucus (0: Chest is completely clear, 5: Chest is completely full)',
      'Chest tightness (0: No chest tightness, 5: Very tight chest)',
      'Breathlessness climbing stairs (0: Not breathless, 5: Very breathless)',
      'Activity limitations at home (0: Not limited, 5: Very limited)',
      'Confidence leaving home (0: Confident, 5: Not confident at all)',
      'Sleep quality (0: Sleep soundly, 5: Do not sleep soundly)',
      'Energy level (0: Lots of energy, 5: No energy at all)',
    ],
    [
      PromChoice('0 - None/Minimal', 0),
      PromChoice('1 - Mild', 1),
      PromChoice('2 - Moderate', 2),
      PromChoice('3 - Noticeable', 3),
      PromChoice('4 - Severe', 4),
      PromChoice('5 - Maximum', 5),
    ],
  ),
  mmrc(
    'mMRC',
    'Modified Medical Research Council Dyspnea Scale',
    '72172-0', // LOINC: mMRC Dyspnea Scale
    ['Grade of breathlessness severity during physical exertion'],
    [
      PromChoice('Grade 0: Only breathless with strenuous exercise', 0),
      PromChoice(
        'Grade 1: Short of breath when hurrying or walking up a slight hill',
        1,
      ),
      PromChoice(
        'Grade 2: Walks slower than people of the same age on level ground due to breathlessness',
        2,
      ),
      PromChoice(
        'Grade 3: Stops for breath after walking about 100 yards or after a few minutes on level ground',
        3,
      ),
      PromChoice(
        'Grade 4: Too breathless to leave the house, or breathless when dressing or undressing',
        4,
      ),
    ],
  ),
  sf12(
    'SF-12',
    '12-Item Short Form Health Survey (Physical & Mental summary)',
    '72173-8', // LOINC: SF-12 Health Survey panel
    [
      'In general, would you say your health is excellent, very good, good, fair, or poor?',
      'Moderate activities, such as moving a table, pushing a vacuum cleaner, bowling, or playing golf',
      'Climbing several flights of stairs',
      'Accomplished less than you would like as a result of your physical health',
      'Were limited in the kind of work or other activities as a result of your physical health',
      'Accomplished less than you would like as a result of any emotional problems',
      'Did work or other activities less carefully than usual as a result of any emotional problems',
      'How much did pain interfere with your normal work (including both outside the home and housework)?',
      'Have you felt calm and peaceful?',
      'Did you have a lot of energy?',
      'Have you felt downhearted and blue?',
      'Has your physical health or emotional problems interfered with your social activities?',
    ],
    [
      PromChoice('Excellent / Never / None', 0),
      PromChoice('Very good / Rarely / Slight', 1),
      PromChoice('Good / Sometimes / Moderate', 2),
      PromChoice('Fair / Often / Severe', 3),
      PromChoice('Poor / Always / Extreme', 4),
    ],
  ),
  haq(
    'HAQ',
    'Health Assessment Questionnaire Disability Index',
    '72174-6', // LOINC: HAQ-DI disability score
    [
      'Dressing and grooming (dressing yourself, shampooing hair)',
      'Arising (standing up from an armless chair, getting in/out of bed)',
      'Eating (cutting meat, lifting a full cup/glass to mouth)',
      'Walking (walking outdoors on flat ground, climbing 5 steps)',
      'Hygiene (washing and drying entire body, turning faucets)',
      'Reach (reaching and getting down a 5-pound object from just above head)',
      'Grip (opening car doors, opening previously opened jars)',
      'Activities (running errands and shopping, getting in and out of a car)',
    ],
    [
      PromChoice('Without any difficulty', 0),
      PromChoice('With some difficulty', 1),
      PromChoice('With much difficulty', 2),
      PromChoice('Unable to do', 3),
    ],
  );

  const PromInstrument(
    this.label,
    this.description,
    this.loincCode,
    this.questions,
    this.choices,
  );

  final String label;
  final String description;
  final String loincCode;
  final List<String> questions;
  final List<PromChoice> choices;

  static PromInstrument fromString(String? raw) {
    if (raw == null) return PromInstrument.phq9;
    final clean = raw.toLowerCase().trim();
    if (clean.contains('gad')) return PromInstrument.gad7;
    if (clean.contains('cat')) return PromInstrument.cat;
    if (clean.contains('mmrc')) return PromInstrument.mmrc;
    if (clean.contains('sf-12') || clean.contains('sf12')) {
      return PromInstrument.sf12;
    }
    if (clean.contains('haq')) return PromInstrument.haq;
    return PromInstrument.phq9;
  }

  /// Evaluates a purely descriptive clinical reference label for a total score without automated clinical triage.
  String scoreSummary(int totalScore) {
    switch (this) {
      case PromInstrument.phq9:
        if (totalScore <= 4) return 'Minimal (0-4)';
        if (totalScore <= 9) return 'Mild (5-9)';
        if (totalScore <= 14) return 'Moderate (10-14)';
        if (totalScore <= 19) return 'Moderately severe (15-19)';
        return 'Severe (20-27)';
      case PromInstrument.gad7:
        if (totalScore <= 4) return 'Minimal (0-4)';
        if (totalScore <= 9) return 'Mild (5-9)';
        if (totalScore <= 14) return 'Moderate (10-14)';
        return 'Severe (15-21)';
      case PromInstrument.cat:
        if (totalScore < 10) return 'Low impact (<10)';
        if (totalScore <= 20) return 'Medium impact (10-20)';
        if (totalScore <= 30) return 'High impact (21-30)';
        return 'Very high impact (>30)';
      case PromInstrument.mmrc:
        return 'mMRC Grade $totalScore';
      case PromInstrument.sf12:
        return 'Total survey score: $totalScore';
      case PromInstrument.haq:
        return 'HAQ total index score: $totalScore';
    }
  }
}

class PromChoice {
  const PromChoice(this.text, this.score);
  final String text;
  final int score;
}

/// Structured response record for a completed PROM questionnaire.
class PromResponseDetails {
  const PromResponseDetails({
    required this.instrument,
    required this.totalScore,
    required this.answers,
    this.scoreSummary,
    this.notes,
  });

  static const sourceDataKey = 'promResponse';

  final PromInstrument instrument;
  final int totalScore;
  final List<int> answers;
  final String? scoreSummary;
  final String? notes;

  Map<String, Object?> toJson() => {
    'instrument': instrument.name,
    'totalScore': totalScore,
    'answers': answers,
    if (scoreSummary != null) 'scoreSummary': scoreSummary,
    if (notes != null && notes!.isNotEmpty) 'notes': notes,
  };

  factory PromResponseDetails.fromRecord(HealthRecord record) {
    final raw = record.sourceData?[sourceDataKey];
    if (raw is Map) {
      final answersRaw = raw['answers'];
      final answers = <int>[];
      if (answersRaw is List) {
        for (final item in answersRaw) {
          if (item is num) answers.add(item.toInt());
        }
      }
      final instrument = PromInstrument.fromString(
        raw['instrument']?.toString(),
      );
      final total =
          (raw['totalScore'] as num?)?.toInt() ??
          int.tryParse(record.value) ??
          0;
      return PromResponseDetails(
        instrument: instrument,
        totalScore: total,
        answers: answers,
        scoreSummary:
            raw['scoreSummary']?.toString() ?? instrument.scoreSummary(total),
        notes: raw['notes']?.toString() ?? record.notes,
      );
    }

    final instrument = PromInstrument.fromString(record.name);
    final total = int.tryParse(record.value) ?? 0;
    return PromResponseDetails(
      instrument: instrument,
      totalScore: total,
      answers: const [],
      scoreSummary: instrument.scoreSummary(total),
      notes: record.notes,
    );
  }

  Map<String, Object?> withSourceData(Map<String, Object?>? sourceData) => {
    ...?sourceData,
    sourceDataKey: toJson(),
  };

  /// Serializes into a standard FHIR QuestionnaireResponse resource map.
  Map<String, Object?> toFhirQuestionnaireResponse(HealthRecord record) {
    final id = record.id.replaceAll(RegExp(r'[^A-Za-z0-9\-\.]'), '-');
    return {
      'resourceType': 'QuestionnaireResponse',
      'id': id.isEmpty ? 'prom-response' : id,
      'status': 'completed',
      'questionnaire': 'urn:loinc:${instrument.loincCode}',
      'authored': record.recordedAt.toUtc().toIso8601String(),
      'item': [
        for (
          var i = 0;
          i < answers.length && i < instrument.questions.length;
          i++
        )
          {
            'linkId': 'q${i + 1}',
            'text': instrument.questions[i],
            'answer': [
              {'valueInteger': answers[i]},
            ],
          },
      ],
      if (notes != null && notes!.isNotEmpty)
        'note': [
          {'text': notes},
        ],
    };
  }
}
