import 'package:clinical_assistant/integrations/fhir_provider_presets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FhirProviderPreset', () {
    test(
      'contains standard curated presets including Epic, Cerner, and SMART',
      () {
        final presets = FhirProviderPreset.standardPresets;
        expect(presets.length, greaterThanOrEqualTo(4));

        final presetIds = presets.map((p) => p.id).toList();
        expect(presetIds, contains('smart-health-it-r4'));
        expect(presetIds, contains('epic-fhir-sandbox'));
        expect(presetIds, contains('cerner-millennium-sandbox'));
        expect(presetIds, contains('logica-health-sandbox'));
      },
    );

    test('exposes correct app redirect URI for OAuth registrations', () {
      expect(
        FhirProviderPreset.appRedirectUri,
        'com.cidevelop.clinicalAssistant:/oauth2redirect',
      );
    });

    test(
      'findByBaseUrl finds preset regardless of trailing slashes or case',
      () {
        final smart1 = FhirProviderPreset.findByBaseUrl(
          'https://launch.smarthealthit.org/v/r4/fhir',
        );
        expect(smart1?.id, 'smart-health-it-r4');

        final smart2 = FhirProviderPreset.findByBaseUrl(
          'https://launch.smarthealthit.org/v/r4/fhir/',
        );
        expect(smart2?.id, 'smart-health-it-r4');

        final epic = FhirProviderPreset.findByBaseUrl(
          'https://fhir.epic.com/interconnect-fhir-oauth/api/FHIR/R4',
        );
        expect(epic?.id, 'epic-fhir-sandbox');
        expect(epic?.instructions, contains('fhir.epic.com'));

        final nonExistent = FhirProviderPreset.findByBaseUrl(
          'https://unknown.hospital.org/fhir',
        );
        expect(nonExistent, isNull);
      },
    );
  });
}
