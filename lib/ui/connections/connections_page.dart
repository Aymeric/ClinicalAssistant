import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../controllers/health_data_controller.dart';
import '../../data/vault_security_service.dart';
import '../../notifications/result_notification_manager.dart';
import '../../notifications/result_notification_settings.dart';
import '../../sync/foreground_sync_state.dart';
import '../../sync/import_progress.dart';
import '../overview/overview_page.dart';
import '../security/vault_security_card.dart';
import '../shared/record_widgets.dart';

class ConnectionsPage extends StatelessWidget {
  const ConnectionsPage({
    super.key,
    required this.busy,
    required this.healthRecordCount,
    required this.fhirRecordCount,
    required this.since,
    required this.syncState,
    required this.syncSettingsLoading,
    required this.syncing,
    required this.syncStatus,
    required this.onChooseDate,
    required this.onHealthImport,
    required this.onFhirImport,
    required this.onHealthAutoSyncChanged,
    required this.onFhirAutoSyncDisabled,
    required this.onSyncNow,
    required this.onDeleteRecords,
    required this.notificationManager,
    required this.syncValueStore,
    required this.onProgress,
    this.syntheticRecordCount = 0,
    this.onLoadSyntheticDemo,
    this.onClearSyntheticDemo,
    this.onImportFhirJson,
    this.onRestoreVaultBackup,
    this.onExportVaultBackup,
    this.vaultSecurityService,
    this.onLockVault,
    required this.onOpenGuidelines,
  });

  final bool busy;
  final int healthRecordCount;
  final int fhirRecordCount;
  final int syntheticRecordCount;
  final DateTime since;
  final ForegroundSyncState? syncState;
  final bool syncSettingsLoading;
  final bool syncing;
  final String? syncStatus;
  final VoidCallback onChooseDate;
  final VoidCallback onHealthImport;
  final FhirPortalConnectCallback onFhirImport;
  final ValueChanged<bool> onHealthAutoSyncChanged;
  final Future<void> Function() onFhirAutoSyncDisabled;
  final VoidCallback onSyncNow;
  final Future<void> Function() onDeleteRecords;
  final ResultNotificationManager notificationManager;
  final SyncValueStore syncValueStore;
  final ImportProgressCallback onProgress;
  final VoidCallback? onLoadSyntheticDemo;
  final VoidCallback? onClearSyntheticDemo;
  final Future<void> Function(String json, {String source})? onImportFhirJson;
  final VoidCallback? onRestoreVaultBackup;
  final VoidCallback? onExportVaultBackup;
  final VaultSecurityService? vaultSecurityService;
  final VoidCallback? onLockVault;
  final VoidCallback onOpenGuidelines;

