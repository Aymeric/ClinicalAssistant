import 'dart:convert';

import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:http/http.dart' as http;

import '../models/health_record.dart';
import '../sync/import_progress.dart';
import 'fhir_observation_parser.dart';

class FhirPortalImportResult {
  const FhirPortalImportResult({
    required this.records,
    required this.patientId,
    required this.authorizationEndpoint,
    required this.tokenEndpoint,
    this.refreshToken,
  });

  final List<HealthRecord> records;
  final String patientId;
  final String authorizationEndpoint;
  final String tokenEndpoint;
  final String? refreshToken;
}

class FhirPortalImporter {
  FhirPortalImporter({
    FlutterAppAuth? appAuth,
    http.Client? client,
    this._parser = const FhirObservationParser(),
  }) : _appAuth = appAuth ?? const FlutterAppAuth(),
       _client = client ?? http.Client();

  static const redirectUri =
      'com.aymericgrassart.clinicalassistant:/oauth2redirect';
  static const _baseScopes = [
    'openid',
    'fhirUser',
    'launch/patient',
    'patient/Observation.read',
  ];

  final FlutterAppAuth _appAuth;
  final http.Client _client;
  final FhirObservationParser _parser;

  void close() => _client.close();

  Future<List<HealthRecord>> importLabResults({
    required String fhirBaseUrl,
    required String clientId,
    ImportProgressCallback? onProgress,
  }) async {
    final result = await authorizeAndImportLabResults(
      fhirBaseUrl: fhirBaseUrl,
      clientId: clientId,
      onProgress: onProgress,
    );
    return result.records;
  }

  Future<FhirPortalImportResult> authorizeAndImportLabResults({
    required String fhirBaseUrl,
    required String clientId,
    bool requestRefreshToken = false,
    DateTime? since,
    ImportProgressCallback? onProgress,
  }) async {
    onProgress?.call(
      const ImportProgress(
        fraction: 0,
        message: 'Waiting for portal authorization',
      ),
    );
    final base = _validatedBaseUri(fhirBaseUrl);
    _validateClientId(clientId);
    final configuration = await _loadConfiguration(base);

    final AuthorizationTokenResponse tokenResponse;
    try {
      tokenResponse = await _appAuth.authorizeAndExchangeCode(
        AuthorizationTokenRequest(
          clientId.trim(),
          redirectUri,
          serviceConfiguration: configuration,
          scopes: [..._baseScopes, if (requestRefreshToken) 'offline_access'],
          additionalParameters: {'aud': base.toString()},
        ),
      );
    } on FlutterAppAuthUserCancelledException {
      throw StateError(
        'Provider connection cancelled. No records were imported.',
      );
    }

    final accessToken = _requiredValue(
      tokenResponse.accessToken,
      'The provider did not return an access token. No health records were imported.',
    );
    final patientId = _requiredValue(
      tokenResponse.tokenAdditionalParameters?['patient']?.toString(),
      'The provider did not grant a patient context. Launch the connection from your patient portal or choose a provider that supports standalone patient access.',
    );
    final refreshToken = requestRefreshToken
        ? _nonEmpty(tokenResponse.refreshToken)
        : null;

    onProgress?.call(
      const ImportProgress(fraction: 0.05, message: 'Downloading lab results'),
    );
    final records = await _readObservations(
      base: base,
      accessToken: accessToken,
      patientId: patientId,
      since: since,
      onProgress: onProgress,
    );
    return FhirPortalImportResult(
      records: records,
      patientId: patientId,
      authorizationEndpoint: configuration.authorizationEndpoint,
      tokenEndpoint: configuration.tokenEndpoint,
      refreshToken: refreshToken,
    );
  }

  Future<FhirPortalImportResult> refreshAndImportLabResults({
    required String fhirBaseUrl,
    required String clientId,
    required String patientId,
    required String refreshToken,
    required String authorizationEndpoint,
    required String tokenEndpoint,
    required DateTime since,
    required Future<void> Function(String refreshToken) onRefreshTokenUpdated,
    ImportProgressCallback? onProgress,
  }) async {
    final base = _validatedBaseUri(fhirBaseUrl);
    _validateClientId(clientId);
    final validatedAuthorizationEndpoint = _validatedEndpoint(
      authorizationEndpoint,
      'authorization',
    );
    final validatedTokenEndpoint = _validatedEndpoint(tokenEndpoint, 'token');
    if (patientId.trim().isEmpty || refreshToken.trim().isEmpty) {
      throw const FormatException(
        'The saved portal authorization is incomplete. Reconnect the portal to continue syncing.',
      );
    }

    final tokenResponse = await _appAuth.token(
      TokenRequest(
        clientId.trim(),
        redirectUri,
        refreshToken: refreshToken,
        serviceConfiguration: AuthorizationServiceConfiguration(
          authorizationEndpoint: validatedAuthorizationEndpoint,
          tokenEndpoint: validatedTokenEndpoint,
        ),
      ),
    );
    final accessToken = _requiredValue(
      tokenResponse.accessToken,
      'The provider did not return an access token. Reconnect the portal to continue syncing.',
    );
    final updatedRefreshToken =
        _nonEmpty(tokenResponse.refreshToken) ?? refreshToken;
    await onRefreshTokenUpdated(updatedRefreshToken);
    onProgress?.call(
      const ImportProgress(fraction: 0.05, message: 'Downloading lab results'),
    );
    final records = await _readObservations(
      base: base,
      accessToken: accessToken,
      patientId: patientId.trim(),
      since: since,
      onProgress: onProgress,
    );
    return FhirPortalImportResult(
      records: records,
      patientId: patientId.trim(),
      authorizationEndpoint: validatedAuthorizationEndpoint,
      tokenEndpoint: validatedTokenEndpoint,
      refreshToken: updatedRefreshToken,
    );
  }

