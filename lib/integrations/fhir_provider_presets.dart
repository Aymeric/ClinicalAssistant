/// Curated SMART-on-FHIR provider gateways and developer sandboxes.
class FhirProviderPreset {
  const FhirProviderPreset({
    required this.id,
    required this.name,
    required this.description,
    required this.baseUrl,
    this.defaultClientId,
    required this.isSandbox,
    this.instructions,
  });

  final String id;
  final String name;
  final String description;
  final String baseUrl;
  final String? defaultClientId;
  final bool isSandbox;
  final String? instructions;

  static const String appRedirectUri =
      'com.cidevelop.clinicalAssistant:/oauth2redirect';

  /// Standard curated list of developer sandboxes and healthcare gateways.
  static const List<FhirProviderPreset> standardPresets = [
    FhirProviderPreset(
      id: 'smart-health-it-r4',
      name: 'SMART Health IT Sample Portal (R4)',
      description:
          'Open public sandbox with synthetic patient records and standard SMART-on-FHIR launch.',
      baseUrl: 'https://launch.smarthealthit.org/v/r4/fhir',
      defaultClientId: 'clinical_assistant_smart_client',
      isSandbox: true,
      instructions:
          'Public testing sandbox. No prior developer registration required.',
    ),
    FhirProviderPreset(
      id: 'epic-fhir-sandbox',
      name: 'Epic on FHIR Developer Sandbox',
      description:
          'Epic Systems open developer environment supporting FHIR R4 Patient and Observation resources.',
      baseUrl: 'https://fhir.epic.com/interconnect-fhir-oauth/api/FHIR/R4',
      defaultClientId: '',
      isSandbox: true,
      instructions:
          'Register at fhir.epic.com to obtain a Non-Production Client ID configured with the redirect URI: $appRedirectUri',
    ),
    FhirProviderPreset(
      id: 'cerner-millennium-sandbox',
      name: 'Oracle Health / Cerner Millennium Sandbox',
      description:
          'Oracle Health (Cerner) Open Developer sandbox with synthetic EHR patient records.',
      baseUrl:
          'https://fhir-myrecord.cerner.com/r4/ec2458f2-1e24-41c8-b71b-0e701af7583d',
      defaultClientId: '',
      isSandbox: true,
      instructions:
          'Register on code.cerner.com with application type "Patient Access" and redirect URI: $appRedirectUri',
    ),
    FhirProviderPreset(
      id: 'logica-health-sandbox',
      name: 'Logica Health Open Sandbox (HSPC)',
      description:
          'Multi-tenant healthcare testbed supporting open FHIR R4 clinical data.',
      baseUrl: 'https://api.logicahealth.org/open/data',
      defaultClientId: 'clinical_assistant_logica_client',
      isSandbox: true,
      instructions:
          'Open developer sandbox supporting public and registered client access.',
    ),
  ];

  static final _trailingSlashPattern = RegExp(r'/+$');

  static FhirProviderPreset? findByBaseUrl(String url) {
    final cleanUrl = url
        .trim()
        .replaceAll(_trailingSlashPattern, '')
        .toLowerCase();
    for (final preset in standardPresets) {
      if (preset.baseUrl.replaceAll(_trailingSlashPattern, '').toLowerCase() ==
          cleanUrl) {
        return preset;
      }
    }
    return null;
  }
}