  @override
  Widget build(BuildContext context) {
    return PageContent(
      children: [
        Text(
          'Choose what you connect. Imports stay in your encrypted on-device vault.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 22),
        Card(
          child: ListTile(
            key: const ValueKey('sources-guidelines-entry'),
            leading: const Icon(Icons.menu_book_outlined),
            title: const Text(
              'Evidence-based guidelines',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: const Text(
              'Browse source collections and check their jurisdiction and status.',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: onOpenGuidelines,
          ),
        ),
        const SizedBox(height: 14),
        ForegroundSyncPanel(
          state: syncState,
          loading: syncSettingsLoading,
          syncing: syncing,
          healthSyncAvailable: Platform.isIOS || Platform.isAndroid,
          status: syncStatus,
          onHealthAutoSyncChanged: onHealthAutoSyncChanged,
          onSyncNow: onSyncNow,
        ),
        const SizedBox(height: 14),
        ResultNotificationSettings(manager: notificationManager),
        const SizedBox(height: 22),
        if (Platform.isIOS)
          SourcePanel(
            icon: CupertinoIcons.heart_fill,
            title: 'Apple Health',
            description:
                'Read supported measurements and stored lab results. Steps are summarized by day.',
            count: healthRecordCount,
            connected:
                healthRecordCount > 0 ||
                (syncState?.healthAutoSync == true &&
                    syncState?.lastHealthSyncAt != null),
            busy: busy,
            buttonLabel: 'Connect Apple Health',
            onPressed: busy ? null : onHealthImport,
          ),
        if (Platform.isAndroid)
          SourcePanel(
            icon: Icons.favorite_outline,
            title: 'Health Connect',
            description:
                'Read supported health and available lab records from Health Connect. Steps are summarized by day.',
            count: healthRecordCount,
            connected:
                healthRecordCount > 0 ||
                (syncState?.healthAutoSync == true &&
                    syncState?.lastHealthSyncAt != null),
            busy: busy,
            buttonLabel: 'Connect Health Connect',
            onPressed: busy ? null : onHealthImport,
          ),
        if (Platform.isIOS || Platform.isAndroid) ...[
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_month_outlined,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Health-platform date range',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      TextButton(
                        onPressed: onChooseDate,
                        child: const Text('Change'),
                      ),
                    ],
                  ),
                  Text(
                    '${since.year <= 1900 ? 'All available history' : 'From ${since.year}-${since.month.toString().padLeft(2, '0')}-${since.day.toString().padLeft(2, '0')}'} to today',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    Platform.isAndroid
                        ? 'Lab results require Health Connect Medical Records support and separate permission. Health Connect may limit history to 30 days unless history access is enabled.'
                        : 'HealthKit measurements and clinical lab records use separate permission prompts. Only approved records stored in Apple Health can be imported.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 14),
        FhirConnectionForm(
          busy: busy,
          importedCount: fhirRecordCount,
          autoSyncConfigured: syncState?.fhirAutoSync ?? false,
          syncValueStore: syncValueStore,
          connected:
              fhirRecordCount > 0 ||
              (syncState?.fhirAutoSync == true &&
                  syncState?.fhirRefreshTokenAvailable == true),
          onConnect: onFhirImport,
          onProgress: onProgress,
          onDisableAutoSync: onFhirAutoSyncDisabled,
        ),
        const SizedBox(height: 14),
        FhirJsonImportCard(busy: busy, onImport: onImportFhirJson),
        const SizedBox(height: 14),
        SyntheticDemoCard(
          busy: busy,
          count: syntheticRecordCount,
          onLoad: onLoadSyntheticDemo,
          onClear: onClearSyntheticDemo,
        ),
        const SizedBox(height: 14),
        VaultBackupCard(
          busy: busy,
          onRestore: onRestoreVaultBackup,
          onExport: onExportVaultBackup,
        ),
        if (vaultSecurityService != null) ...[
          const SizedBox(height: 14),
          VaultSecurityCard(
            securityService: vaultSecurityService!,
            onLockNow: onLockVault,
          ),
        ],
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your data stays yours',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Records are encrypted on this device. Removing them here does not remove them from the original source.',
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: busy ? null : onDeleteRecords,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete records from this device'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class VaultBackupCard extends StatelessWidget {
  const VaultBackupCard({
    super.key,
    required this.busy,
    this.onRestore,
    this.onExport,
  });

  final bool busy;
  final VoidCallback? onRestore;
  final VoidCallback? onExport;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconStamp(
                  icon: Icons.shield_outlined,
                  background: theme.colorScheme.primaryContainer,
                  foreground: theme.colorScheme.onPrimaryContainer,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Encrypted vault backup & restore',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Passphrase-protected archive',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Move your records securely between devices using AES-GCM 256-bit encrypted backup files protected by your personal passphrase.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  key: const ValueKey('vault-restore-open-button'),
                  onPressed: busy || onRestore == null ? null : onRestore,
                  icon: const Icon(Icons.settings_backup_restore, size: 18),
                  label: const Text('Restore from backup'),
                ),
                if (onExport != null)
                  OutlinedButton.icon(
                    key: const ValueKey('vault-export-connections-button'),
                    onPressed: busy ? null : onExport,
                    icon: const Icon(Icons.file_download_outlined, size: 18),
                    label: const Text('Export backup'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class VaultRestoreSheet extends StatefulWidget {
  const VaultRestoreSheet({super.key, required this.onRestore});

  final Future<void> Function(String json, String passphrase, bool replaceAll)
  onRestore;

  @override
  State<VaultRestoreSheet> createState() => _VaultRestoreSheetState();
}

class _VaultRestoreSheetState extends State<VaultRestoreSheet> {
  final _jsonController = TextEditingController();
  final _passphraseController = TextEditingController();
  bool _replaceAll = false;
  bool _obscurePassphrase = true;
  bool _restoring = false;
  String? _error;

  @override
  void dispose() {
    _jsonController.dispose();
    _passphraseController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final jsonText = _jsonController.text.trim();
    if (jsonText.isEmpty) {
      setState(
        () => _error = 'Please paste the encrypted backup JSON payload.',
      );
      return;
    }
    final passphrase = _passphraseController.text;
    if (passphrase.isEmpty) {
      setState(() => _error = 'Please enter the vault backup passphrase.');
      return;
    }

    setState(() {
      _restoring = true;
      _error = null;
    });

    try {
      await widget.onRestore(jsonText, passphrase, _replaceAll);
    } catch (e) {
      if (mounted) {
        setState(() {
          _restoring = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Restore Encrypted Vault Backup',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Restore records from a passphrase-protected backup file.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              key: const ValueKey('vault-restore-json-input'),
              controller: _jsonController,
              maxLines: 5,
              decoration: InputDecoration(
                labelText: 'Encrypted backup JSON',
                hintText:
                    '{\n  "format": "clinical_assistant_vault_backup_v1",\n  ...\n}',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  tooltip: 'Paste from clipboard',
                  icon: const Icon(Icons.content_paste),
                  onPressed: () async {
                    final data = await Clipboard.getData('text/plain');
                    if (data?.text != null) {
                      _jsonController.text = data!.text!;
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('vault-restore-passphrase-input'),
              controller: _passphraseController,
              obscureText: _obscurePassphrase,
              decoration: InputDecoration(
                labelText: 'Backup passphrase',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassphrase
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassphrase = !_obscurePassphrase),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Replace existing vault records'),
              subtitle: const Text(
                'When enabled, existing records are replaced. When disabled, backup records are merged with current records.',
              ),
              value: _replaceAll,
              onChanged: _restoring
                  ? null
                  : (val) => setState(() => _replaceAll = val),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 13,
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _restoring ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  key: const ValueKey('vault-restore-submit-button'),
                  onPressed: _restoring ? null : _submit,
                  child: _restoring
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Restore records'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class FhirJsonImportCard extends StatelessWidget {
  const FhirJsonImportCard({super.key, required this.busy, this.onImport});

  final bool busy;
  final Future<void> Function(String json, {String source})? onImport;

  void _openImportSheet(BuildContext context) {
    if (onImport == null) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => FhirJsonImportSheet(
        onImport: (json, source) async {
          Navigator.pop(sheetContext);
          await onImport!(json, source: source);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconStamp(
                  icon: Icons.code,
                  background: theme.colorScheme.secondaryContainer,
                  foreground: theme.colorScheme.onSecondaryContainer,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Direct FHIR JSON import',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Paste Observations or Bundles directly',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Import clinical records from a file or sandbox by pasting raw FHIR Observation or Bundle JSON into your local vault.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.tonalIcon(
              key: const ValueKey('connection-import-fhir-json-button'),
              onPressed: busy || onImport == null
                  ? null
                  : () => _openImportSheet(context),
              icon: const Icon(Icons.paste_outlined, size: 18),
              label: const Text('Paste FHIR JSON'),
            ),
          ],
        ),
      ),
    );
  }
}

class FhirJsonImportSheet extends StatefulWidget {
  const FhirJsonImportSheet({super.key, required this.onImport});

  final Future<void> Function(String json, String source) onImport;

  @override
  State<FhirJsonImportSheet> createState() => _FhirJsonImportSheetState();
}

class _FhirJsonImportSheetState extends State<FhirJsonImportSheet> {
  final _jsonController = TextEditingController();
  final _sourceController = TextEditingController(text: 'FHIR Import');
  bool _importing = false;
  String? _error;

  @override
  void dispose() {
    _jsonController.dispose();
    _sourceController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _jsonController.text.trim();
    if (text.isEmpty) {
      setState(() => _error = 'Please paste FHIR JSON content.');
      return;
    }
    final source = _sourceController.text.trim().isEmpty
        ? 'FHIR Import'
        : _sourceController.text.trim();
    setState(() {
      _importing = true;
      _error = null;
    });
    try {
      await widget.onImport(text, source);
    } catch (e) {
      if (mounted) {
        setState(() {
          _importing = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Paste FHIR JSON',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Paste an Observation resource or a Bundle containing Observations.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              key: const ValueKey('fhir-json-source-field'),
              controller: _sourceController,
              decoration: const InputDecoration(
                labelText: 'Source label',
                hintText: 'e.g. Hospital Lab, Sandbox FHIR',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('fhir-json-input-field'),
              controller: _jsonController,
              maxLines: 8,
              decoration: InputDecoration(
                labelText: 'JSON payload',
                hintText: '{\n  "resourceType": "Observation",\n  ...\n}',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  tooltip: 'Paste from clipboard',
                  icon: const Icon(Icons.content_paste),
                  onPressed: () async {
                    final data = await Clipboard.getData('text/plain');
                    if (data?.text != null) {
                      _jsonController.text = data!.text!;
                    }
                  },
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 13,
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _importing ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  key: const ValueKey('fhir-json-submit-button'),
                  onPressed: _importing ? null : _submit,
                  child: _importing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Import records'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class SyntheticDemoCard extends StatelessWidget {
  const SyntheticDemoCard({
    super.key,
    required this.busy,
    required this.count,
    this.onLoad,
    this.onClear,
  });

  final bool busy;
  final int count;
  final VoidCallback? onLoad;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasRecords = count > 0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconStamp(
                  icon: Icons.science_outlined,
                  background: theme.colorScheme.tertiaryContainer,
                  foreground: theme.colorScheme.onTertiaryContainer,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Demonstration records',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        hasRecords
                            ? '$count demonstration records loaded'
                            : 'Explore without real health data',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (hasRecords)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.tertiaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Synthetic',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onTertiaryContainer,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Load synthetic demonstration records (HbA1c, Cholesterol, Glucose, Creatinine, Heart Rate, Blood Pressure, and Daily Steps) spanning recent months to explore trends, charts, and exports.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                if (!hasRecords)
                  FilledButton.tonalIcon(
                    key: const ValueKey('load-synthetic-demo-button'),
                    onPressed: busy ? null : onLoad,
                    icon: const Icon(Icons.download_outlined, size: 18),
                    label: const Text('Load demonstration records'),
                  )
                else ...[
                  OutlinedButton.icon(
                    key: const ValueKey('reload-synthetic-demo-button'),
                    onPressed: busy ? null : onLoad,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Reload demo records'),
                  ),
                  TextButton.icon(
                    key: const ValueKey('clear-synthetic-demo-button'),
                    onPressed: busy ? null : onClear,
                    icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                    label: const Text('Remove demo records'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ForegroundSyncPanel extends StatelessWidget {
  const ForegroundSyncPanel({
    super.key,
    required this.state,
    required this.loading,
    required this.syncing,
    required this.healthSyncAvailable,
    required this.status,
    required this.onHealthAutoSyncChanged,
    required this.onSyncNow,
  });

  final ForegroundSyncState? state;
  final bool loading;
  final bool syncing;
  final bool healthSyncAvailable;
  final String? status;
  final ValueChanged<bool> onHealthAutoSyncChanged;
  final VoidCallback onSyncNow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasAutoSync = state?.hasAutoSync ?? false;
    final isError = status?.startsWith('Sync needs attention') ?? false;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Automatic sync',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Check for new records when the app opens or returns to the foreground, at most once every 5 minutes. Sync runs only on this device.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            if (healthSyncAvailable)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Apple Health / Health Connect'),
                subtitle: const Text(
                  'Initial sync downloads all available history; later checks overlap the last 3 days.',
                ),
                value: state?.healthAutoSync ?? false,
                onChanged: loading || syncing ? null : onHealthAutoSyncChanged,
              ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.local_hospital_outlined),
              title: const Text('FHIR patient portal'),
              subtitle: Text(
                state?.fhirAutoSync != true
                    ? 'Off · opt in below when authorizing the portal'
                    : state?.fhirRefreshTokenAvailable == true
                    ? 'On · refresh token stored securely on this device'
                    : 'Needs attention · reauthorize this portal',
              ),
            ),
            if (!healthSyncAvailable)
              Text(
                'Health-platform sync is available on iOS and Android.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            if (state?.healthAutoSync == true)
              Text(
                'Last health sync: ${formatSyncTimestamp(state?.lastHealthSyncAt)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            if (state?.fhirAutoSync == true)
              Text(
                'Last portal sync: ${formatSyncTimestamp(state?.lastFhirSyncAt)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            if (loading && status == null)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('Loading sync settings...'),
              ),
            if (status != null) ...[
              const SizedBox(height: 8),
              Text(
                status!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isError ? theme.colorScheme.error : null,
                ),
              ),
            ],
            const SizedBox(height: 6),
            OutlinedButton.icon(
              onPressed: loading || syncing || !hasAutoSync ? null : onSyncNow,
              icon: const Icon(Icons.sync),
              label: Text(syncing ? 'Syncing...' : 'Sync enabled sources now'),
            ),
          ],
        ),
      ),
    );
  }
}

class FhirConnectionForm extends StatefulWidget {
  const FhirConnectionForm({
    super.key,
    required this.busy,
    required this.importedCount,
    required this.autoSyncConfigured,
    required this.syncValueStore,
    required this.connected,
    required this.onConnect,
    required this.onProgress,
    required this.onDisableAutoSync,
  });

  final bool busy;
  final int importedCount;
  final bool autoSyncConfigured;
  final SyncValueStore syncValueStore;
  final bool connected;
  final FhirPortalConnectCallback onConnect;
  final ImportProgressCallback onProgress;
  final Future<void> Function() onDisableAutoSync;

  @override
  State<FhirConnectionForm> createState() => _FhirConnectionFormState();
}

class _FhirConnectionFormState extends State<FhirConnectionForm> {
  static const _baseKey = 'fhir_base_url_v1';
  static const _clientKey = 'fhir_client_id_v1';
  static const _autoSyncKey = 'fhir_auto_sync_v1';
  static const _refreshTokenKey = 'fhir_refresh_token_v1';
  final _formKey = GlobalKey<FormState>();
  final _baseController = TextEditingController();
  final _clientController = TextEditingController();
  var _loadingConfig = true;
  var _rememberPortalForAutoSync = false;
  var _savedPortalAutoSync = false;
  String? _configError;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  @override
  void didUpdateWidget(covariant FhirConnectionForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.autoSyncConfigured != widget.autoSyncConfigured) {
      setState(() {
        _savedPortalAutoSync = widget.autoSyncConfigured;
        if (widget.autoSyncConfigured || oldWidget.autoSyncConfigured) {
          _rememberPortalForAutoSync = widget.autoSyncConfigured;
        }
      });
    }
  }

  @override
  void dispose() {
    _baseController.dispose();
    _clientController.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    try {
      final values = await Future.wait([
        widget.syncValueStore.read(_baseKey),
        widget.syncValueStore.read(_clientKey),
        widget.syncValueStore.read(_autoSyncKey),
        widget.syncValueStore.read(_refreshTokenKey),
        widget.syncValueStore.read('fhir_patient_id_v1'),
        widget.syncValueStore.read('fhir_authorization_endpoint_v1'),
        widget.syncValueStore.read('fhir_token_endpoint_v1'),
      ]);
      if (!mounted) return;
      _baseController.text = values[0] ?? '';
      _clientController.text = values[1] ?? '';
      final hasSavedRefreshToken =
          values[2] == 'true' &&
          values[3] != null &&
          values[4] != null &&
          values[5] != null &&
          values[6] != null;
      _rememberPortalForAutoSync = hasSavedRefreshToken;
      _savedPortalAutoSync = hasSavedRefreshToken;
      if (values[2] == 'true' && !hasSavedRefreshToken) {
        _configError =
            'Saved portal auto-sync authorization is incomplete. Reauthorize the portal to restore it.';
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _configError = 'Saved connection details could not be opened: $error';
        });
      }
    } finally {
      if (mounted) setState(() => _loadingConfig = false);
    }
  }

  Future<void> _setPortalAutoSyncConsent(bool enabled) async {
    if (enabled) {
      setState(() => _rememberPortalForAutoSync = true);
      return;
    }
    if (!_savedPortalAutoSync && !widget.autoSyncConfigured) {
      setState(() => _rememberPortalForAutoSync = false);
      return;
    }
    setState(() {
      _loadingConfig = true;
      _configError = null;
    });
    try {
      await widget.onDisableAutoSync();
      if (mounted) {
        setState(() {
          _rememberPortalForAutoSync = false;
          _savedPortalAutoSync = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _configError = 'Could not disable portal auto-sync: $error',
        );
      }
    } finally {
      if (mounted) setState(() => _loadingConfig = false);
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final outcome = await widget.onConnect(
      baseUrl: _baseController.text.trim(),
      clientId: _clientController.text.trim(),
      rememberPortalForAutoSync: _rememberPortalForAutoSync,
      onProgress: widget.onProgress,
    );
    if (!mounted || outcome == null) return;
    setState(() {
      _savedPortalAutoSync = outcome.autoSyncEnabled;
      _rememberPortalForAutoSync = outcome.autoSyncEnabled;
      _configError = outcome.autoSyncUnavailable
          ? 'This portal did not issue a refresh token. Automatic portal sync remains off.'
          : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconStamp(
                    icon: Icons.local_hospital_outlined,
                    background: theme.colorScheme.tertiaryContainer,
                    foreground: theme.colorScheme.onTertiaryContainer,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'FHIR patient portal',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (widget.importedCount > 0)
                    CountPill(count: widget.importedCount),
                ],
              ),
              if (widget.connected) ...[
                const SizedBox(height: 8),
                const ConnectionStatusPill(),
              ],
              const SizedBox(height: 14),
              Text(
                'Import lab Observations from a provider that supports SMART-on-FHIR patient access.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _baseController,
                keyboardType: TextInputType.url,
                autofillHints: const [AutofillHints.url],
                decoration: const InputDecoration(
                  labelText: 'FHIR server base URL',
                  hintText: 'https://provider.example/fhir/R4',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final uri = Uri.tryParse(value?.trim() ?? '');
                  if (uri == null ||
                      uri.scheme != 'https' ||
                      uri.host.isEmpty) {
                    return 'Enter the provider’s HTTPS FHIR base URL.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _clientController,
                decoration: const InputDecoration(
                  labelText: 'Registered app client ID',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter the client ID registered with this provider.'
                    : null,
              ),
              const SizedBox(height: 12),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('Automatically sync this portal'),
                subtitle: const Text(
                  'If the provider supports it, the app will securely store a refresh token on this device. Uncheck to delete it locally.',
                ),
                value: _rememberPortalForAutoSync,
                onChanged: widget.busy || _loadingConfig
                    ? null
                    : (value) => _setPortalAutoSyncConsent(value ?? false),
              ),
              const SizedBox(height: 4),
              Text(
                'Portal access is provider-specific. Automatic sync requests offline access; not every provider supports refresh tokens. Access tokens are never saved.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              if (_configError != null) ...[
                const SizedBox(height: 8),
                Text(
                  _configError!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: widget.busy || _loadingConfig ? null : _submit,
                icon: widget.busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.open_in_new),
                label: Text(
                  widget.busy ? 'Connecting...' : 'Authorize and import labs',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
