import 'package:flutter/material.dart';

import '../shared/record_widgets.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Privacy & Data Governance')),
      body: PageContent(
        children: [
          Card(
            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.shield_outlined,
                    size: 28,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '100% On-Device & Zero Cloud',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Clinical Assistant does not operate app accounts or cloud servers. '
                          'Your health records, lab results, medications, and notes remain encrypted '
                          'exclusively on this device.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildSection(
            context,
            icon: Icons.lock_outline,
            title: 'On-Device AES-GCM Encryption',
            content:
                'All imported health records and manual entries are stored in a local SQLite '
                'database encrypted with AES-GCM (256-bit). Cryptographic keys are generated '
                'randomly on-device and stored in platform hardware security modules '
                '(iOS Keychain or Android Keystore via EncryptedSharedPreferences). '
                'The local vault is excluded from standard cloud backups.',
          ),
          const SizedBox(height: 14),
          _buildSection(
            context,
            icon: Icons.health_and_safety_outlined,
            title: 'Platform Health Permissions Rationale',
            content:
                'When you connect Apple HealthKit or Android Health Connect, the app requests read-only '
                'access to measurements you choose to aggregate (such as blood pressure, heart rate, '
                'glucose, oxygen saturation, sleep, and steps). '
                'Where supported by your device, reading clinical laboratory records is separately '
                'requested. Health data is never transmitted to third parties, used for marketing, or sold.',
          ),
          const SizedBox(height: 14),
          _buildSection(
            context,
            icon: Icons.local_hospital_outlined,
            title: 'SMART-on-FHIR Provider Portals',
            content:
                'Connecting to an external healthcare provider portal uses standard SMART-on-FHIR '
                'OAuth 2.0 authorization directly on your provider’s secure website. '
                'Access tokens stay strictly in volatile memory. If you explicitly opt in to '
                'automatic sync, a provider-issued refresh token is protected in platform secure '
                'storage. Disabling sync permanently removes it.',
          ),
          const SizedBox(height: 14),
          _buildSection(
            context,
            icon: Icons.file_upload_outlined,
            title: 'User-Initiated Exports',
            content:
                'Exports (PDF doctor summaries, FHIR JSON Bundles, and CSV tables) are created '
                'only when you trigger them. Files are generated in temporary storage and shared '
                'exclusively through the native system share sheet. CSV exports sanitize formula '
                'triggers to prevent spreadsheet injection risks.',
          ),
          const SizedBox(height: 14),
          _buildSection(
            context,
            icon: Icons.delete_forever_outlined,
            title: 'Right to Complete Deletion',
            content:
                'You maintain complete ownership of your health records. Tapping "Delete all records" '
                'instantly wipes the encrypted database, destroys encryption keys from platform hardware '
                'storage, revokes saved provider tokens, and resets all synchronization settings.',
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              'Clinical Assistant is an informational tool and does not provide medical diagnosis or advice.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String content,
  }) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 22, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              content,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
