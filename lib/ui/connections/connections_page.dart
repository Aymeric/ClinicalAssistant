import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../controllers/health_data_controller.dart';
import '../../data/vault_security_service.dart';
import '../../integrations/fhir_file_import.dart';
import '../../integrations/fhir_provider_presets.dart';
import '../../models/health_record.dart';
import '../../notifications/result_notification_manager.dart';
import '../../notifications/result_notification_settings.dart';
import '../../sync/foreground_sync_state.dart';
import '../../sync/import_progress.dart';
import '../../sync/source_import_history.dart';
import '../overview/overview_page.dart';
import '../security/privacy_policy_page.dart';
import '../security/vault_security_card.dart';
import '../shared/record_widgets.dart';

class ConnectionsPage extends StatelessWidget {
  const ConnectionsPage({
    super.key,
    required this.busy,
    required this.healthRecordCount,
    required this.fhirRecordCount,
    this.healthRawSampleCount,
    required this.syncState,
    required this.syncSettingsLoading,
    required this.syncing,
    required this.syncStatus,
    required this.onHealthImport,
    required this.onFhirImport,
    required this.onHealthAutoSyncChanged,
    required this.onFhirAutoSyncDisabled,
    required this.onSyncNow,
    required this.onDeleteRecords,
    required this.notificationManager,
    required this.syncValueStore,
    required this.onProgress,
    this.records = const <HealthRecord>[],
    this.importHistory = const <SourceImportEvent>[],
    this.syntheticRecordCount = 0,
    this.onLoadSyntheticDemo,
    this.onClearSyntheticDemo,
    this.onImportFhirJson,
    this.onImportFhirFiles,
    this.fhirFilePickerService,
    this.onRestoreVaultBackup,
    this.onExportVaultBackup,
    this.vaultSecurityService,
    this.onLockVault,
    required this.onOpenGuidelines,
    this.onResetHealthSyncAnchor,
  });

  final bool busy;
  final int healthRecordCount;
  final int? healthRawSampleCount;
  final int fhirRecordCount;
  final int syntheticRecordCount;
  final List<HealthRecord> records;
  final List<SourceImportEvent> importHistory;
  final ForegroundSyncState? syncState;
  final bool syncSettingsLoading;
  final bool syncing;
  final String? syncStatus;
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
  final Future<void> Function(List<FhirFilePayload> files, {String? source})?
  onImportFhirFiles;
  final FhirFilePickerService? fhirFilePickerService;
  final VoidCallback? onRestoreVaultBackup;
  final VoidCallback? onExportVaultBackup;
  final VaultSecurityService? vaultSecurityService;
  final VoidCallback? onLockVault;
  final VoidCallback onOpenGuidelines;
  final VoidCallback? onResetHealthSyncAnchor;

