import 'clinical_guideline.dart';
import 'guideline_source.dart';

abstract final class ClinicalGuidelineCatalog {
  static final List<ClinicalGuideline> guidelines = List.unmodifiable([
    ClinicalGuideline(
      id: 'nice-ng136-hypertension',
      title: 'Hypertension in adults: diagnosis and management',
      shortTitle: 'Hypertension in adults',
      identifier: 'NICE NG136',
      publisher: 'National Institute for Health and Care Excellence (NICE)',
      sourceId: 'nice-guidance',
      jurisdiction: GuidelineJurisdiction.unitedKingdom,
      topic: GuidelineTopic.conditionCare,
      publishedDate: DateTime.utc(2019, 8, 28),
      lastUpdatedDate: DateTime.utc(2023, 11, 20),
      summary:
          'Evidence-based guidance on diagnosing and managing primary hypertension '
          'in adults in primary and secondary healthcare settings.',
      targetAudience:
          'Healthcare professionals, commissioners, and adults with suspected '
          'or diagnosed primary hypertension.',
      evidenceGrade: 'NICE Guideline (High-certainty evidence synthesis)',
      fileSizeBytes: 284000,
      webUrl: Uri.parse('https://www.nice.org.uk/guidance/ng136'),
      downloadUrl: Uri.parse('https://www.nice.org.uk/guidance/ng136'),
      citation:
          'National Institute for Health and Care Excellence. (2019). '
          'Hypertension in adults: diagnosis and management (NICE Guideline NG136). '
          'London: NICE.',
      recommendations: const [
        GuidelineRecommendation(
          id: 'nice-ng136-rec-1',
          title: 'Confirm clinic BP with out-of-office monitoring',
          text:
              'If clinic blood pressure is 140/90 mmHg or higher, offer ambulatory '
              'blood pressure monitoring (ABPM) or home blood pressure monitoring '
              '(HBPM) to confirm the diagnosis of hypertension.',
          strength: 'Strong recommendation',
          evidenceLevel: 'High',
          category: 'Diagnosis',
        ),
        GuidelineRecommendation(
          id: 'nice-ng136-rec-2',
          title: 'Cardiovascular risk and target organ assessment',
          text:
              'Assess cardiovascular risk using a validated formal risk calculator '
              '(such as QRISK) for all adults with stage 1 hypertension, and test '
              'for target organ damage (urine albumin:creatinine ratio, ECG, bloods).',
          strength: 'Strong recommendation',
          evidenceLevel: 'High',
          category: 'Assessment',
        ),
        GuidelineRecommendation(
          id: 'nice-ng136-rec-3',
          title: 'Antihypertensive drug treatment threshold',
          text:
              'Offer antihypertensive drug treatment to people aged under 80 with '
              'stage 1 hypertension who have target organ damage, established CVD, '
              'renal disease, diabetes, or a 10-year CVD risk of 10% or higher.',
          strength: 'Strong recommendation',
          evidenceLevel: 'High',
          category: 'Treatment',
        ),
        GuidelineRecommendation(
          id: 'nice-ng136-rec-4',
          title: 'Blood pressure treatment targets',
          text:
              'Aim for clinic blood pressure below 140/90 mmHg (and ABPM/HBPM daytime '
              'average below 135/85 mmHg) for adults aged under 80. Aim for clinic '
              'BP below 150/90 mmHg for adults aged 80 and over.',
          strength: 'Strong recommendation',
          evidenceLevel: 'Moderate',
          category: 'Targets',
        ),
        GuidelineRecommendation(
          id: 'nice-ng136-rec-5',
          title: 'Lifestyle advice across all stages',
          text:
              'Offer lifestyle advice regarding dietary sodium reduction, exercise, '
              'healthy weight, alcohol moderation, and smoking cessation at diagnosis '
              'and at periodic reviews.',
          strength: 'Strong recommendation',
          evidenceLevel: 'High',
          category: 'Lifestyle',
        ),
      ],
      sections: const [
        GuidelineSection(
          id: 'nice-ng136-sec-1',
          title: '1. Diagnostic Criteria and Measurement',
          content:
              'Ensure standardized blood pressure measurement technique: seated quietly '
              'for 5 minutes with arm supported. If initial clinic BP is 140/90 mmHg or '
              'higher, take a second recording; if different, take a third and record the '
              'lowest reading. Confirm suspected hypertension with daytime ABPM or 4- to '
              '7-day HBPM before prescribing ongoing pharmacological treatment.',
        ),
        GuidelineSection(
          id: 'nice-ng136-sec-2',
          title: '2. Stages of Hypertension',
          content:
              'Stage 1: Clinic BP 140/90 to 159/99 mmHg and ABPM/HBPM daytime average 135/85 '
              'to 149/94 mmHg.\n'
              'Stage 2: Clinic BP 160/100 to 179/119 mmHg and ABPM/HBPM daytime average 150/95 '
              'mmHg or higher.\n'
              'Stage 3 (Severe): Clinic systolic BP 180 mmHg or higher, or clinic diastolic '
              'BP 120 mmHg or higher. Check for emergency signs of retinal haemorrhage, '
              'papilloedema, or acute heart failure requiring same-day specialist referral.',
        ),
        GuidelineSection(
          id: 'nice-ng136-sec-3',
          title: '3. Treatment Steps and Medication Classes',
          content:
              'Step 1: Offer an ACE inhibitor or angiotensin II receptor blocker (ARB) to '
              'adults aged under 55 who are not of Black African or African-Caribbean family '
              'origin. Offer a calcium-channel blocker (CCB) to adults aged 55 and over, and '
              'to adults of Black African or African-Caribbean family origin of any age.\n'
              'Step 2: Combine an ACE inhibitor or ARB with a CCB or a thiazide-like diuretic '
              '(indapamide preferred).\n'
              'Step 3: Triple therapy with ACE-i/ARB + CCB + thiazide-like diuretic.\n'
              'Step 4: Resistant hypertension review and low-dose spironolactone consideration.',
        ),
        GuidelineSection(
          id: 'nice-ng136-sec-4',
          title: '4. Ongoing Monitoring and Patient Support',
          content:
              'Provide an annual review of blood pressure, cardiovascular risk factors, and '
              'kidney function (eGFR and electrolytes). Address adherence non-judgmentally, '
              'and encourage patient-led home blood pressure logs.',
        ),
      ],
    ),
    ClinicalGuideline(
      id: 'nice-ng28-diabetes',
      title: 'Type 2 diabetes in adults: management',
      shortTitle: 'Type 2 diabetes management',
      identifier: 'NICE NG28',
      publisher: 'National Institute for Health and Care Excellence (NICE)',
      sourceId: 'nice-guidance',
      jurisdiction: GuidelineJurisdiction.unitedKingdom,
      topic: GuidelineTopic.conditionCare,
      publishedDate: DateTime.utc(2015, 12, 2),
      lastUpdatedDate: DateTime.utc(2024, 2, 15),
      summary:
          'Evidence-based recommendations on patient education, dietary advice, '
          'blood glucose monitoring, and pharmacological treatment for type 2 diabetes.',
      targetAudience:
          'Adults with type 2 diabetes, general practitioners, diabetes educators, '
          'and endocrinologists.',
      evidenceGrade: 'NICE Guideline (High-certainty evidence)',
      fileSizeBytes: 310000,
      webUrl: Uri.parse('https://www.nice.org.uk/guidance/ng28'),
      downloadUrl: Uri.parse('https://www.nice.org.uk/guidance/ng28'),
      citation:
          'National Institute for Health and Care Excellence. (2015). '
          'Type 2 diabetes in adults: management (NICE Guideline NG28). '
          'London: NICE.',
      recommendations: const [
        GuidelineRecommendation(
          id: 'nice-ng28-rec-1',
          title: 'Individualised HbA1c targets',
          text:
              'Agree an individualised HbA1c target with each patient. Aim for '
              '48 mmol/mol (6.5%) with lifestyle or single drug not associated with '
              'hypoglycaemia. Aim for 53 mmol/mol (7.0%) with therapies that can cause '
              'hypoglycaemia.',
          strength: 'Strong recommendation',
          evidenceLevel: 'High',
          category: 'Targets',
        ),
        GuidelineRecommendation(
          id: 'nice-ng28-rec-2',
          title: 'First-line pharmacological treatment',
          text:
              'Offer standard-release metformin as initial drug treatment unless '
              'contraindicated or not tolerated. Gradually titrate the dose over several '
              'weeks to reduce gastrointestinal side effects.',
          strength: 'Strong recommendation',
          evidenceLevel: 'High',
          category: 'Pharmacotherapy',
        ),
        GuidelineRecommendation(
          id: 'nice-ng28-rec-3',
          title: 'Cardiovascular protection with SGLT2 inhibitors',
          text:
              'Introduce an SGLT2 inhibitor with proven cardiovascular benefit for adults '
              'with chronic heart failure or established atherosclerotic cardiovascular disease.',
          strength: 'Strong recommendation',
          evidenceLevel: 'High',
          category: 'Cardiovascular',
        ),
        GuidelineRecommendation(
          id: 'nice-ng28-rec-4',
          title: 'Structured diabetes education',
          text:
              'Offer structured education to every adult with type 2 diabetes and their '
              'family or carers at diagnosis, with an annual refresher.',
          strength: 'Strong recommendation',
          evidenceLevel: 'Moderate',
          category: 'Education',
        ),
      ],
      sections: const [
        GuidelineSection(
          id: 'nice-ng28-sec-1',
          title: '1. Structured Education and Self-Care',
          content:
              'Ensure all newly diagnosed individuals receive evidence-based structured '
              'education focusing on diet, carbohydrate awareness, physical activity, '
              'self-monitoring, and complication risk awareness.',
        ),
        GuidelineSection(
          id: 'nice-ng28-sec-2',
          title: '2. Glucose Targets and HbA1c Monitoring',
          content:
              'Measure HbA1c at 3- to 6-month intervals until blood glucose control is '
              'stable on unchanging therapy, then at 6-month intervals. Relax targets '
              'in individuals with advanced frailty, short life expectancy, or high risk '
              'of severe hypoglycaemia.',
        ),
        GuidelineSection(
          id: 'nice-ng28-sec-3',
          title: '3. Dual and Triple Therapy Escalation',
          content:
              'If HbA1c rises above the target, consider dual therapy adding an SGLT2 '
              'inhibitor, DPP-4 inhibitor, sulfonylurea, or pioglitazone based on renal '
              'function, cardiac comorbidities, and weight management goals.',
        ),
      ],
    ),
    ClinicalGuideline(
      id: 'uspstf-hypertension-screening',
      title: 'Screening for Hypertension in Adults: Recommendation Statement',
      shortTitle: 'Hypertension screening in adults',
      identifier: 'USPSTF Recommendation (Grade A)',
      publisher: 'U.S. Preventive Services Task Force (USPSTF)',
      sourceId: 'uspstf-recommendations',
      jurisdiction: GuidelineJurisdiction.unitedStates,
      topic: GuidelineTopic.prevention,
      publishedDate: DateTime.utc(2021, 4, 27),
      summary:
          'The USPSTF recommends screening for hypertension in adults aged 18 years '
          'or older with office blood pressure measurement, and confirming elevated '
          'readings outside the clinical setting before starting treatment.',
      targetAudience:
          'Primary care clinicians and asymptomatic adults aged 18 years or older '
          'without prior diagnosed hypertension.',
      evidenceGrade: 'Grade A (Substantial net benefit)',
      fileSizeBytes: 242000,
      webUrl: Uri.parse(
        'https://www.uspreventiveservicestaskforce.org/uspstf/recommendation/hypertension-in-adults-screening',
      ),
      downloadUrl: Uri.parse(
        'https://www.uspreventiveservicestaskforce.org/uspstf/recommendation/hypertension-in-adults-screening',
      ),
      citation:
          'US Preventive Services Task Force. (2021). Screening for Hypertension '
          'in Adults: US Preventive Services Task Force Recommendation Statement. '
          'JAMA, 325(16):1650–1656.',
      recommendations: const [
        GuidelineRecommendation(
          id: 'uspstf-htn-rec-1',
          title: 'Universal screening for all adults 18+',
          text:
              'Screen all adults aged 18 years or older for hypertension with office '
              'blood pressure measurement.',
          strength: 'Grade A recommendation',
          evidenceLevel: 'High certainty',
          category: 'Screening',
        ),
        GuidelineRecommendation(
          id: 'uspstf-htn-rec-2',
          title: 'Out-of-office confirmation before treatment',
          text:
              'Obtain blood pressure measurements outside the clinical setting (such as '
              'ambulatory blood pressure monitoring or home blood pressure monitoring) '
              'for diagnostic confirmation before starting treatment.',
          strength: 'Grade A recommendation',
          evidenceLevel: 'High certainty',
          category: 'Confirmation',
        ),
        GuidelineRecommendation(
          id: 'uspstf-htn-rec-3',
          title: 'Annual rescreening for higher-risk adults',
          text:
              'Rescreen annually adults aged 40 years or older and adults with increased '
              'risk (such as Black individuals, high-normal BP 130-139/85-89 mmHg, or '
              'overweight/obesity). Rescreen every 3 to 5 years for adults aged 18 to 39 '
              'with normal BP and no risk factors.',
          strength: 'Grade A recommendation',
          evidenceLevel: 'Moderate certainty',
          category: 'Intervals',
        ),
      ],
      sections: const [
        GuidelineSection(
          id: 'uspstf-htn-sec-1',
          title: '1. Rationale and Net Benefit',
          content:
              'Hypertension is a prevalent, asymptomatic condition and a major '
              'contributor to myocardial infarction, stroke, heart failure, and chronic '
              'kidney disease. Early identification and evidence-based pharmacologic and '
              'lifestyle interventions produce substantial reductions in cardiovascular '
              'events and all-cause mortality.',
        ),
        GuidelineSection(
          id: 'uspstf-htn-sec-2',
          title: '2. Office Measurement Protocol',
          content:
              'Clinicians should use calibrated manual or automated sphygmomanometers '
              'with an appropriately sized cuff. The patient should sit quietly with back '
              'supported and feet on the floor for at least 5 minutes before reading.',
        ),
        GuidelineSection(
          id: 'uspstf-htn-sec-3',
          title: '3. Out-of-Office Confirmation Rationale',
          content:
              'Up to 15% to 30% of patients with elevated office readings experience '
              'white-coat hypertension. Out-of-office measurement prevents unnecessary '
              'lifelong medical therapy while accurately diagnosing sustained hypertension.',
        ),
      ],
    ),
    ClinicalGuideline(
      id: 'uspstf-diabetes-screening',
      title:
          'Screening for Prediabetes and Type 2 Diabetes: Recommendation Statement',
      shortTitle: 'Prediabetes and diabetes screening',
      identifier: 'USPSTF Recommendation (Grade B)',
      publisher: 'U.S. Preventive Services Task Force (USPSTF)',
      sourceId: 'uspstf-recommendations',
      jurisdiction: GuidelineJurisdiction.unitedStates,
      topic: GuidelineTopic.prevention,
      publishedDate: DateTime.utc(2021, 8, 24),
      summary:
          'Recommends screening for prediabetes and type 2 diabetes in nonpregnant '
          'adults aged 35 to 70 years who are overweight or obese.',
      targetAudience:
          'Primary care clinicians and asymptomatic adults aged 35 to 70 with overweight '
          'or obesity.',
      evidenceGrade: 'Grade B (Moderate net benefit)',
      fileSizeBytes: 228000,
      webUrl: Uri.parse(
        'https://www.uspreventiveservicestaskforce.org/uspstf/recommendation/screening-for-prediabetes-and-type-2-diabetes',
      ),
      downloadUrl: Uri.parse(
        'https://www.uspreventiveservicestaskforce.org/uspstf/recommendation/screening-for-prediabetes-and-type-2-diabetes',
      ),
      citation:
          'US Preventive Services Task Force. (2021). Screening for Prediabetes '
          'and Type 2 Diabetes: US Preventive Services Task Force Recommendation Statement. '
          'JAMA, 326(8):736–743.',
      recommendations: const [
        GuidelineRecommendation(
          id: 'uspstf-dm-rec-1',
          title: 'Screening adults aged 35 to 70 with overweight or obesity',
          text:
              'Screen for prediabetes and type 2 diabetes in nonpregnant adults aged 35 '
              'to 70 years who have overweight or obesity (BMI ≥ 25 kg/m², or ≥ 23 kg/m² '
              'for Asian American individuals).',
          strength: 'Grade B recommendation',
          evidenceLevel: 'Moderate certainty',
          category: 'Screening',
        ),
        GuidelineRecommendation(
          id: 'uspstf-dm-rec-2',
          title: 'Preventive lifestyle counseling for prediabetes',
          text:
              'Offer or refer patients identified with prediabetes to effective preventive '
              'interventions such as intensive lifestyle and physical activity programs.',
          strength: 'Grade B recommendation',
          evidenceLevel: 'High certainty',
          category: 'Intervention',
        ),
        GuidelineRecommendation(
          id: 'uspstf-dm-rec-3',
          title: '3-year rescreening frequency',
          text:
              'Rescreen every 3 years for adults with normal initial screening results, '
              'or more frequently if weight increases or additional metabolic risk factors arise.',
          strength: 'Grade B recommendation',
          evidenceLevel: 'Moderate certainty',
          category: 'Intervals',
        ),
      ],
      sections: const [
        GuidelineSection(
          id: 'uspstf-dm-sec-1',
          title: '1. Screening Tests and Thresholds',
          content:
              'Screening tests include fasting plasma glucose (FPG ≥ 100 mg/dL for '
              'prediabetes; ≥ 126 mg/dL for diabetes), HbA1c (5.7% to 6.4% for prediabetes; '
              '≥ 6.5% for diabetes), or 2-hour oral glucose tolerance test. Repeat testing '
              'on a subsequent day is recommended to confirm asymptomatic diagnosis.',
        ),
        GuidelineSection(
          id: 'uspstf-dm-sec-2',
          title: '2. Clinical Benefits of Early Detection',
          content:
              'Lifestyle interventions targeting at least 5% to 7% weight loss and 150 '
              'minutes of moderate activity per week significantly reduce the incidence of '
              'progression to type 2 diabetes and improve cardiometabolic risk profiles.',
        ),
      ],
    ),
    ClinicalGuideline(
      id: 'uspstf-statin-cvd',
      title:
          'Statin Use for the Primary Prevention of Cardiovascular Disease in Adults',
      shortTitle: 'Statin for primary CVD prevention',
      identifier: 'USPSTF Recommendation (Grade B)',
      publisher: 'U.S. Preventive Services Task Force (USPSTF)',
      sourceId: 'uspstf-recommendations',
      jurisdiction: GuidelineJurisdiction.unitedStates,
      topic: GuidelineTopic.prevention,
      publishedDate: DateTime.utc(2022, 8, 23),
      summary:
          'Recommends statin prescription for primary prevention of cardiovascular '
          'disease in adults aged 40 to 75 years who have 1 or more CVD risk factors '
          'and an estimated 10-year CVD risk of 10% or greater.',
      targetAudience:
          'Adults aged 40 to 75 years with no history of cardiovascular disease.',
      evidenceGrade: 'Grade B (Moderate net benefit)',
      fileSizeBytes: 236000,
      webUrl: Uri.parse(
        'https://www.uspreventiveservicestaskforce.org/uspstf/recommendation/statin-use-in-adults-preventive-medication',
      ),
      downloadUrl: Uri.parse(
        'https://www.uspreventiveservicestaskforce.org/uspstf/recommendation/statin-use-in-adults-preventive-medication',
      ),
      citation:
          'US Preventive Services Task Force. (2022). Statin Use for the Primary '
          'Prevention of Cardiovascular Disease in Adults: US Preventive Services '
          'Task Force Recommendation Statement. JAMA, 328(8):745–753.',
      recommendations: const [
        GuidelineRecommendation(
          id: 'uspstf-statin-rec-1',
          title: 'Statin initiation for 10-year CVD risk ≥ 10%',
          text:
              'Prescribe a statin for primary prevention of CVD in adults aged 40 to 75 '
              'years who have 1 or more CVD risk factors (dyslipidemia, diabetes, '
              'hypertension, or smoking) and calculated 10-year CVD event risk ≥ 10%.',
          strength: 'Grade B recommendation',
          evidenceLevel: 'Moderate certainty',
          category: 'Prevention',
        ),
        GuidelineRecommendation(
          id: 'uspstf-statin-rec-2',
          title: 'Individualised decision-making for 7.5% to < 10% risk',
          text:
              'Selectively offer a statin for adults aged 40 to 75 years with 1 or more '
              'risk factors and a 10-year risk of 7.5% to < 10%, weighing individual '
              'preference, potential absolute benefit, and adherence considerations.',
          strength: 'Grade C recommendation',
          evidenceLevel: 'Moderate certainty',
          category: 'Shared Decision',
        ),
      ],
      sections: const [
        GuidelineSection(
          id: 'uspstf-statin-sec-1',
          title: '1. Risk Calculation and Eligibility Criteria',
          content:
              'Calculate 10-year CVD risk using the pooled cohort equations. Modifiable '
              'risk factors include LDL cholesterol, blood pressure, smoking status, '
              'and diabetes mellitus.',
        ),
        GuidelineSection(
          id: 'uspstf-statin-sec-2',
          title: '2. Statin Intensity and Monitoring',
          content:
              'Low- to moderate-intensity statins (e.g. atorvastatin 10-20 mg, rosuvastatin '
              '5-10 mg, or simvastatin 20-40 mg) demonstrate clear primary prevention '
              'benefits with low adverse effect incidence.',
        ),
      ],
    ),
    ClinicalGuideline(
      id: 'who-hypertension-pharmacological',
      title:
          'Guideline for the pharmacological treatment of hypertension in adults',
      shortTitle: 'Pharmacological treatment of hypertension',
      identifier: 'WHO Guideline (2021)',
      publisher: 'World Health Organization',
      sourceId: 'who-guidelines',
      jurisdiction: GuidelineJurisdiction.global,
      topic: GuidelineTopic.conditionCare,
      publishedDate: DateTime.utc(2021, 8, 25),
      summary:
          'WHO global guidance on initiation thresholds, blood pressure targets, '
          'medication combinations, and monitoring intervals for hypertension in adults.',
      targetAudience:
          'Physicians, nurses, community health workers, and public health planners '
          'in global health systems.',
      evidenceGrade: 'WHO Strong Recommendation',
      fileSizeBytes: 295000,
      webUrl: Uri.parse(
        'https://www.who.int/publications/i/item/9789240033986',
      ),
      downloadUrl: Uri.parse(
        'https://www.who.int/publications/i/item/9789240033986',
      ),
      citation:
          'World Health Organization. (2021). Guideline for the pharmacological '
          'treatment of hypertension in adults. Geneva: World Health Organization.',
      recommendations: const [
        GuidelineRecommendation(
          id: 'who-htn-rec-1',
          title: 'Pharmacological initiation threshold',
          text:
              'Initiate pharmacological antihypertensive treatment in individuals with '
              'a confirmed diagnosis of hypertension and SBP ≥ 140 mmHg or DBP ≥ 90 mmHg.',
          strength: 'Strong recommendation',
          evidenceLevel: 'Moderate to High',
          category: 'Thresholds',
        ),
        GuidelineRecommendation(
          id: 'who-htn-rec-2',
          title: 'Core first-line classes',
          text:
              'Recommend initiation with any of three core drug classes: thiazide/thiazide-like '
              'diuretics, ACE inhibitors/ARBs, or long-acting dihydropyridine CCBs.',
          strength: 'Strong recommendation',
          evidenceLevel: 'High',
          category: 'Classes',
        ),
        GuidelineRecommendation(
          id: 'who-htn-rec-3',
          title: 'Target blood pressure < 140/90 mmHg',
          text:
              'Treat to target blood pressure below 140/90 mmHg in all adults with '
              'hypertension, and below 130/80 mmHg in patients with known cardiovascular '
              'disease.',
          strength: 'Strong recommendation',
          evidenceLevel: 'Moderate',
          category: 'Targets',
        ),
      ],
      sections: const [
        GuidelineSection(
          id: 'who-htn-sec-1',
          title: '1. Global Health Context and Scope',
          content:
              'Hypertension affects over 1.2 billion people worldwide and is the leading '
              'preventable cause of premature death and disability. Simplified treatment '
              'protocols improve adherence and access in primary care.',
        ),
        GuidelineSection(
          id: 'who-htn-sec-2',
          title: '2. Combination Therapy Protocols',
          content:
              'For patients requiring two agents, fixed-dose combination pills (FDCs) '
              'are strongly recommended to simplify regimens and substantially improve '
              'long-term medication adherence.',
        ),
      ],
    ),
    ClinicalGuideline(
      id: 'who-physical-activity',
      title: 'WHO Guidelines on physical activity and sedentary behaviour',
      shortTitle: 'Physical activity and sedentary behaviour',
      identifier: 'WHO Guidelines (2020)',
      publisher: 'World Health Organization',
      sourceId: 'who-guidelines',
      jurisdiction: GuidelineJurisdiction.global,
      topic: GuidelineTopic.publicHealth,
      publishedDate: DateTime.utc(2020, 11, 25),
      summary:
          'Evidence-based public health guidelines on the amount and types of physical '
          'activity that produce substantial health benefits and mitigate sedentary risk.',
      targetAudience:
          'Adults, older adults, pregnant/postpartum women, and individuals living '
          'with chronic conditions.',
      evidenceGrade: 'WHO Strong Recommendation',
      fileSizeBytes: 275000,
      webUrl: Uri.parse(
        'https://www.who.int/publications/i/item/9789240015128',
      ),
      downloadUrl: Uri.parse(
        'https://www.who.int/publications/i/item/9789240015128',
      ),
      citation:
          'World Health Organization. (2020). WHO guidelines on physical activity '
          'and sedentary behaviour. Geneva: World Health Organization.',
      recommendations: const [
        GuidelineRecommendation(
          id: 'who-pa-rec-1',
          title: '150–300 minutes weekly aerobic activity',
          text:
              'All adults should undertake 150–300 minutes of moderate-intensity, or '
              '75–150 minutes of vigorous-intensity physical activity per week.',
          strength: 'Strong recommendation',
          evidenceLevel: 'High certainty',
          category: 'Aerobic',
        ),
        GuidelineRecommendation(
          id: 'who-pa-rec-2',
          title: 'Muscle strengthening 2+ days a week',
          text:
              'Adults should perform muscle-strengthening activities involving all major '
              'muscle groups on 2 or more days a week for additional health benefits.',
          strength: 'Strong recommendation',
          evidenceLevel: 'High certainty',
          category: 'Strength',
        ),
        GuidelineRecommendation(
          id: 'who-pa-rec-3',
          title: 'Limiting sedentary time',
          text:
              'Replace sedentary time with physical activity of any intensity, including '
              'light physical activity. Every move counts.',
          strength: 'Strong recommendation',
          evidenceLevel: 'Moderate certainty',
          category: 'Sedentary',
        ),
      ],
      sections: const [
        GuidelineSection(
          id: 'who-pa-sec-1',
          title: '1. Cardiovascular and Metabolic Health',
          content:
              'Regular physical activity improves cardiovascular fitness, lowers resting '
              'blood pressure, enhances insulin sensitivity, and reduces risks of coronary '
              'heart disease, stroke, hypertension, type 2 diabetes, and depression.',
        ),
        GuidelineSection(
          id: 'who-pa-sec-2',
          title: '2. Functional Balance for Older Adults',
          content:
              'For older adults (aged 65+), multicomponent physical activity that emphasizes '
              'functional balance and strength training on 3 or more days per week helps '
              'enhance functional capacity and prevent falls.',
        ),
      ],
    ),
    ClinicalGuideline(
      id: 'aus-immunisation-influenza',
      title: 'Australian Immunisation Handbook: Annual Influenza',
      shortTitle: 'Annual Influenza Immunisation',
      identifier: 'ATAGI Annual Update',
      publisher: 'Australian Government Department of Health and Aged Care',
      sourceId: 'australian-immunisation',
      jurisdiction: GuidelineJurisdiction.australia,
      topic: GuidelineTopic.immunization,
      publishedDate: DateTime.utc(2024, 4, 1),
      summary:
          'Clinical guidance on influenza vaccination schedules, eligible priority '
          'groups, vaccine strains, and co-administration in Australia.',
      targetAudience:
          'General practitioners, immunisation coordinators, and residents of Australia.',
      evidenceGrade:
          'Australian Technical Advisory Group on Immunisation (ATAGI)',
      fileSizeBytes: 215000,
      webUrl: Uri.parse(
        'https://immunisationhandbook.health.gov.au/contents/vaccine-preventable-diseases/influenza-flu',
      ),
      downloadUrl: Uri.parse(
        'https://immunisationhandbook.health.gov.au/contents/vaccine-preventable-diseases/influenza-flu',
      ),
      citation:
          'Australian Technical Advisory Group on Immunisation (ATAGI). (2024). '
          'The Australian Immunisation Handbook. Australian Government Department of Health.',
      recommendations: const [
        GuidelineRecommendation(
          id: 'aus-flu-rec-1',
          title: 'Universal annual vaccination for all 6 months and older',
          text:
              'Annual influenza vaccination is recommended for all people aged 6 months '
              'and older to protect against seasonal influenza complications.',
          strength: 'National policy recommendation',
          evidenceLevel: 'High certainty',
          category: 'Schedule',
        ),
        GuidelineRecommendation(
          id: 'aus-flu-rec-2',
          title: 'National Immunisation Program priority funding',
          text:
              'Vaccination is free under the NIP for children aged 6 months to < 5 years, '
              'adults aged 65 years and older, pregnant women, and all Aboriginal and '
              'Torres Strait Islander people.',
          strength: 'Funded national policy',
          evidenceLevel: 'High certainty',
          category: 'Eligibility',
        ),
      ],
      sections: const [
        GuidelineSection(
          id: 'aus-flu-sec-1',
          title: '1. Vaccine Timing and Peak Immunity',
          content:
              'Optimal protection occurs within the first 3 to 4 months following vaccination. '
              'In Australia, annual vaccination is typically recommended starting in April/May '
              'ahead of the peak flu season (June to September).',
        ),
      ],
    ),
    ClinicalGuideline(
      id: 'canadian-tobacco-cessation',
      title: 'Tobacco cessation in adults: preventive care recommendations',
      shortTitle: 'Tobacco cessation recommendations',
      identifier: 'Canadian Task Force Recommendation',
      publisher: 'Canadian Task Force on Preventive Health Care',
      sourceId: 'canadian-task-force-archive',
      jurisdiction: GuidelineJurisdiction.canada,
      topic: GuidelineTopic.prevention,
      publishedDate: DateTime.utc(2020, 3, 10),
      summary:
          'Evidence-based recommendations on screening for tobacco use and providing '
          'cessation interventions in Canadian primary care.',
      targetAudience: 'Primary care providers and adults who smoke in Canada.',
      evidenceGrade: 'Task Force Recommendation',
      fileSizeBytes: 198000,
      webUrl: Uri.parse(
        'https://canadiantaskforce.ca/guidelines/published-guidelines/',
      ),
      downloadUrl: Uri.parse(
        'https://canadiantaskforce.ca/guidelines/published-guidelines/',
      ),
      citation:
          'Canadian Task Force on Preventive Health Care. (2020). '
          'Recommendations on tobacco cessation interventions in adults. '
          'Canadian Medical Association Journal (CMAJ).',
      recommendations: const [
        GuidelineRecommendation(
          id: 'can-tobacco-rec-1',
          title: 'Routine screening and brief advice',
          text:
              'Ask all adult patients about tobacco use and provide clear, non-judgmental '
              'advice on cessation.',
          strength: 'Strong recommendation',
          evidenceLevel: 'High certainty',
          category: 'Screening',
        ),
        GuidelineRecommendation(
          id: 'can-tobacco-rec-2',
          title: 'Combined behavioural and pharmacotherapeutic support',
          text:
              'Offer combined behavioural counseling and approved first-line pharmacotherapies '
              '(nicotine replacement therapy, varenicline, or bupropion) for adults wanting to quit.',
          strength: 'Strong recommendation',
          evidenceLevel: 'High certainty',
          category: 'Intervention',
        ),
      ],
      sections: const [
        GuidelineSection(
          id: 'can-tobacco-sec-1',
          title: '1. Effectiveness of Multi-Modal Cessation Support',
          content:
              'Combining individual or group behavioural support with pharmacotherapy '
              'doubles long-term abstinence rates compared to brief unassisted attempts.',
        ),
      ],
    ),
    ClinicalGuideline(
      id: 'nice-ng203-ckd',
      title: 'Chronic kidney disease: assessment and management',
      shortTitle: 'Chronic kidney disease in adults',
      identifier: 'NICE NG203',
      publisher: 'National Institute for Health and Care Excellence (NICE)',
      sourceId: 'nice-guidance',
      jurisdiction: GuidelineJurisdiction.unitedKingdom,
      topic: GuidelineTopic.conditionCare,
      publishedDate: DateTime.utc(2021, 8, 25),
      lastUpdatedDate: DateTime.utc(2024, 1, 15),
      summary:
          'Evidence-based recommendations on diagnosing, monitoring, and managing '
          'chronic kidney disease (CKD) in adults, including eGFR testing, serum '
          'creatinine, urine albumin-to-creatinine ratio (uACR), and renal protection.',
      targetAudience:
          'Healthcare professionals, general practitioners, nephrologists, and adults with or at risk of CKD.',
      evidenceGrade: 'NICE Guideline (High-certainty evidence synthesis)',
      fileSizeBytes: 312000,
      webUrl: Uri.parse('https://www.nice.org.uk/guidance/ng203'),
      downloadUrl: Uri.parse('https://www.nice.org.uk/guidance/ng203'),
      citation:
          'National Institute for Health and Care Excellence. (2021). '
          'Chronic kidney disease: assessment and management (NICE Guideline NG203). London: NICE.',
      recommendations: const [
        GuidelineRecommendation(
          id: 'nice-ng203-rec-1',
          title: 'Monitoring eGFR and Serum Creatinine',
          text:
              'Monitor eGFR creatinine at least annually in adults with CKD, and more frequently '
              'if eGFR is below 45 mL/min/1.73m² or if albuminuria is present.',
          strength: 'Strong recommendation',
          evidenceLevel: 'High',
          category: 'Monitoring',
        ),
        GuidelineRecommendation(
          id: 'nice-ng203-rec-2',
          title: 'Quantifying Proteinuria with uACR',
          text:
              'Use urine albumin-to-creatinine ratio (uACR) rather than reagent strip testing '
              'to detect and quantify proteinuria. Confirm an initial uACR between 3 and 70 mg/mmol '
              'with an early morning specimen.',
          strength: 'Strong recommendation',
          evidenceLevel: 'High',
          category: 'Assessment',
        ),
        GuidelineRecommendation(
          id: 'nice-ng203-rec-3',
          title: 'Blood Pressure Control in CKD',
          text:
              'Aim for systolic blood pressure between 120 and 139 mmHg and diastolic below 90 mmHg '
              'in adults with CKD. If uACR is 70 mg/mmol or higher, target systolic BP below 130 mmHg.',
          strength: 'Strong recommendation',
          evidenceLevel: 'Moderate',
          category: 'Targets',
        ),
        GuidelineRecommendation(
          id: 'nice-ng203-rec-4',
          title: 'Renal-Protective Pharmacotherapy',
          text:
              'Offer an SGLT2 inhibitor alongside optimized ACE inhibitor or ARB therapy '
              'to adults with CKD and type 2 diabetes or significant proteinuria.',
          strength: 'Strong recommendation',
          evidenceLevel: 'High',
          category: 'Treatment',
        ),
      ],
      sections: const [
        GuidelineSection(
          id: 'nice-ng203-sec-1',
          title: '1. Diagnostic Criteria & Laboratory Assessment',
          content:
              'Diagnose CKD if there is evidence of kidney damage (such as persistent uACR >= 3 mg/mmol) '
              'or sustained eGFR < 60 mL/min/1.73m² present for at least 3 months. Avoid diagnosing CKD '
              'based on a single isolated creatinine elevation without repeat verification.',
        ),
        GuidelineSection(
          id: 'nice-ng203-sec-2',
          title: '2. Progression Risk & Specialist Referral',
          content:
              'Calculate 5-year risk of end-stage renal disease using validated 4-variable kidney failure '
              'risk equations (KFRE). Refer adults to nephrology if 5-year risk exceeds 5% or if sustained '
              'eGFR decline is >= 25% within 12 months.',
        ),
      ],
    ),
    ClinicalGuideline(
      id: 'nice-cg181-lipids',
      title:
          'Cardiovascular disease: risk assessment and reduction, including lipid modification',
      shortTitle: 'Lipid modification & CVD reduction',
      identifier: 'NICE CG181/NG238',
      publisher: 'National Institute for Health and Care Excellence (NICE)',
      sourceId: 'nice-guidance',
      jurisdiction: GuidelineJurisdiction.unitedKingdom,
      topic: GuidelineTopic.conditionCare,
      publishedDate: DateTime.utc(2014, 7, 18),
      lastUpdatedDate: DateTime.utc(2023, 12, 14),
      summary:
          'Evidence-based guidance on full lipid profiling (Total Cholesterol, LDL, HDL, '
          'Triglycerides), cardiovascular risk assessment, and statin therapy for primary '
          'and secondary prevention.',
      targetAudience:
          'Primary care physicians, cardiologists, lipid specialists, and adults undergoing lipid testing.',
      evidenceGrade: 'NICE Guideline (High-certainty evidence synthesis)',
      fileSizeBytes: 298000,
      webUrl: Uri.parse('https://www.nice.org.uk/guidance/cg181'),
      downloadUrl: Uri.parse('https://www.nice.org.uk/guidance/cg181'),
      citation:
          'National Institute for Health and Care Excellence. (2014). '
          'Cardiovascular disease: risk assessment and reduction, including lipid modification (NICE CG181/NG238). London: NICE.',
      recommendations: const [
        GuidelineRecommendation(
          id: 'nice-cg181-rec-1',
          title: 'Comprehensive Lipid Profiling',
          text:
              'Measure full lipid profile including total cholesterol, HDL cholesterol, non-HDL '
              'cholesterol, and triglycerides before initiating lipid-lowering therapy. A fasting '
              'sample is not routinely required for initial cardiovascular risk assessment.',
          strength: 'Strong recommendation',
          evidenceLevel: 'High',
          category: 'Assessment',
        ),
        GuidelineRecommendation(
          id: 'nice-cg181-rec-2',
          title: 'Primary Prevention Statin Threshold',
          text:
              'Offer atorvastatin 20 mg for the primary prevention of CVD to people who have a '
              '10-year QRISK cardiovascular risk estimate of 10% or higher.',
          strength: 'Strong recommendation',
          evidenceLevel: 'High',
          category: 'Treatment',
        ),
        GuidelineRecommendation(
          id: 'nice-cg181-rec-3',
          title: 'Lipid Reduction Targets',
          text:
              'Aim for a greater than 40% reduction in non-HDL cholesterol at 3 months after starting '
              'or titrating statin therapy.',
          strength: 'Strong recommendation',
          evidenceLevel: 'Moderate',
          category: 'Targets',
        ),
        GuidelineRecommendation(
          id: 'nice-cg181-rec-4',
          title: 'Lifestyle Advice & Secondary Causes',
          text:
              'Advise a cardioprotective diet, regular aerobic exercise, smoking cessation, and '
              'exclude secondary causes of dyslipidemia (hypothyroidism, nephrotic syndrome, alcohol abuse).',
          strength: 'Strong recommendation',
          evidenceLevel: 'High',
          category: 'Lifestyle',
        ),
      ],
      sections: const [
        GuidelineSection(
          id: 'nice-cg181-sec-1',
          title: '1. Formal Risk Calculation & Indications',
          content:
              'Use formal risk calculation tools (such as QRISK3) in adults aged 25 to 84 without '
              'pre-existing CVD. People with type 1 diabetes, established CVD, or familial '
              'hypercholesterolemia should receive statin therapy without requiring risk score calculation.',
        ),
        GuidelineSection(
          id: 'nice-cg181-sec-2',
          title: '2. Statin Safety & Muscle Symptom Review',
          content:
              'Measure baseline liver enzymes (ALT or AST) and renal function before starting statins. '
              'Re-check ALT/AST at 3 months and 12 months; routine CK monitoring is not required unless '
              'unexplained generalized muscle pain develops.',
        ),
      ],
    ),
    ClinicalGuideline(
      id: 'uspstf-weight-management',
      title:
          'Weight Loss to Prevent Obesity-Related Morbidity and Mortality in Adults: Behavioral Interventions',
      shortTitle: 'Adult Weight Management & Obesity',
      identifier: 'USPSTF Recommendation (Grade B)',
      publisher: 'U.S. Preventive Services Task Force (USPSTF)',
      sourceId: 'uspstf-recommendations',
      jurisdiction: GuidelineJurisdiction.unitedStates,
      topic: GuidelineTopic.prevention,
      publishedDate: DateTime.utc(2018, 9, 18),
      lastUpdatedDate: DateTime.utc(2023, 6, 12),
      summary:
          'Evidence-based recommendations on screening for obesity and offering intensive, '
          'multicomponent behavioral weight-loss interventions to adults with BMI >= 30 kg/m².',
      targetAudience:
          'Primary care clinicians, preventive medicine specialists, and adults seeking weight management guidance.',
      evidenceGrade: 'USPSTF Grade B (Moderate net benefit)',
      fileSizeBytes: 245000,
      webUrl: Uri.parse(
        'https://www.uspreventiveservicestaskforce.org/uspstf/recommendation/obesity-in-adults-interventions',
      ),
      downloadUrl: Uri.parse(
        'https://www.uspreventiveservicestaskforce.org/uspstf/recommendation/obesity-in-adults-interventions',
      ),
      citation:
          'US Preventive Services Task Force. (2018). '
          'Behavioral Weight Loss Interventions to Prevent Obesity-Related Morbidity and Mortality in Adults: Recommendation Statement. JAMA, 320(11):1163–1171.',
      recommendations: const [
        GuidelineRecommendation(
          id: 'uspstf-weight-rec-1',
          title: 'Universal BMI Screening & Intervention Referral',
          text:
              'Clinicians should screen all adults for obesity using Body Mass Index (BMI). '
              'Offer or refer adults with a BMI of 30 or higher to intensive, multicomponent behavioral interventions.',
          strength: 'Grade B recommendation',
          evidenceLevel: 'Moderate certainty',
          category: 'Screening',
        ),
        GuidelineRecommendation(
          id: 'uspstf-weight-rec-2',
          title: 'Multicomponent Behavioral Intervention Content',
          text:
              'Effective behavioral interventions should include group or individual counseling, '
              'dietary calorie tracking, prescribed physical activity goals, and self-monitoring strategies.',
          strength: 'Grade B recommendation',
          evidenceLevel: 'High certainty',
          category: 'Intervention',
        ),
      ],
      sections: const [
        GuidelineSection(
          id: 'uspstf-weight-sec-1',
          title: '1. Clinical Considerations & BMI Categories',
          content:
              'Normal BMI is defined as 18.5 to 24.9 kg/m²; overweight is 25.0 to 29.9 kg/m²; '
              'and obesity is >= 30.0 kg/m² (with lower thresholds of 23.0 and 27.5 kg/m² in Asian populations). '
              'Weight loss of 5% or greater significantly improves glycemic control, blood pressure, and lipid profiles.',
        ),
      ],
    ),
    ClinicalGuideline(
      id: 'nice-ng80-asthma',
      title: 'Asthma: diagnosis, monitoring and chronic asthma management',
      shortTitle: 'Asthma & Respiratory Monitoring',
      identifier: 'NICE NG80',
      publisher: 'National Institute for Health and Care Excellence (NICE)',
      sourceId: 'nice-guidance',
      jurisdiction: GuidelineJurisdiction.unitedKingdom,
      topic: GuidelineTopic.conditionCare,
      publishedDate: DateTime.utc(2017, 11, 29),
      lastUpdatedDate: DateTime.utc(2021, 3, 22),
      summary:
          'Evidence-based guidance on diagnosing and monitoring asthma and chronic airway '
          'limitation in adults and children, including peak flow variability and pulse oximetry.',
      targetAudience:
          'Pulmonologists, general practitioners, respiratory nurses, and individuals with asthma or COPD.',
      evidenceGrade: 'NICE Guideline (High-certainty evidence synthesis)',
      fileSizeBytes: 275000,
      webUrl: Uri.parse('https://www.nice.org.uk/guidance/ng80'),
      downloadUrl: Uri.parse('https://www.nice.org.uk/guidance/ng80'),
      citation:
          'National Institute for Health and Care Excellence. (2017). '
          'Asthma: diagnosis, monitoring and chronic asthma management (NICE Guideline NG80). London: NICE.',
      recommendations: const [
        GuidelineRecommendation(
          id: 'nice-ng80-rec-1',
          title: 'Objective Respiratory Monitoring with Peak Flow',
          text:
              'Monitor peak expiratory flow (PEF) variability over 2 to 4 weeks in adults with '
              'suspected asthma or fluctuating respiratory symptoms. A diurnal variability > 20% supports diagnosis.',
          strength: 'Strong recommendation',
          evidenceLevel: 'Moderate',
          category: 'Monitoring',
        ),
        GuidelineRecommendation(
          id: 'nice-ng80-rec-2',
          title: 'Pulse Oximetry Oxygen Saturation Targets',
          text:
              'In acute respiratory assessment, measure pulse oximetry (SpO2). Target oxygen '
              'saturation of 94% to 98% in adults without risk of hypercapnic respiratory failure.',
          strength: 'Strong recommendation',
          evidenceLevel: 'High',
          category: 'Assessment',
        ),
        GuidelineRecommendation(
          id: 'nice-ng80-rec-3',
          title: 'Personalized Asthma Action Plan',
          text:
              'Provide every patient with a written personalized asthma action plan including '
              'daily maintenance guidance, symptom-triggered adjustments, and emergency criteria.',
          strength: 'Strong recommendation',
          evidenceLevel: 'High',
          category: 'Management',
        ),
      ],
      sections: const [
        GuidelineSection(
          id: 'nice-ng80-sec-1',
          title: '1. Diagnostic Testing Pathway',
          content:
              'Combine clinical history with objective tests: spirometry with bronchodilator reversibility, '
              'fractional exhaled nitric oxide (FeNO), and peak flow diaries before confirming chronic airway diagnoses.',
        ),
      ],
    ),
  ]);

