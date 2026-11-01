import '../models/health_record.dart';

/// Severity level of a drug or dietary interaction.
enum DrugInteractionSeverity {
  /// Major or critical interaction with high clinical significance.
  high('High', 'Significant safety risk'),

  /// Moderate interaction requiring monitoring or dosage adjustment.
  moderate('Moderate', 'Potential clinical interaction'),

  /// Minor interaction or informational caution.
  low('Minor', 'Informational caution');

  const DrugInteractionSeverity(this.label, this.description);
  final String label;
  final String description;
}

/// Type of interaction.
enum DrugInteractionType {
  /// Interaction between two active medications.
  drugDrug('Drug–Drug'),

  /// Interaction between an active medication and dietary factors or food intake.
  foodDrug('Food–Drug');

  const DrugInteractionType(this.label);
  final String label;
}

/// A structured offline interaction entry between medications or dietary substances.
class DrugInteraction {
  const DrugInteraction({
    required this.id,
    required this.type,
    required this.severity,
    required this.substanceA,
    required this.substanceB,
    required this.title,
    required this.description,
    required this.recommendation,
    this.aliasesA = const [],
    this.aliasesB = const [],
  });

  final String id;
  final DrugInteractionType type;
  final DrugInteractionSeverity severity;

  /// Primary substance or class name (e.g. 'Warfarin', 'ACE Inhibitors').
  final String substanceA;

  /// Secondary substance, drug class, or food item (e.g. 'NSAIDs', 'Grapefruit juice').
  final String substanceB;

  final String title;
  final String description;

  /// Purely descriptive clinical safety prompt.
  final String recommendation;

  /// Normalized aliases / drug brands / ingredient names for substance A.
  final List<String> aliasesA;

  /// Normalized aliases / drug brands / ingredient names for substance B.
  final List<String> aliasesB;
}

/// Represents an alert triggered when an active medication list contains
/// interacting medications or significant food/dietary precautions.
class DetectedDrugInteraction {
  const DetectedDrugInteraction({
    required this.interaction,
    required this.medicationA,
    this.medicationB,
  });

  final DrugInteraction interaction;

  /// The active health record representing medication A.
  final HealthRecord medicationA;

  /// The active health record representing medication B (null for food-drug interactions).
  final HealthRecord? medicationB;

  bool get isFoodDrug => interaction.type == DrugInteractionType.foodDrug;
}

/// Bundled offline open pharmacology interaction dataset and evaluator.
///
/// Curated from consensus open pharmacology data (openFDA, RxNorm, and open DrugBank sources).
/// Maintains strict diagnostic neutrality: alerts are descriptive prompts instructing
/// patients to consult their prescriber or pharmacist, without automated clinical triage.
class DrugInteractionDatabase {
  const DrugInteractionDatabase._();

  /// Standard disclaimer displayed alongside interaction warnings.
  static const clinicalDisclaimer =
      'Descriptive pharmacology reference only. Does not replace professional clinical judgement. Always consult your physician or pharmacist regarding prescription safety and dietary adjustments.';