  @override
  Widget build(BuildContext context) {
    final effectiveHealthRawCount =
        healthRawSampleCount ??
        countRawSamples(records.where(isHealthPlatformRecord));
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
          onResetHealthSyncAnchor: onResetHealthSyncAnchor,
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
            rawCount: effectiveHealthRawCount,
            connected:
                healthRecordCount > 0 ||
                (syncState?.healthAutoSync == true &&
                    syncState?.lastHealthSyncAt != null),
            busy: busy,
            hasAnchor: syncState?.hasHealthSyncAnchor ?? false,
            onResetAnchor: onResetHealthSyncAnchor,
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
            rawCount: effectiveHealthRawCount,
            connected:
                healthRecordCount > 0 ||
                (syncState?.healthAutoSync == true &&
                    syncState?.lastHealthSyncAt != null),
            busy: busy,
            hasAnchor: syncState?.hasHealthSyncAnchor ?? false,
            onResetAnchor: onResetHealthSyncAnchor,
            buttonLabel: 'Connect Health Connect',
            onPressed: busy ? null : onHealthImport,
          ),
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
        FhirJsonImportCard(
          busy: busy,
          onImport: onImportFhirJson,
          onImportFiles: onImportFhirFiles,
          filePickerService: fhirFilePickerService,
        ),
        const SizedBox(height: 14),
        SourceCoverageAndHistoryCard(
          records: records,
          importHistory: importHistory,
        ),
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
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    TextButton.icon(
                      onPressed: busy ? null : onDeleteRecords,
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Delete records from this device'),
                    ),
                    TextButton.icon(
                      key: const ValueKey('privacy-policy-entry'),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const PrivacyPolicyPage(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.shield_outlined),
                      label: const Text('Privacy & data governance'),
                    ),
                  ],
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
                  tooltip: _obscurePassphrase
                      ? 'Show passphrase'
                      : 'Hide passphrase',
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
  const FhirJsonImportCard({
    super.key,
    required this.busy,
    this.onImport,
    this.onImportFiles,
    this.filePickerService,
  });

  final bool busy;
  final Future<void> Function(String json, {String source})? onImport;
  final Future<void> Function(List<FhirFilePayload> files, {String? source})?
  onImportFiles;
  final FhirFilePickerService? filePickerService;

  Future<void> _pickAndOpenFiles(BuildContext context) async {
    final picker = filePickerService ?? const FhirFilePickerService();
    try {
      final files = await picker.pickFiles();
      if (files == null || files.isEmpty || !context.mounted) return;
      _openImportSheet(context, initialFiles: files);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to pick FHIR files: ${e.toString().replaceFirst('Exception: ', '')}',
            ),
          ),
        );
      }
    }
  }

  void _openImportSheet(
    BuildContext context, {
    List<FhirFilePayload>? initialFiles,
  }) {
    if (onImport == null && onImportFiles == null) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => FhirJsonImportSheet(
        initialFiles: initialFiles,
        filePickerService: filePickerService,
        onImportFiles: (files, source) async {
          Navigator.pop(sheetContext);
          if (onImportFiles != null) {
            await onImportFiles!(files, source: source);
          } else if (onImport != null) {
            for (final f in files) {
              await onImport!(f.content, source: source ?? f.name);
            }
          }
        },
        onImportJson: (json, source) async {
          Navigator.pop(sheetContext);
          if (onImport != null) {
            await onImport!(json, source: source);
          } else if (onImportFiles != null) {
            await onImportFiles!([
              FhirFilePayload(name: source, content: json),
            ], source: source);
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEnabled = !busy && (onImport != null || onImportFiles != null);

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
                        'Direct FHIR JSON & file import',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Choose file(s) or paste Observations & Bundles',
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
              'Import clinical records from local FHIR JSON files or sandbox exports into your local encrypted vault.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.tonalIcon(
                  key: const ValueKey('connection-pick-fhir-file-button'),
                  onPressed: isEnabled
                      ? () => _pickAndOpenFiles(context)
                      : null,
                  icon: const Icon(Icons.upload_file_outlined, size: 18),
                  label: const Text('Choose FHIR File(s)'),
                ),
                OutlinedButton.icon(
                  key: const ValueKey('connection-import-fhir-json-button'),
                  onPressed: isEnabled ? () => _openImportSheet(context) : null,
                  icon: const Icon(Icons.paste_outlined, size: 18),
                  label: const Text('Paste FHIR JSON'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class FhirJsonImportSheet extends StatefulWidget {
  const FhirJsonImportSheet({
    super.key,
    this.initialFiles,
    this.onImportFiles,
    this.onImportJson,
    this.onImport,
    this.filePickerService,
  });

  final List<FhirFilePayload>? initialFiles;
  final Future<void> Function(List<FhirFilePayload> files, String? source)?
  onImportFiles;
  final Future<void> Function(String json, String source)? onImportJson;
  final Future<void> Function(String json, String source)? onImport;
  final FhirFilePickerService? filePickerService;

  @override
  State<FhirJsonImportSheet> createState() => _FhirJsonImportSheetState();
}

class _FhirJsonImportSheetState extends State<FhirJsonImportSheet> {
  late final List<FhirFilePayload> _files;
  final _jsonController = TextEditingController();
  late final TextEditingController _sourceController;
  bool _importing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _files = widget.initialFiles != null
        ? List<FhirFilePayload>.from(widget.initialFiles!)
        : <FhirFilePayload>[];

    final defaultSource = _files.length == 1
        ? _files.first.name
        : (_files.length > 1
              ? 'FHIR Import (${_files.length} files)'
              : 'FHIR Import');
    _sourceController = TextEditingController(text: defaultSource);
    _jsonController.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _jsonController.removeListener(_onTextChanged);
    _jsonController.dispose();
    _sourceController.dispose();
    super.dispose();
  }

  Future<void> _pickMoreFiles() async {
    final picker = widget.filePickerService ?? const FhirFilePickerService();
    try {
      final picked = await picker.pickFiles();
      if (picked != null && picked.isNotEmpty && mounted) {
        setState(() {
          _files.addAll(picked);
          if (_files.length > 1 &&
              _sourceController.text.startsWith('FHIR Import')) {
            _sourceController.text = 'FHIR Import (${_files.length} files)';
          } else if (_files.length == 1) {
            _sourceController.text = _files.first.name;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error =
              'Failed picking files: ${e.toString().replaceFirst('Exception: ', '')}';
        });
      }
    }
  }

  void _removeFile(int index) {
    setState(() {
      _files.removeAt(index);
      if (_files.length == 1) {
        _sourceController.text = _files.first.name;
      } else if (_files.isEmpty) {
        _sourceController.text = 'FHIR Import';
      } else {
        _sourceController.text = 'FHIR Import (${_files.length} files)';
      }
    });
  }

  FhirFilesImportSummary _computeSummary() {
    if (_files.isNotEmpty) {
      return FhirFilesImportSummary.fromPayloads(_files);
    }
    final text = _jsonController.text.trim();
    if (text.isNotEmpty) {
      final payload = FhirFilePayload(
        name: _sourceController.text.trim().isEmpty
            ? 'Pasted FHIR'
            : _sourceController.text.trim(),
        content: text,
      );
      return FhirFilesImportSummary.fromPayloads([payload]);
    }
    return const FhirFilesImportSummary(previews: []);
  }

  Future<void> _submit() async {
    final summary = _computeSummary();
    if (summary.hasErrors) {
      setState(() {
        _error =
            'Cannot import: Please resolve or remove invalid files before proceeding.';
      });
      return;
    }

    if (summary.totalRecords == 0) {
      setState(() {
        _error = 'No supported clinical resources were found to import.';
      });
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
      if (_files.isNotEmpty) {
        if (widget.onImportFiles != null) {
          await widget.onImportFiles!(_files, source);
        } else if (widget.onImportJson != null) {
          for (final f in _files) {
            await widget.onImportJson!(f.content, source);
          }
        } else if (widget.onImport != null) {
          for (final f in _files) {
            await widget.onImport!(f.content, source);
          }
        }
      } else {
        final text = _jsonController.text.trim();
        if (widget.onImportJson != null) {
          await widget.onImportJson!(text, source);
        } else if (widget.onImport != null) {
          await widget.onImport!(text, source);
        } else if (widget.onImportFiles != null) {
          await widget.onImportFiles!([
            FhirFilePayload(name: source, content: text),
          ], source);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e
              .toString()
              .replaceFirst('FormatException: ', '')
              .replaceFirst('Exception: ', '');
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _importing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final summary = _computeSummary();

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
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _files.isNotEmpty
                            ? 'FHIR File Import'
                            : 'Import FHIR JSON',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Review supported clinical resources before importing into your local vault.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_files.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Selected Files (${_files.length})',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextButton.icon(
                    key: const ValueKey('fhir-sheet-add-more-files-button'),
                    onPressed: _importing ? null : _pickMoreFiles,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add files'),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ..._files.asMap().entries.map((entry) {
                final index = entry.key;
                final file = entry.value;
                final preview = FhirFilePreview.fromPayload(file);
                final isValid = preview.isValid;

                return Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 8),
                  color: isValid
                      ? theme.colorScheme.surfaceContainer
                      : theme.colorScheme.errorContainer.withValues(alpha: 0.3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                      color: isValid
                          ? theme.colorScheme.outlineVariant.withValues(
                              alpha: 0.5,
                            )
                          : theme.colorScheme.error.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              isValid
                                  ? Icons.insert_drive_file_outlined
                                  : Icons.error_outline,
                              color: isValid
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.error,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                preview.fileName,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (preview.formattedSize.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Text(
                                preview.formattedSize,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                            IconButton(
                              key: ValueKey(
                                'fhir-file-remove-${preview.fileName}',
                              ),
                              icon: const Icon(Icons.close, size: 18),
                              tooltip: 'Remove file',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: _importing
                                  ? null
                                  : () => _removeFile(index),
                            ),
                          ],
                        ),
                        if (isValid) ...[
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: preview.resourceCounts.entries.map((c) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${c.key}: ${c.value}',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.onPrimaryContainer,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ] else ...[
                          const SizedBox(height: 4),
                          Text(
                            preview.error ?? 'Invalid FHIR file',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.error,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }),
            ] else ...[
              Center(
                child: OutlinedButton.icon(
                  key: const ValueKey('fhir-sheet-choose-files-button'),
                  onPressed: _importing ? null : _pickMoreFiles,
                  icon: const Icon(Icons.upload_file_outlined, size: 18),
                  label: const Text('Choose FHIR File(s)'),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      'OR PASTE FHIR JSON',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('fhir-json-input-field'),
                controller: _jsonController,
                maxLines: 6,
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
            ],
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
            if (summary.totalRecords > 0 || summary.hasErrors) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: summary.hasErrors
                      ? theme.colorScheme.errorContainer.withValues(alpha: 0.4)
                      : theme.colorScheme.secondaryContainer.withValues(
                          alpha: 0.4,
                        ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: summary.hasErrors
                        ? theme.colorScheme.error.withValues(alpha: 0.5)
                        : theme.colorScheme.secondary.withValues(alpha: 0.5),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          summary.hasErrors
                              ? Icons.warning_amber_rounded
                              : Icons.check_circle_outline,
                          size: 18,
                          color: summary.hasErrors
                              ? theme.colorScheme.error
                              : theme.colorScheme.secondary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            summary.hasErrors
                                ? 'One or more files have errors and cannot be imported.'
                                : 'Ready to import ${summary.totalRecords} record${summary.totalRecords == 1 ? '' : 's'}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: summary.hasErrors
                                  ? theme.colorScheme.error
                                  : theme.colorScheme.onSecondaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (!summary.hasErrors &&
                        summary.aggregatedResourceCounts.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: summary.aggregatedResourceCounts.entries.map((
                          c,
                        ) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${c.key}: ${c.value}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: TextStyle(color: theme.colorScheme.error, fontSize: 13),
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
                  onPressed:
                      _importing ||
                          summary.hasErrors ||
                          summary.totalRecords == 0
                      ? null
                      : _submit,
                  child: _importing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          summary.totalRecords > 0
                              ? 'Import ${summary.totalRecords} records'
                              : 'Import records',
                        ),
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
              'Load synthetic demonstration records (labs, vital signs, daily steps, and medications) spanning recent months to explore trends, charts, exports, and medication management.',
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
    this.onResetHealthSyncAnchor,
  });

  final ForegroundSyncState? state;
  final bool loading;
  final bool syncing;
  final bool healthSyncAvailable;
  final String? status;
  final ValueChanged<bool> onHealthAutoSyncChanged;
  final VoidCallback onSyncNow;
  final VoidCallback? onResetHealthSyncAnchor;

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
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: loading || syncing || !hasAutoSync
                      ? null
                      : onSyncNow,
                  icon: const Icon(Icons.sync),
                  label: Text(
                    syncing ? 'Syncing...' : 'Sync enabled sources now',
                  ),
                ),
                if (state?.hasHealthSyncAnchor == true &&
                    onResetHealthSyncAnchor != null)
                  TextButton.icon(
                    key: const ValueKey('reset-sync-anchor-foreground-button'),
                    onPressed: loading || syncing
                        ? null
                        : onResetHealthSyncAnchor,
                    icon: const Icon(Icons.restart_alt, size: 18),
                    label: const Text('Reset health anchor'),
                  ),
              ],
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
  String? _selectedPresetId = 'custom';

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
      if (_baseController.text.isNotEmpty) {
        final matchedPreset = FhirProviderPreset.findByBaseUrl(
          _baseController.text,
        );
        _selectedPresetId = matchedPreset?.id ?? 'custom';
      }
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
              DropdownButtonFormField<String>(
                key: const ValueKey('fhir-preset-dropdown'),
                decoration: const InputDecoration(
                  labelText: 'Provider / Sandbox Preset',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.dns_outlined),
                ),
                initialValue: _selectedPresetId,
                isExpanded: true,
                items: [
                  const DropdownMenuItem(
                    value: 'custom',
                    child: Text('Custom FHIR Server (Manual URL)'),
                  ),
                  ...FhirProviderPreset.standardPresets.map(
                    (preset) => DropdownMenuItem(
                      value: preset.id,
                      child: Text(preset.name, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ],
                onChanged: widget.busy || _loadingConfig
                    ? null
                    : (id) {
                        setState(() {
                          _selectedPresetId = id;
                          if (id != null && id != 'custom') {
                            final preset = FhirProviderPreset.standardPresets
                                .firstWhere((p) => p.id == id);
                            _baseController.text = preset.baseUrl;
                            if (preset.defaultClientId != null &&
                                preset.defaultClientId!.isNotEmpty &&
                                _clientController.text.trim().isEmpty) {
                              _clientController.text = preset.defaultClientId!;
                            }
                          }
                        });
                      },
              ),
              if (_selectedPresetId != null &&
                  _selectedPresetId != 'custom') ...[
                const SizedBox(height: 12),
                Builder(
                  builder: (context) {
                    final preset = FhirProviderPreset.standardPresets
                        .firstWhere((p) => p.id == _selectedPresetId);
                    if (preset.instructions == null) {
                      return const SizedBox.shrink();
                    }
                    return Card(
                      color: theme.colorScheme.secondaryContainer.withValues(
                        alpha: 0.35,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 18,
                              color: theme.colorScheme.secondary,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                preset.instructions!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSecondaryContainer,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
              const SizedBox(height: 12),
              Card(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.45,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.link, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'OAuth 2.0 Redirect URI',
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              FhirProviderPreset.appRedirectUri,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontFamily: 'monospace',
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 16),
                        tooltip: 'Copy redirect URI',
                        onPressed: () {
                          Clipboard.setData(
                            const ClipboardData(
                              text: FhirProviderPreset.appRedirectUri,
                            ),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Redirect URI copied to clipboard'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
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

class SourceCoverageAndHistoryCard extends StatefulWidget {
  const SourceCoverageAndHistoryCard({
    super.key,
    required this.records,
    required this.importHistory,
  });

  final List<HealthRecord> records;
  final List<SourceImportEvent> importHistory;

  @override
  State<SourceCoverageAndHistoryCard> createState() =>
      _SourceCoverageAndHistoryCardState();
}

class _SourceCoverageAndHistoryCardState
    extends State<SourceCoverageAndHistoryCard> {
  static const _initialVisibleEvents = 5;
  bool _showAllEvents = false;

  String _formatDateSpan(DateTime? oldest, DateTime? newest) {
    if (oldest == null || newest == null) {
      return 'No records stored yet';
    }
    final start = formatRecordDate(oldest);
    final end = formatRecordDate(newest);
    if (start == end) {
      return 'Observed date: $start';
    }
    return 'Observed span: $start – $end';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final summaries = buildSourceCoverageSummaries(
      widget.records,
      widget.importHistory,
    );
    final visibleHistory = _showAllEvents
        ? widget.importHistory
        : widget.importHistory.take(_initialVisibleEvents).toList();

    return Card(
      key: const ValueKey('source-coverage-history-card'),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconStamp(
                  icon: Icons.history_edu_outlined,
                  background: theme.colorScheme.secondaryContainer,
                  foreground: theme.colorScheme.onSecondaryContainer,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Import coverage & activity history',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Observed record date spans and recent sync outcomes per source',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              key: const ValueKey('source-coverage-disclaimer'),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.45,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Observed date spans reflect only the earliest and latest records returned by each source. Platform permissions and clinical portal availability limit what is shared and do not guarantee a complete medical history.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Per-source coverage',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < summaries.length; i++) ...[
              if (i > 0) const Divider(height: 18),
              _SourceCoverageSummaryRow(
                summary: summaries[i],
                dateSpanLabel: _formatDateSpan(
                  summaries[i].oldestRecordedAt,
                  summaries[i].newestRecordedAt,
                ),
              ),
            ],
            const SizedBox(height: 18),
            Text(
              'Recent import & sync activity',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            if (widget.importHistory.isEmpty)
              Text(
                'No import or sync checks recorded on this device yet.',
                key: const ValueKey('source-import-history-empty'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else
              Column(
                key: const ValueKey('source-import-history-list'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < visibleHistory.length; i++) ...[
                    if (i > 0) const Divider(height: 16),
                    _SourceImportEventRow(event: visibleHistory[i]),
                  ],
                  if (widget.importHistory.length > _initialVisibleEvents) ...[
                    const SizedBox(height: 8),
                    TextButton.icon(
                      key: const ValueKey('source-import-history-toggle'),
                      onPressed: () =>
                          setState(() => _showAllEvents = !_showAllEvents),
                      icon: Icon(
                        _showAllEvents ? Icons.expand_less : Icons.expand_more,
                        size: 18,
                      ),
                      label: Text(
                        _showAllEvents
                            ? 'Show fewer'
                            : 'Show all (${widget.importHistory.length})',
                      ),
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

class _SourceCoverageSummaryRow extends StatelessWidget {
  const _SourceCoverageSummaryRow({
    required this.summary,
    required this.dateSpanLabel,
  });

  final SourceCoverageSummary summary;
  final String dateSpanLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lastEvent = summary.lastEvent;
    final baseCountLabel = summary.recordCount == 1
        ? '1 record stored'
        : '${summary.recordCount} records stored';
    final countLabel = summary.rawSampleCount > summary.recordCount
        ? '$baseCountLabel (${summary.rawSampleCount} raw samples)'
        : baseCountLabel;

    return Column(
      key: ValueKey('source-coverage-row-${summary.sourceKind.storageKey}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              summary.sourceLabel,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                countLabel,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (lastEvent != null)
              _SourceOutcomeStatusBadge(status: lastEvent.status),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          dateSpanLabel,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (summary.distinctSourceNames.length > 1 ||
            (summary.distinctSourceNames.length == 1 &&
                summary.distinctSourceNames.first != summary.sourceLabel)) ...[
          const SizedBox(height: 2),
          Text(
            'Sources: ${summary.distinctSourceNames.join(', ')}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        if (lastEvent != null) ...[
          const SizedBox(height: 2),
          Text(
            'Last check: ${formatSyncTimestamp(lastEvent.timestamp)} (${lastEvent.isAutoSync ? 'Auto sync' : 'Manual import'})',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

class _SourceImportEventRow extends StatelessWidget {
  const _SourceImportEventRow({required this.event});

  final SourceImportEvent event;

  String _buildOutcomeDescription() {
    final mode = event.isAutoSync ? 'Auto sync' : 'Manual import';
    switch (event.status) {
      case SourceImportOutcomeStatus.succeeded:
        final details = event.fetchedRawSampleCount > event.fetchedCount
            ? '${event.fetchedRawSampleCount} raw samples, ${event.addedCount} new'
            : '${event.addedCount} new';
        final base = '$mode · ${event.fetchedCount} returned ($details)';
        if (event.oldestRecordAt != null && event.newestRecordAt != null) {
          final start = formatRecordDate(event.oldestRecordAt!);
          final end = formatRecordDate(event.newestRecordAt!);
          final span = start == end ? start : '$start – $end';
          return '$base · Span: $span';
        }
        return base;
      case SourceImportOutcomeStatus.empty:
        return '$mode · Checked source, 0 records returned';
      case SourceImportOutcomeStatus.failed:
        final reason =
            event.errorSummary ?? 'Source check could not be completed.';
        return '$mode · Failed: $reason';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isFailed = event.status == SourceImportOutcomeStatus.failed;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              event.sourceLabel,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            _SourceOutcomeStatusBadge(status: event.status),
            Text(
              formatSyncTimestamp(event.timestamp),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          _buildOutcomeDescription(),
          style: theme.textTheme.bodySmall?.copyWith(
            color: isFailed
                ? theme.colorScheme.error
                : theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _SourceOutcomeStatusBadge extends StatelessWidget {
  const _SourceOutcomeStatusBadge({required this.status});

  final SourceImportOutcomeStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (Color bg, Color fg, IconData icon) = switch (status) {
      SourceImportOutcomeStatus.succeeded => (
        colors.primaryContainer,
        colors.onPrimaryContainer,
        Icons.check_circle_outline,
      ),
      SourceImportOutcomeStatus.empty => (
        colors.secondaryContainer,
        colors.onSecondaryContainer,
        Icons.remove_circle_outline,
      ),
      SourceImportOutcomeStatus.failed => (
        colors.errorContainer,
        colors.onErrorContainer,
        Icons.error_outline,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: fg),
          const SizedBox(width: 4),
          Text(
            status.badgeLabel,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}