  Future<AuthorizationServiceConfiguration> _loadConfiguration(Uri base) async {
    final discovery = await _client.get(
      base.resolve('.well-known/smart-configuration'),
      headers: const {'Accept': 'application/json'},
    );
    if (discovery.statusCode < 200 || discovery.statusCode >= 300) {
      throw StateError(
        'This server did not provide SMART-on-FHIR configuration (HTTP ${discovery.statusCode}).',
      );
    }
    final decoded = jsonDecode(discovery.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'The FHIR server returned invalid SMART configuration.',
      );
    }
    final authorizationEndpoint = _validatedEndpoint(
      decoded['authorization_endpoint']?.toString(),
      'authorization',
    );
    final tokenEndpoint = _validatedEndpoint(
      decoded['token_endpoint']?.toString(),
      'token',
    );
    return AuthorizationServiceConfiguration(
      authorizationEndpoint: authorizationEndpoint,
      tokenEndpoint: tokenEndpoint,
      endSessionEndpoint: decoded['end_session_endpoint']?.toString(),
    );
  }

  Future<List<HealthRecord>> _readObservations({
    required Uri base,
    required String accessToken,
    required String patientId,
    DateTime? since,
    ImportProgressCallback? onProgress,
  }) async {
    final query = <String, String>{
      'patient': patientId,
      'category': 'laboratory',
      '_count': '100',
      if (since != null) 'date': 'ge${since.toUtc().toIso8601String()}',
    };
    final observationsUri = base
        .resolve('Observation')
        .replace(queryParameters: query);
    final records = <HealthRecord>[];
    var nextUri = observationsUri;
    final expectedOrigin = base.origin;
    final visitedPages = <Uri>{};
    var completedEntries = 0;
    int? totalEntries;
    var pageNumber = 0;
    while (true) {
      if (!visitedPages.add(nextUri)) {
        throw const FormatException(
          'The provider returned a repeated pagination link. Import stopped to avoid looping.',
        );
      }
      if (nextUri.origin != expectedOrigin) {
        throw const FormatException(
          'The provider returned a pagination link to another server. Import stopped to protect your access token.',
        );
      }
      final response = await _client.get(
        nextUri,
        headers: {
          'Accept': 'application/fhir+json, application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError(
          'The provider could not return lab results (HTTP ${response.statusCode}).',
        );
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('The provider returned invalid FHIR data.');
      }
      final bundleTotal = decoded['total'];
      if (totalEntries == null && bundleTotal is num && bundleTotal > 0) {
        totalEntries = bundleTotal.toInt();
      }
      final entries = decoded['entry'];
      if (entries is List) completedEntries += entries.length;
      pageNumber++;
      final pageRecords = _parser.parseBundle(
        decoded,
        source: base.host,
        sourceId: base.toString(),
      );
      records.addAll(
        since == null
            ? pageRecords
            : pageRecords.where(
                (record) => !record.recordedAt.isBefore(since.toUtc()),
              ),
      );
      final progressFraction = totalEntries == null
          ? 0.05
          : (0.05 + 0.8 * completedEntries / totalEntries)
                .clamp(0.05, 0.85)
                .toDouble();
      onProgress?.call(
        ImportProgress(
          fraction: progressFraction,
          message: totalEntries == null
              ? 'Downloaded page $pageNumber · ${records.length} lab results'
              : 'Downloaded ${completedEntries.clamp(0, totalEntries)} of $totalEntries results',
        ),
      );

      final links = decoded['link'];
      if (links is! List) break;
      final nextLink = links.whereType<Map>().where(
        (link) => link['relation'] == 'next',
      );
      if (nextLink.isEmpty) break;
      final nextUrl = nextLink.first['url']?.toString();
      if (nextUrl == null || nextUrl.isEmpty) break;
      final parsedNext = Uri.tryParse(nextUrl);
      if (parsedNext == null) {
        throw const FormatException(
          'The provider returned an invalid pagination link.',
        );
      }
      nextUri = base.resolveUri(parsedNext);
    }
    onProgress?.call(
      const ImportProgress(fraction: 0.9, message: 'Lab results downloaded'),
    );
    return records..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
  }

  Uri _validatedBaseUri(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        uri.scheme != 'https') {
      throw const FormatException(
        'Enter a valid HTTPS FHIR server base URL (without credentials, query, or fragment).',
      );
    }
    return uri.replace(
      path: uri.path.endsWith('/') ? uri.path : '${uri.path}/',
    );
  }

  String _validatedEndpoint(String? value, String name) {
    final uri = value == null ? null : Uri.tryParse(value);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      throw FormatException('The provider returned an invalid $name endpoint.');
    }
    return uri.toString();
  }

  void _validateClientId(String value) {
    if (value.trim().isEmpty) {
      throw ArgumentError.value(
        value,
        'clientId',
        'Enter the registered app client ID.',
      );
    }
  }

  String _requiredValue(String? value, String message) {
    if (value == null || value.isEmpty) throw FormatException(message);
    return value;
  }

  String? _nonEmpty(String? value) =>
      value == null || value.isEmpty ? null : value;
}