  /// Bundled interaction catalog.
  static const List<DrugInteraction> interactions = [
    // --- Drug-Drug: High Severity ---
    DrugInteraction(
      id: 'ddi-warfarin-nsaids',
      type: DrugInteractionType.drugDrug,
      severity: DrugInteractionSeverity.high,
      substanceA: 'Warfarin',
      substanceB: 'NSAIDs',
      title: 'Increased Bleeding Risk (Anticoagulant + NSAID)',
      description:
          'Concurrent use of Warfarin (Coumadin) with nonsteroidal anti-inflammatory drugs (NSAIDs) markedly increases gastrointestinal and systemic bleeding risks due to platelet inhibition and gastric mucosal injury.',
      recommendation:
          'Discuss alternative pain or anti-inflammatory options (such as acetaminophen/paracetamol) with your physician or pharmacist.',
      aliasesA: ['warfarin', 'coumadin', 'jantoven'],
      aliasesB: [
        'ibuprofen',
        'advil',
        'motrin',
        'naproxen',
        'aleve',
        'aspirin',
        'meloxicam',
        'celecoxib',
        'celebrex',
        'diclofenac',
        'voltaren',
        'indomethacin',
        'ketorolac',
      ],
    ),
    DrugInteraction(
      id: 'ddi-acei-arb-potassium',
      type: DrugInteractionType.drugDrug,
      severity: DrugInteractionSeverity.high,
      substanceA: 'ACE Inhibitors / ARBs',
      substanceB: 'Potassium Supplements / Potassium-Sparing Diuretics',
      title: 'Hyperkalemia Risk (Renin-Angiotensin Blocker + Potassium)',
      description:
          'Combining ACE inhibitors or ARBs with potassium supplements or potassium-sparing diuretics (e.g. spironolactone) can cause dangerously high serum potassium levels (hyperkalemia), potentially resulting in cardiac arrhythmias.',
      recommendation:
          'Verify serum potassium and kidney function monitoring with your doctor before combining potassium supplements with blood pressure medications.',
      aliasesA: [
        'lisinopril',
        'enalapril',
        'ramipril',
        'benazepril',
        'captopril',
        'losartan',
        'valsartan',
        'candesartan',
        'olmesartan',
        'irbesartan',
        'telmisartan',
      ],
      aliasesB: [
        'potassium',
        'potassium chloride',
        'k-dur',
        'klor-con',
        'spironolactone',
        'aldactone',
        'eplerenone',
        'inspra',
        'triamterene',
        'amiloride',
      ],
    ),
    DrugInteraction(
      id: 'ddi-methotrexate-nsaids',
      type: DrugInteractionType.drugDrug,
      severity: DrugInteractionSeverity.high,
      substanceA: 'Methotrexate',
      substanceB: 'NSAIDs',
      title: 'Methotrexate Toxicity Risk (Methotrexate + NSAID)',
      description:
          'NSAIDs can decrease renal clearance of methotrexate, causing elevated serum levels and heightened risk of severe bone marrow suppression and gastrointestinal toxicity.',
      recommendation:
          'Avoid starting over-the-counter NSAIDs without direct guidance from your rheumatologist or prescribing physician.',
      aliasesA: ['methotrexate', 'trexall', 'rasuvo', 'otrexup'],
      aliasesB: [
        'ibuprofen',
        'advil',
        'motrin',
        'naproxen',
        'aleve',
        'meloxicam',
        'diclofenac',
        'indomethacin',
      ],
    ),
    DrugInteraction(
      id: 'ddi-ssri-tramadol',
      type: DrugInteractionType.drugDrug,
      severity: DrugInteractionSeverity.high,
      substanceA: 'SSRIs / SNRIs',
      substanceB: 'Tramadol',
      title: 'Serotonin Syndrome Caution (SSRI/SNRI + Tramadol)',
      description:
          'Concomitant administration increases the risk of Serotonin Syndrome, characterized by tremor, hyperreflexia, agitation, and diaphoresis.',
      recommendation:
          'Review combined pain and antidepressant therapy with your prescriber and seek prompt medical attention if neuromuscular agitation occurs.',
      aliasesA: [
        'sertraline',
        'zoloft',
        'fluoxetine',
        'prozac',
        'escitalopram',
        'lexapro',
        'citalopram',
        'celexa',
        'paroxetine',
        'paxil',
        'duloxetine',
        'cymbalta',
        'venlafaxine',
        'effexor',
      ],
      aliasesB: ['tramadol', 'ultram', 'conzip'],
    ),
    DrugInteraction(
      id: 'ddi-clopidogrel-omeprazole',
      type: DrugInteractionType.drugDrug,
      severity: DrugInteractionSeverity.moderate,
      substanceA: 'Clopidogrel',
      substanceB: 'Omeprazole / Esomeprazole',
      title: 'Reduced Antiplatelet Efficacy (Clopidogrel + PPI)',
      description:
          'Omeprazole inhibits CYP2C19, significantly reducing the conversion of clopidogrel (Plavix) to its active metabolite, potentially lessening its cardiovascular protection.',
      recommendation:
          'Consult your cardiologist or pharmacist regarding alternative acid-reducing medications (such as pantoprazole or famotidine).',
      aliasesA: ['clopidogrel', 'plavix'],
      aliasesB: ['omeprazole', 'prilosec', 'esomeprazole', 'nexium'],
    ),
    DrugInteraction(
      id: 'ddi-levothyroxine-iron-calcium',
      type: DrugInteractionType.drugDrug,
      severity: DrugInteractionSeverity.moderate,
      substanceA: 'Levothyroxine',
      substanceB: 'Iron / Calcium Supplements',
      title: 'Decreased Thyroid Absorption (Levothyroxine + Mineral Binders)',
      description:
          'Oral iron (ferrous sulfate) or calcium supplements bind levothyroxine in the gastrointestinal tract, substantially reducing thyroid hormone absorption.',
      recommendation:
          'Separate doses of levothyroxine and mineral supplements (iron, calcium, antacids) by at least 4 hours.',
      aliasesA: ['levothyroxine', 'synthroid', 'tirosint', 'levoxyl'],
      aliasesB: [
        'iron',
        'ferrous sulfate',
        'ferrous gluconate',
        'calcium',
        'calcium carbonate',
        'calcium citrate',
        'caltrate',
        'tums',
      ],
    ),
    DrugInteraction(
      id: 'ddi-metformin-contrast-caution',
      type: DrugInteractionType.drugDrug,
      severity: DrugInteractionSeverity.moderate,
      substanceA: 'Metformin',
      substanceB: 'Iodinated Radiocontrast',
      title: 'Metformin & Iodinated Contrast Procedure Caution',
      description:
          'Iodinated contrast dye used in CT scans can transiently impair renal function, leading to potential metformin accumulation and risk of lactic acidosis.',
      recommendation:
          'Notify radiology and your physician prior to contrast imaging; metformin is typically paused 48 hours around iodinated procedures.',
      aliasesA: ['metformin', 'glucophage', 'fortamet', 'glumetza'],
      aliasesB: ['contrast dye', 'iodinated contrast', 'ct contrast'],
    ),

    // --- Food-Drug & Dietary Interactions ---
    DrugInteraction(
      id: 'fdi-statin-grapefruit',
      type: DrugInteractionType.foodDrug,
      severity: DrugInteractionSeverity.moderate,
      substanceA: 'Statins (Simvastatin / Atorvastatin)',
      substanceB: 'Grapefruit & Grapefruit Juice',
      title: 'Dietary Warning: Grapefruit with Statins',
      description:
          'Grapefruit compounds inhibit intestinal CYP3A4 enzymes, markedly elevating blood concentrations of certain statins and increasing the risk of muscle toxicity (myopathy and rhabdomyolysis).',
      recommendation:
          'Limit or avoid grapefruit consumption while taking atorvastatin, simvastatin, or lovastatin. Consult your prescriber for statins unaffected by CYP3A4 (such as rosuvastatin or pravastatin).',
      aliasesA: [
        'atorvastatin',
        'lipitor',
        'simvastatin',
        'zocor',
        'lovastatin',
        'mevacor',
      ],
      aliasesB: ['grapefruit', 'grapefruit juice'],
    ),
    DrugInteraction(
      id: 'fdi-warfarin-vitamin-k',
      type: DrugInteractionType.foodDrug,
      severity: DrugInteractionSeverity.high,
      substanceA: 'Warfarin',
      substanceB: 'High-Vitamin K Foods',
      title: 'Dietary Warning: Vitamin K Consistency with Warfarin',
      description:
          'Large swings in dietary vitamin K (found in dark leafy greens like kale, spinach, collards, and broccoli) directly antagonize warfarin anticoagulation, altering your INR.',
      recommendation:
          'Maintain a steady, consistent intake of vitamin K-rich foods from week to week rather than making sudden large dietary changes. Report dietary shifts to your INR clinic.',
      aliasesA: ['warfarin', 'coumadin', 'jantoven'],
      aliasesB: [
        'vitamin k',
        'kale',
        'spinach',
        'collard greens',
        'broccoli',
        'brussels sprouts',
      ],
    ),
    DrugInteraction(
      id: 'fdi-acei-high-potassium-food',
      type: DrugInteractionType.foodDrug,
      severity: DrugInteractionSeverity.moderate,
      substanceA: 'ACE Inhibitors / ARBs',
      substanceB: 'Potassium Salt Substitutes',
      title: 'Dietary Warning: Salt Substitutes with ACE Inhibitors / ARBs',
      description:
          'Salt substitutes (e.g. NoSalt, Nu-Salt) replace sodium chloride with potassium chloride. When combined with medications that retain potassium (ACE inhibitors, ARBs, spironolactone), high potassium levels may develop.',
      recommendation:
          'Avoid salt substitutes containing potassium chloride unless specifically approved by your physician.',
      aliasesA: [
        'lisinopril',
        'enalapril',
        'ramipril',
        'benazepril',
        'losartan',
        'valsartan',
        'candesartan',
        'olmesartan',
        'spironolactone',
      ],
      aliasesB: [
        'salt substitute',
        'potassium salt',
        'nosalt',
        'nu-salt',
        'potassium chloride',
      ],
    ),
    DrugInteraction(
      id: 'fdi-fluoroquinolone-dairy',
      type: DrugInteractionType.foodDrug,
      severity: DrugInteractionSeverity.moderate,
      substanceA: 'Fluoroquinolones / Tetracyclines',
      substanceB: 'Dairy & Calcium-Fortified Foods',
      title: 'Dietary Warning: Dairy & Calcium with Antibiotics',
      description:
          'Calcium in milk, cheese, yogurt, and fortified juices binds to fluoroquinolone and tetracycline antibiotics in the stomach, dramatically decreasing antibiotic absorption.',
      recommendation:
          'Take your antibiotic at least 2 hours before or 4 to 6 hours after consuming dairy products or calcium-fortified beverages.',
      aliasesA: [
        'ciprofloxacin',
        'cipro',
        'levofloxacin',
        'levaquin',
        'doxycycline',
        'vibramycin',
        'minocycline',
        'tetracycline',
      ],
      aliasesB: [
        'dairy',
        'milk',
        'yogurt',
        'cheese',
        'calcium fortified juice',
      ],
    ),
    DrugInteraction(
      id: 'fdi-metronidazole-alcohol',
      type: DrugInteractionType.foodDrug,
      severity: DrugInteractionSeverity.high,
      substanceA: 'Metronidazole',
      substanceB: 'Alcohol',
      title: 'Dietary Warning: Alcohol Avoidance with Metronidazole',
      description:
          'Combining metronidazole (Flagyl) with alcohol triggers a disulfiram-like reaction causing severe nausea, vomiting, facial flushing, tachycardia, and throbbing headache.',
      recommendation:
          'Completely avoid alcohol during metronidazole treatment and for at least 48 to 72 hours after completing the course.',
      aliasesA: ['metronidazole', 'flagyl'],
      aliasesB: ['alcohol', 'wine', 'beer', 'liquor', 'ethanol'],
    ),
  ];

