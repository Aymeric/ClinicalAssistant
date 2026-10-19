import 'package:clinical_assistant/ui/security/privacy_policy_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders PrivacyPolicyPage with local-only and encryption sections', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: PrivacyPolicyPage(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Privacy & Data Governance'), findsOneWidget);
    expect(find.text('100% On-Device & Zero Cloud'), findsOneWidget);
    expect(find.text('On-Device AES-GCM Encryption'), findsOneWidget);
    expect(find.text('Platform Health Permissions Rationale'), findsOneWidget);
    expect(find.text('SMART-on-FHIR Provider Portals'), findsOneWidget);
    expect(find.text('User-Initiated Exports'), findsOneWidget);
    expect(find.text('Right to Complete Deletion'), findsOneWidget);
  });
}