  static List<ClinicalGuideline> filter({
    String query = '',
    GuidelineTopic topic = GuidelineTopic.all,
    GuidelineJurisdiction jurisdiction = GuidelineJurisdiction.all,
    Set<String>? downloadedIds,
    bool downloadedOnly = false,
  }) {
    final normalizedQuery = query.trim().toLowerCase();
    return guidelines
        .where((guideline) {
          if (downloadedOnly) {
            if (downloadedIds == null ||
                !downloadedIds.contains(guideline.id)) {
              return false;
            }
          }
          final matchesTopic =
              topic == GuidelineTopic.all || guideline.topic == topic;
          final matchesJurisdiction =
              jurisdiction == GuidelineJurisdiction.all ||
              guideline.jurisdiction == jurisdiction;
          if (!matchesTopic || !matchesJurisdiction) return false;

          if (normalizedQuery.isEmpty) return true;

          final searchable = [
            guideline.title,
            guideline.shortTitle,
            guideline.identifier,
            guideline.publisher,
            guideline.summary,
            guideline.targetAudience,
            guideline.evidenceGrade,
            guideline.topic.label,
            guideline.jurisdiction.label,
            ...guideline.recommendations.map((r) => '${r.title} ${r.text}'),
            ...guideline.sections.map((s) => '${s.title} ${s.content}'),
          ].join(' ').toLowerCase();

          return searchable.contains(normalizedQuery);
        })
        .toList(growable: false);
  }

