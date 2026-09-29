import 'dart:convert';

import 'package:clinical_assistant/integrations/fhir_portal_importer.dart';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('imports every FHIR page with determinate progress and patient-scoped token', () async {
    final requests = <http.Request>[];
    final progress = <double>[];
    final importer = FhirPortalImporter(
      client: MockClient((request) async {
        requests.add(request);
        if (request.url.path.endsWith('/.well-known/smart-configuration')) {
          return http.Response(
            jsonEncode({
              'authorization_endpoint':
                  'https://login.portal.example/authorize',
              'token_endpoint': 'https://login.portal.example/token',
            }),
            200,
          );
        }
        expect(request.headers['Authorization'], 'Bearer temporary-token');
        if (request.url.queryParameters['cursor'] == 'page-2') {
          return http.Response(
            jsonEncode({
              'resourceType': 'Bundle',
              'entry': [
                {
                  'resource': {
                    'resourceType': 'Observation',
                    'id': 'lab-2',
                    'status': 'final',
                    'code': {'text': 'Glucose'},
                    'effectiveDateTime': '2025-04-12T00:00:00Z',
                    'valueQuantity': {'value': 98, 'unit': 'mg/dL'},
                  },
                },
              ],
            }),
            200,
          );
        }
        expect(request.url.queryParameters['patient'], 'patient-7');
        expect(request.url.queryParameters['category'], 'laboratory');
        return http.Response(
          jsonEncode({
            'resourceType': 'Bundle',
            'total': 2,
            'entry': [
              {
                'resource': {
                  'resourceType': 'Observation',
                  'id': 'lab-1',
                  'status': 'final',
                  'code': {'text': 'Glucose'},
                  'effectiveDateTime': '2025-04-11T00:00:00Z',
                  'valueQuantity': {'value': 96, 'unit': 'mg/dL'},
                },
              },
            ],
            'link': [
              {
                'relation': 'next',
                'url': 'https://portal.example/fhir/Observation?cursor=page-2',
              },
            ],
          }),
          200,
        );
      }),
      appAuth: _FakeAppAuth(),
    );

    final records = await importer.importLabResults(
      fhirBaseUrl: 'https://portal.example/fhir',
      clientId: 'registered-client',
      onProgress: (value) => progress.add(value.fraction),
    );

    expect(records, hasLength(2));
    expect(requests, hasLength(3));
    expect(requests.last.url.queryParameters['cursor'], 'page-2');
    expect(progress, contains(0.45));
    expect(progress, contains(0.85));
    expect(progress.last, 0.9);
  });

  test('rejects non-HTTPS FHIR endpoints before making a request', () async {
    var requestCount = 0;
    final importer = FhirPortalImporter(
      client: MockClient((_) async {
        requestCount++;
        return http.Response('', 500);
      }),
      appAuth: _FakeAppAuth(),
    );

    await expectLater(
      importer.importLabResults(
        fhirBaseUrl: 'http://portal.example/fhir',
        clientId: 'registered-client',
      ),
      throwsFormatException,
    );
    expect(requestCount, 0);
  });

  test(
    'rejects a cross-origin pagination link before sending the token',
    () async {
      var tokenSentToAnotherHost = false;
      final importer = FhirPortalImporter(
        client: MockClient((request) async {
          if (request.url.path.endsWith('/.well-known/smart-configuration')) {
            return http.Response(
              jsonEncode({
                'authorization_endpoint':
                    'https://login.portal.example/authorize',
                'token_endpoint': 'https://login.portal.example/token',
              }),
              200,
            );
          }
          if (request.url.host != 'portal.example' &&
              request.headers.containsKey('Authorization')) {
            tokenSentToAnotherHost = true;
          }
          return http.Response(
            jsonEncode({
              'resourceType': 'Bundle',
              'entry': [],
              'link': [
                {'relation': 'next', 'url': 'https://attacker.example/collect'},
              ],
            }),
            200,
          );
        }),
        appAuth: _FakeAppAuth(),
      );

      await expectLater(
        importer.importLabResults(
          fhirBaseUrl: 'https://portal.example/fhir',
          clientId: 'registered-client',
        ),
        throwsFormatException,
      );
      expect(tokenSentToAnotherHost, isFalse);
    },
  );

  test('rejects repeated pagination links instead of looping', () async {
    final requests = <http.Request>[];
    final importer = FhirPortalImporter(
      client: MockClient((request) async {
        requests.add(request);
        if (request.url.path.endsWith('/.well-known/smart-configuration')) {
          return http.Response(
            jsonEncode({
              'authorization_endpoint':
                  'https://login.portal.example/authorize',
              'token_endpoint': 'https://login.portal.example/token',
            }),
            200,
          );
        }
        return http.Response(
          jsonEncode({
            'resourceType': 'Bundle',
            'entry': [],
            'link': [
              {'relation': 'next', 'url': request.url.toString()},
            ],
          }),
          200,
        );
      }),
      appAuth: _FakeAppAuth(),
    );

    await expectLater(
      importer.importLabResults(
        fhirBaseUrl: 'https://portal.example/fhir',
        clientId: 'registered-client',
      ),
      throwsFormatException,
    );
    expect(requests, hasLength(2));
  });

  test(
    'requests and rotates a refresh token for opted-in incremental sync',
    () async {
      final requests = <http.Request>[];
      final appAuth = _FakeAppAuth(
        authorizationRefreshToken: 'initial-refresh-token',
        refreshedToken: 'rotated-refresh-token',
      );
      String? savedRefreshToken;
      final importer = FhirPortalImporter(
        client: MockClient((request) async {
          requests.add(request);
          if (request.url.path.endsWith('/.well-known/smart-configuration')) {
            return http.Response(
              jsonEncode({
                'authorization_endpoint':
                    'https://login.portal.example/authorize',
                'token_endpoint': 'https://login.portal.example/token',
              }),
              200,
            );
          }
          return http.Response(
            jsonEncode({'resourceType': 'Bundle', 'entry': []}),
            200,
          );
        }),
        appAuth: appAuth,
      );

      final authorized = await importer.authorizeAndImportLabResults(
        fhirBaseUrl: 'https://portal.example/fhir',
        clientId: 'registered-client',
        requestRefreshToken: true,
      );
      final since = DateTime.utc(2026, 9, 20);
      final refreshed = await importer.refreshAndImportLabResults(
        fhirBaseUrl: 'https://portal.example/fhir',
        clientId: 'registered-client',
        patientId: authorized.patientId,
        refreshToken: authorized.refreshToken!,
        authorizationEndpoint: authorized.authorizationEndpoint,
        tokenEndpoint: authorized.tokenEndpoint,
        since: since,
        onRefreshTokenUpdated: (token) async {
          savedRefreshToken = token;
        },
      );

      expect(authorized.refreshToken, 'initial-refresh-token');
      expect(refreshed.refreshToken, 'rotated-refresh-token');
      expect(savedRefreshToken, 'rotated-refresh-token');
      expect(appAuth.authorizationRequest!.scopes, contains('offline_access'));
      expect(appAuth.refreshRequest!.refreshToken, 'initial-refresh-token');
      expect(
        requests.last.url.queryParameters['date'],
        'ge${since.toIso8601String()}',
      );
      expect(requests.last.headers['Authorization'], 'Bearer refreshed-token');
    },
  );

  test(
    'persists a rotated token before a portal data request can fail',
    () async {
      final appAuth = _FakeAppAuth(refreshedToken: 'rotated-refresh-token');
      String? savedRefreshToken;
      final importer = FhirPortalImporter(
        client: MockClient(
          (_) async =>
              http.Response('{"resourceType":"OperationOutcome"}', 401),
        ),
        appAuth: appAuth,
      );

      await expectLater(
        importer.refreshAndImportLabResults(
          fhirBaseUrl: 'https://portal.example/fhir',
          clientId: 'registered-client',
          patientId: 'patient-7',
          refreshToken: 'old-refresh-token',
          authorizationEndpoint: 'https://login.portal.example/authorize',
          tokenEndpoint: 'https://login.portal.example/token',
          since: DateTime.utc(2026, 9, 20),
          onRefreshTokenUpdated: (token) async {
            savedRefreshToken = token;
          },
        ),
        throwsStateError,
      );
      expect(savedRefreshToken, 'rotated-refresh-token');
    },
  );
}

class _FakeAppAuth extends FlutterAppAuth {
  _FakeAppAuth({this.authorizationRefreshToken, this.refreshedToken});

  final String? authorizationRefreshToken;
  final String? refreshedToken;
  AuthorizationTokenRequest? authorizationRequest;
  TokenRequest? refreshRequest;

  @override
  Future<AuthorizationTokenResponse> authorizeAndExchangeCode(
    AuthorizationTokenRequest request,
  ) async {
    expect(request.clientId, 'registered-client');
    authorizationRequest = request;
    return AuthorizationTokenResponse(
      'temporary-token',
      authorizationRefreshToken,
      null,
      null,
      'Bearer',
      const [],
      null,
      {'patient': 'patient-7'},
    );
  }

  @override
  Future<TokenResponse> token(TokenRequest request) async {
    refreshRequest = request;
    return TokenResponse(
      'refreshed-token',
      refreshedToken,
      null,
      null,
      'Bearer',
      null,
      null,
    );
  }
}