  /// Tests if a medication record's name or code matches any alias in the provided list.
  static bool _matchesSubstance(HealthRecord record, List<String> aliases) {
    final lowerName = record.name.toLowerCase();
    final lowerVal = record.value.toLowerCase();
    for (final alias in aliases) {
      final clean = alias.toLowerCase().trim();
      if (clean.isEmpty) continue;
      // Word boundary or substring check
      if (lowerName.contains(clean) || lowerVal.contains(clean)) {
        return true;
      }
    }
    return false;
  }

  /// Evaluates an active list of medication health records and returns all detected
  /// drug-drug and food-drug interaction safety cautions.
  static List<DetectedDrugInteraction> evaluateInteractions(
    List<HealthRecord> activeMedications,
  ) {
    if (activeMedications.isEmpty) return const [];

    final results = <DetectedDrugInteraction>[];
    final detectedDrugPairKeys = <String>{};

    for (final interaction in interactions) {
      if (interaction.type == DrugInteractionType.drugDrug) {
        // Find matching pairs among active medications
        for (var i = 0; i < activeMedications.length; i++) {
          final medA = activeMedications[i];
          final matchesA = _matchesSubstance(medA, interaction.aliasesA);

          for (var j = 0; j < activeMedications.length; j++) {
            if (i == j) continue;
            final medB = activeMedications[j];
            final matchesB = _matchesSubstance(medB, interaction.aliasesB);

            if (matchesA && matchesB) {
              // Deduplicate unordered pair
              final ids = [medA.id, medB.id]..sort();
              final pairKey = '${interaction.id}_${ids[0]}_${ids[1]}';
              if (!detectedDrugPairKeys.contains(pairKey)) {
                detectedDrugPairKeys.add(pairKey);
                results.add(
                  DetectedDrugInteraction(
                    interaction: interaction,
                    medicationA: medA,
                    medicationB: medB,
                  ),
                );
              }
            }
          }
        }
      } else if (interaction.type == DrugInteractionType.foodDrug) {
        // For food-drug interactions, any matching active medication triggers the dietary caution
        for (final med in activeMedications) {
          if (_matchesSubstance(med, interaction.aliasesA)) {
            final key = '${interaction.id}_${med.id}';
            if (!detectedDrugPairKeys.contains(key)) {
              detectedDrugPairKeys.add(key);
              results.add(
                DetectedDrugInteraction(
                  interaction: interaction,
                  medicationA: med,
                ),
              );
            }
          }
        }
      }
    }

    // Sort by severity (high first), then title
    results.sort((a, b) {
      final sevCompare = a.interaction.severity.index.compareTo(
        b.interaction.severity.index,
      );
      if (sevCompare != 0) return sevCompare;
      return a.interaction.title.compareTo(b.interaction.title);
    });

    return results;
  }
}
