import 'dart:convert';

import 'package:clinical_assistant/integrations/fhir_portal_importer.dart';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('parseRetryAfter', () {
    test('parses integer seconds and clamps to maximum bound', () {
      expect(
        FhirPortalImporter.parseRetryAfter('5', fallbackAttempt: 1),
        const Duration(seconds: 5),
      );
      expect(
        FhirPortalImporter.parseRetryAfter('120', fallbackAttempt: 1),
        const Duration(seconds: 30),
      );
    });

    test('falls back to exponential backoff when header is absent or invalid', () {
      expect(
        FhirPortalImporter.parseRetryAfter(null, fallbackAttempt: 1),
        const Duration(seconds: 1),
      );
      expect(
        FhirPortalImporter.parseRetryAfter('', fallbackAttempt: 2),
        const Duration(seconds: 2),
      );
      expect(
        FhirPortalImporter.parseRetryAfter('invalid-header', fallbackAttempt: 3),
        const Duration(seconds: 4),
      );
    });

    test('parses date-based Retry-After header', () {
      final now = DateTime.utc(2026, 9, 30, 12, 0, 0);
      final targetDate = now.add(const Duration(seconds: 10));
      final dateStr = targetDate.toIso8601String();

      final duration = FhirPortalImporter.parseRetryAfter(
        dateStr,
        fallbackAttempt: 1,
        now: () => now,
      );
      expect(duration, const Duration(seconds: 10));
    });
  });

  group('HTTP 429 / 503 Retry Resilience', () {
    test('retries on 429 Too Many Requests and succeeds on subsequent attempt', () async {
      var callCount = 0;
      final delays = <Duration>[];

      final client = MockClient((request) async {
        if (request.url.path.endsWith('/.well-known/smart-configuration')) {
          return http.Response(
            jsonEncode({
              'authorization_endpoint': 'https://auth.example.com/oauth/authorize',
              'token_endpoint': 'https://auth.example.com/oauth/token',
            }),
            200,
          );
        }

        callCount++;
        if (callCount <= 2) {
          return http.Response(
            'Too Many Requests',
            429,
            headers: {'retry-after': '3'},
          );
        }

        return http.Response(
          jsonEncode({
            'resourceType': 'Bundle',
            'entry': [
              {
                'resource': {
                  'resourceType': 'Observation',
                  'id': 'obs-1',
                  'status': 'final',
                  'code': {'text': 'Serum Creatinine'},
                  'effectiveDateTime': '2026-09-28T10:00:00Z',
                  'valueQuantity': {'value': 0.9, 'unit': 'mg/dL'},
                },
              },
            ],
          }),
          200,
        );
      });

      final importer = FhirPortalImporter(
        appAuth: _FakeAppAuth(),
        client: client,
        sleeper: (duration) async {
          delays.add(duration);
        },
      );

      final records = await importer.authorizeAndImportLabResults(
        fhirBaseUrl: 'https://ehr.example.com/fhir',
        clientId: 'registered-client',
      );

      expect(callCount, 3); // initial 429 + retry 429 + retry 200
      expect(delays, [const Duration(seconds: 3), const Duration(seconds: 3)]);
      expect(records.records.length, 1);
      expect(records.records.first.name, 'Serum Creatinine');
    });

    test('retries on 503 Service Unavailable with exponential backoff', () async {
      var callCount = 0;
      final delays = <Duration>[];

      final client = MockClient((request) async {
        if (request.url.path.endsWith('/.well-known/smart-configuration')) {
          return http.Response(
            jsonEncode({
              'authorization_endpoint': 'https://auth.example.com/oauth/authorize',
              'token_endpoint': 'https://auth.example.com/oauth/token',
            }),
            200,
          );
        }

        callCount++;
        if (callCount == 1) {
          return http.Response('Service Temporarily Unavailable', 503);
        }

        return http.Response(
          jsonEncode({
            'resourceType': 'Bundle',
            'entry': [],
          }),
          200,
        );
      });

      final importer = FhirPortalImporter(
        appAuth: _FakeAppAuth(),
        client: client,
        sleeper: (duration) async {
          delays.add(duration);
        },
      );

      final records = await importer.authorizeAndImportLabResults(
        fhirBaseUrl: 'https://ehr.example.com/fhir',
        clientId: 'registered-client',
      );

      expect(callCount, 2);
      expect(delays, [const Duration(seconds: 1)]);
      expect(records.records, isEmpty);
    });

    test('throws StateError when 429 retries are exhausted', () async {
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/.well-known/smart-configuration')) {
          return http.Response(
            jsonEncode({
              'authorization_endpoint': 'https://auth.example.com/oauth/authorize',
              'token_endpoint': 'https://auth.example.com/oauth/token',
            }),
            200,
          );
        }
        return http.Response('Rate Limit Exceeded', 429, headers: {'retry-after': '1'});
      });

      final importer = FhirPortalImporter(
        appAuth: _FakeAppAuth(),
        client: client,
        sleeper: (_) async {},
      );

      expect(
        () => importer.authorizeAndImportLabResults(
          fhirBaseUrl: 'https://ehr.example.com/fhir',
          clientId: 'registered-client',
        ),
        throwsA(isA<StateError>()),
      );
    });
  });
}

class _FakeAppAuth extends FlutterAppAuth {
  @override
  Future<AuthorizationTokenResponse> authorizeAndExchangeCode(
    AuthorizationTokenRequest request,
  ) async {
    return AuthorizationTokenResponse(
      'mock-access-token',
      null,
      null,
      null,
      'Bearer',
      const [],
      null,
      {'patient': 'patient-123'},
    );
  }
}