  static final Map<String, ClinicalGuideline> _guidelineById = {
    for (final g in guidelines) g.id: g,
  };

  static final _nonAlphanumericPattern = RegExp(r'[^a-z0-9]+');

  // Cache related guideline query results to prevent redundant regex evaluation and string tokenization
  static final Map<String, List<ClinicalGuideline>> _relatedGuidelinesCache =
      {};
  static const int _maxCacheSize = 128;

  /// Returns curated clinical guidelines related to a specific measurement or
  /// record type for educational reference and doctor-patient discussion.
  ///
  /// Supports matching by LOINC code ([loincCode]), standardized measurement names,
  /// clinical abbreviations (e.g. eGFR, BP, BMI, SpO2), and categories.
  ///
  /// This mapping is strictly educational and informational; it does not provide
  /// automated diagnosis, clinical interpretation, or individualized patient advice.
  static List<ClinicalGuideline> findRelatedGuidelines({
    required String measurementName,
    String? category,
    String? loincCode,
  }) {
    final name = measurementName.toLowerCase().trim();
    final cat = category?.toLowerCase().trim() ?? '';
    final code =
        loincCode
            ?.toLowerCase()
            .trim()
            .replaceFirst('http://loinc.org|', '')
            .replaceFirst('urn:oid:2.16.840.1.113883.6.1|', '')
            .replaceFirst('loinc:', '')
            .trim() ??
        '';

    final cacheKey = '$name|$cat|$code';
    final cached = _relatedGuidelinesCache[cacheKey];
    if (cached != null) return cached;

    final tokens = name
        .split(_nonAlphanumericPattern)
        .where((t) => t.isNotEmpty)
        .toSet();

    final matched = <ClinicalGuideline>[];
    final matchedIds = <String>{};

    void addGuideline(String id) {
      if (matchedIds.add(id)) {
        final found = _guidelineById[id];
        if (found != null) {
          matched.add(found);
        }
      }
    }

    // 1. Blood Pressure / Hypertension
    const bpLoincs = {'85354-9', '8480-6', '8462-4', '55284-4'};
    if (bpLoincs.contains(code) ||
        name.contains('blood pressure') ||
        name.contains('systolic') ||
        name.contains('diastolic') ||
        name.contains('hypertension') ||
        name.contains('arterial pressure') ||
        tokens.contains('bp') ||
        tokens.contains('sbp') ||
        tokens.contains('dbp')) {
      addGuideline('nice-ng136-hypertension');
      addGuideline('uspstf-hypertension-screening');
      addGuideline('who-hypertension-pharmacological');
    }

    // 2. Glucose / Diabetes / HbA1c
    const glucoseLoincs = {
      '4548-4',
      '17856-6',
      '2345-7',
      '2339-0',
      '15074-8',
      '14771-0',
      '14749-6',
    };
    if (glucoseLoincs.contains(code) ||
        name.contains('glucose') ||
        name.contains('hba1c') ||
        name.contains('a1c') ||
        name.contains('glycated') ||
        name.contains('diabetes') ||
        name.contains('blood sugar') ||
        tokens.contains('a1c') ||
        tokens.contains('dm')) {
      addGuideline('nice-ng28-diabetes');
      addGuideline('uspstf-diabetes-screening');
    }

    // 3. Chronic Kidney Disease (CKD) / Renal Function
    const ckdLoincs = {
      '2160-0',
      '38483-4',
      '33914-3',
      '48642-3',
      '48643-1',
      '88294-4',
      '14959-1',
      '9318-7',
      '3094-0',
      '14958-3',
      '2888-6',
    };
    if (ckdLoincs.contains(code) ||
        name.contains('creatinine') ||
        name.contains('egfr') ||
        name.contains('glomerular') ||
        name.contains('kidney') ||
        name.contains('renal') ||
        name.contains('uacr') ||
        name.contains('albuminuria') ||
        name.contains('microalbumin') ||
        name.contains('bun') ||
        name.contains('urea nitrogen') ||
        tokens.contains('ckd') ||
        tokens.contains('egfr') ||
        tokens.contains('gfr') ||
        tokens.contains('uacr') ||
        tokens.contains('cr')) {
      addGuideline('nice-ng203-ckd');
    }

    // 4. Cholesterol / Lipids / CVD Prevention
    const lipidLoincs = {
      '2093-3',
      '13457-7',
      '18262-6',
      '2085-9',
      '2571-8',
      '57698-3',
      '3043-7',
      '9830-1',
    };
    if (lipidLoincs.contains(code) ||
        name.contains('cholesterol') ||
        name.contains('ldl') ||
        name.contains('hdl') ||
        name.contains('lipid') ||
        name.contains('triglyceride') ||
        name.contains('dyslipidemia') ||
        name.contains('hyperlipidemia') ||
        tokens.contains('ldl') ||
        tokens.contains('hdl') ||
        tokens.contains('tc')) {
      addGuideline('nice-cg181-lipids');
      addGuideline('uspstf-statin-cvd');
    }

    // 5. Weight Management / Obesity / BMI
    const weightLoincs = {
      '39156-5',
      '29463-7',
      '3141-9',
      '8302-2',
      '8306-3',
      '56086-2',
    };
    if (weightLoincs.contains(code) ||
        name.contains('body mass index') ||
        name.contains('bmi') ||
        name.contains('body weight') ||
        name.contains('weight') ||
        name.contains('obesity') ||
        name.contains('overweight') ||
        name.contains('adiposity') ||
        tokens.contains('bmi')) {
      addGuideline('uspstf-weight-management');
      addGuideline('who-physical-activity');
    }

    // 6. Asthma / Respiratory / SpO2 / Peak Expiratory Flow
    const asthmaLoincs = {'2708-6', '59408-5', '19935-6', '20150-9', '19926-5'};
    if (asthmaLoincs.contains(code) ||
        name.contains('asthma') ||
        name.contains('spo2') ||
        name.contains('oxygen saturation') ||
        name.contains('pulse oximetry') ||
        name.contains('peak flow') ||
        name.contains('pefr') ||
        name.contains('fev1') ||
        name.contains('respiratory') ||
        tokens.contains('spo2') ||
        tokens.contains('pefr')) {
      addGuideline('nice-ng80-asthma');
    }

    // 7. Physical activity / Steps / Exercise
    if (name.contains('step') ||
        name.contains('walk') ||
        name.contains('run') ||
        name.contains('distance') ||
        name.contains('active energy') ||
        name.contains('activity') ||
        cat == 'activity' ||
        cat == 'physical activity') {
      addGuideline('who-physical-activity');
    }

    // 8. Heart rate / Pulse
    const hrLoincs = {'8867-4', '8889-8'};
    if (hrLoincs.contains(code) ||
        name.contains('heart rate') ||
        name.contains('pulse') ||
        name.contains('resting heart rate') ||
        tokens.contains('hr')) {
      addGuideline('nice-ng136-hypertension');
      addGuideline('who-physical-activity');
    }

    // 9. Smoking / Tobacco
    const tobaccoLoincs = {'72166-2'};
    if (tobaccoLoincs.contains(code) ||
        name.contains('smoking') ||
        name.contains('tobacco') ||
        name.contains('nicotine') ||
        name.contains('cigarette')) {
      addGuideline('canadian-tobacco-cessation');
    }

    // 10. Immunization / Vaccines
    if (name.contains('flu') ||
        name.contains('influenza') ||
        name.contains('vaccine') ||
        name.contains('immunisation') ||
        name.contains('immunization') ||
        cat == 'immunization' ||
        cat == 'immunisation') {
      addGuideline('aus-immunisation-influenza');
    }

    final result = List<ClinicalGuideline>.unmodifiable(matched);
    if (_relatedGuidelinesCache.length >= _maxCacheSize) {
      _relatedGuidelinesCache.clear();
    }
    _relatedGuidelinesCache[cacheKey] = result;
    return result;
  }

  /// Quick check whether any evidence-based guideline matches the given
  /// measurement name, category, or LOINC code.
  static bool hasRelatedGuidelines({
    required String measurementName,
    String? category,
    String? loincCode,
  }) {
    return findRelatedGuidelines(
      measurementName: measurementName,
      category: category,
      loincCode: loincCode,
    ).isNotEmpty;
  }
}
