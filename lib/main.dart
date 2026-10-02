import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import 'controllers/health_data_controller.dart';
import 'data/vault_security_service.dart';
import 'exports/health_export_service.dart';
import 'guidelines/guidelines_library_page.dart';
import 'models/health_record.dart';
import 'notifications/result_notification_manager.dart';
import 'records/manual_record_edit_sheet.dart';
import 'records/manual_record_entry_sheet.dart';
import 'sync/foreground_sync_state.dart';
import 'sync/import_progress.dart';
import 'trends/health_trend.dart';
import 'trends/health_trends_page.dart';
import 'ui/connections/connections_page.dart';
import 'ui/export/export_page.dart';
import 'ui/medications/medications_page.dart';
import 'ui/overview/overview_page.dart';
import 'ui/records/record_details_sheet.dart';
import 'ui/records/records_page.dart';
import 'ui/security/vault_lock_screen.dart';
import 'ui/shared/record_widgets.dart';

export 'controllers/health_data_controller.dart';
export 'ui/records/records_page.dart' show RecordSortOrder;

void main() {
  runApp(const ClinicalAssistantApp());
}

class ClinicalAssistantApp extends StatelessWidget {
  const ClinicalAssistantApp({
    super.key,
    this.controller,
    this.vaultSecurityService,
  });

  static const _ink = Color(0xFF153E45);
  static const _teal = Color(0xFF17645E);
  static const _mutedInk = Color(0xFF52696B);

  final HealthDataController? controller;
  final VaultSecurityService? vaultSecurityService;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Clinical Assistant',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      home: HealthHome(
        controller: controller,
        vaultSecurityService: vaultSecurityService,
      ),
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: _teal,
          brightness: brightness,
          surface: isLight ? const Color(0xFFFAFBFA) : const Color(0xFF17211F),
        ).copyWith(
          onSurface: isLight ? _ink : null,
          onSurfaceVariant: isLight ? _mutedInk : null,
        );
    final scaffoldBackgroundColor = isLight
        ? const Color(0xFFF4F7F6)
        : const Color(0xFF101816);
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scaffoldBackgroundColor,
      appBarTheme: AppBarTheme(
        backgroundColor: scaffoldBackgroundColor,
        foregroundColor: colorScheme.onSurface,
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(
        color: isLight ? Colors.white : colorScheme.surfaceContainerLow,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        },
      ),
    );
  }
}

class HealthHome extends StatefulWidget {
  const HealthHome({
    super.key,
    this.controller,
    this.notificationManager,
    this.vaultSecurityService,
  });

  final HealthDataController? controller;
  final ResultNotificationManager? notificationManager;
  final VaultSecurityService? vaultSecurityService;

  @override
  State<HealthHome> createState() => _HealthHomeState();
}

class _HealthHomeState extends State<HealthHome> with WidgetsBindingObserver {
  late final _controller = widget.controller ?? HealthDataController();
  late final _notificationManager =
      widget.notificationManager ??
      LocalResultNotificationManager(onNotificationTap: _openRecords);
  late final _vaultSecurityService =
      widget.vaultSecurityService ??
      VaultSecurityService(storage: widget.controller?.syncValueStore);
  final _exporter = HealthExportService();
  var _selectedIndex = 0;
  var _since = DateTime(1900);
  var _exporting = false;
  var _syncSettingsLoading = true;
  var _syncing = false;
  var _initialLoadFinished = false;
  var _isVaultLocked = false;
  RecordCategory? _preselectedCategoryFilter;
  bool _recordsPageInitialOutOfRange = false;
  String? _trendInitialSeriesId;
  ForegroundSyncState? _syncState;
  String? _syncStatus;
  ImportProgress? _operationProgress;
  DateTime? _lastForegroundSyncAttempt;

  Set<String> _pinnedSeries = {};

  static const _titles = [
    'Overview',
    'Trends',
    'Records',
    'Connections',
    'Export',
  ];
  static const _foregroundSyncCooldown = Duration(minutes: 5);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller.addListener(_onControllerChanged);
    unawaited(_loadInitialState());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _vaultSecurityService.onAppBackgrounded();
    } else if (state == AppLifecycleState.resumed) {
      _checkLockOnResume();
      if (_initialLoadFinished) {
        unawaited(_syncEnabledSources());
      }
    }
  }

  Future<void> _checkLockOnResume() async {
    final shouldLock = await _vaultSecurityService.shouldLockOnResume();
    if (shouldLock && mounted) {
      setState(() => _isVaultLocked = true);
    }
  }

  Future<void> _loadInitialState() async {
    await _controller.load();
    if (!mounted) return;
    try {
      final hasPin = await _vaultSecurityService.isPinConfigured();
      if (hasPin && mounted) {
        setState(() => _isVaultLocked = true);
      }
    } catch (_) {}
    try {
      final syncState = await _controller.loadForegroundSyncState();
      final pinned = await _controller.pinnedPreferences.getPinnedSeries();
      if (!mounted) return;
      setState(() {
        _syncState = syncState;
        _pinnedSeries = pinned;
        _syncSettingsLoading = false;
        _initialLoadFinished = true;
      });
      if (syncState.hasAutoSync && _controller.error == null) {
        await _syncEnabledSources(force: true);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _syncStatus = 'Sync settings could not be loaded: $error';
        _syncSettingsLoading = false;
        _initialLoadFinished = true;
      });
    }
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  void _openRecords() {
    if (mounted) {
      setState(() {
        _recordsPageInitialOutOfRange = false;
        _selectedIndex = 2;
      });
    }
  }

  void _openRecordsWithCategory(RecordCategory category) {
    if (mounted) {
      setState(() {
        _preselectedCategoryFilter = category;
        _recordsPageInitialOutOfRange = false;
        _selectedIndex = 2;
      });
    }
  }

  void _openRecordsWithOutOfRange() {
    if (mounted) {
      setState(() {
        _preselectedCategoryFilter = null;
        _recordsPageInitialOutOfRange = true;
        _selectedIndex = 2;
      });
    }
  }

  void _onViewInTrends(HealthRecord record) {
    final seriesId = healthTrendSeriesId(record);
    if (mounted) {
      setState(() {
        _trendInitialSeriesId = seriesId;
        _selectedIndex = 1;
      });
    }
  }

  void _openGuidelines() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const GuidelinesLibraryPage()),
    );
  }

  void _openMedications() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MedicationsPage(
          controller: _controller,
          onRecordTap: _showRecordDetails,
        ),
      ),
    );
  }

  Future<void> _openManualRecordEntry() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => ManualRecordEntrySheet(
        onSave: (newRecords) async {
          await _controller.addManualRecords(newRecords);
          if (mounted) {
            _showMessage(
              newRecords.length == 1
                  ? 'Saved ${newRecords.first.name} to vault.'
                  : 'Saved ${newRecords.length} measurements to vault.',
            );
          }
        },
      ),
    );
  }

  Future<void> _showRecordDetails(HealthRecord record) async {
    final isNumeric = parseHealthRecordValue(record.value) != null;
    final seriesId = healthTrendSeriesId(record);
    final isPinned = _pinnedSeries.contains(seriesId);

    final editRequested = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => RecordDetailsSheet(
        record: record,
        isNumeric: isNumeric,
        isPinned: isPinned,
        onTogglePin: () async {
          final newState = await _controller.pinnedPreferences.togglePin(
            seriesId,
          );
          if (mounted) {
            setState(() {
              if (newState) {
                _pinnedSeries.add(seriesId);
              } else {
                _pinnedSeries.remove(seriesId);
              }
            });
            _showMessage(
              newState ? 'Pinned to Overview' : 'Unpinned from Overview',
            );
          }
        },
        onSaveNotes: (notes) async {
          await _controller.updateRecordNotes(record.id, notes);
          if (mounted) {
            _showMessage('Personal note saved.');
          }
        },
        onDelete: record.isManual
            ? () async {
                await _controller.deleteRecord(record.id);
                if (sheetContext.mounted) {
                  Navigator.pop(sheetContext);
                }
                if (mounted) {
                  _showMessage('Measurement deleted.');
                }
              }
            : null,
        onEdit: record.isManual
            ? () => Navigator.pop(sheetContext, true)
            : null,
        onViewInTrends: isNumeric
            ? () {
                Navigator.pop(sheetContext);
                _onViewInTrends(record);
              }
            : null,
      ),
    );
    if (editRequested == true && mounted) {
      await _editManualRecords(record);
    }
  }

  Future<void> _editManualRecords(HealthRecord record) async {
    final recordsToEdit = <HealthRecord>[record];
    final match = RegExp(r'^manual:(sys|dia):(.+)$').firstMatch(record.id);
    if (match != null) {
      final siblingType = match[1] == 'sys' ? 'dia' : 'sys';
      final siblingId = 'manual:$siblingType:${match[2]}';
      HealthRecord? sibling;
      for (final candidate in _controller.records) {
        if (candidate.id == siblingId && candidate.isManual) {
          sibling = candidate;
          break;
        }
      }
      if (sibling != null) {
        recordsToEdit
          ..add(sibling)
          ..sort((a, b) {
            if (a.name == 'Systolic Blood Pressure') return -1;
            if (b.name == 'Systolic Blood Pressure') return 1;
            return 0;
          });
      }
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => ManualRecordEditSheet(
        records: recordsToEdit,
        onSave: (editedRecords) async {
          await _controller.updateManualRecords(editedRecords);
          if (mounted) _showMessage('Manual measurement updated.');
        },
      ),
    );
  }

  Future<void> _importHealth() async {
    await _runAction(
      (onProgress) =>
          _controller.importHealth(since: _since, onProgress: onProgress),
    );
    await _reloadSyncState();
  }

  Future<void> _loadSyntheticDemo() async {
    await _runAction(
      (onProgress) =>
          _controller.loadSyntheticDemoRecords(onProgress: onProgress),
    );
  }

  Future<void> _clearSyntheticDemo() async {
    try {
      final removed = await _controller.clearSyntheticDemoRecords();
      if (mounted) {
        _showMessage(
          removed > 0
              ? 'Removed $removed demonstration records.'
              : 'No demonstration records to remove.',
        );
      }
    } catch (error) {
      if (mounted) _showMessage('Could not remove demo records: $error');
    }
  }

  Future<void> _importFhirJson(
    String jsonString, {
    String source = 'FHIR File',
  }) async {
    await _runAction(
      (onProgress) => _controller.importFhirJson(
        jsonString,
        source: source,
        onProgress: onProgress,
      ),
    );
  }

  Future<FhirConnectionOutcome?> _importFhir({
    required String baseUrl,
    required String clientId,
    required bool rememberPortalForAutoSync,
    required ImportProgressCallback onProgress,
  }) async {
    _reportProgress(
      const ImportProgress(fraction: 0, message: 'Starting portal import'),
    );
    try {
      final outcome = await _controller.connectFhir(
        baseUrl: baseUrl,
        clientId: clientId,
        rememberPortalForAutoSync: rememberPortalForAutoSync,
        onProgress: onProgress,
      );
      if (!mounted) return outcome;
      try {
        await _notificationManager.notifyForImport(
          newlyImported: outcome.newlyImported,
          allRecords: _controller.records,
        );
      } catch (error) {
        _showMessage(
          'Records saved, but a notification could not be sent: $error',
        );
        await _reloadSyncState();
        return outcome;
      }
      await _reloadSyncState();
      if (outcome.autoSyncUnavailable) {
        _showMessage(
          'The portal did not provide a refresh token. Records were imported, but portal auto-sync is unavailable.',
        );
      } else if (outcome.fetchedRecordCount == 0) {
        _showMessage('Connected, but the portal returned no lab results.');
      } else if (outcome.newlyImported.isEmpty) {
        _showMessage('Portal import complete. No new lab results were found.');
      } else {
        _showMessage(
          'Portal import complete. New records are saved on this device.',
        );
      }
      _finishProgress('Portal import complete');
      return outcome;
    } catch (error) {
      if (mounted) _showMessage(displayError(error));
      return null;
    } finally {
      await _finishAndClearProgress();
    }
  }

  Future<void> _onHealthAutoSyncChanged(bool enabled) async {
    try {
      await _controller.setHealthAutoSync(enabled);
      await _reloadSyncState();
      if (enabled) {
        await _syncEnabledSources(force: true, userInitiated: true);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _syncStatus = 'Could not update sync settings: $error');
      }
    }
  }

  Future<void> _disableFhirAutoSync() async {
    await _controller.disableFhirAutoSync();
    await _reloadSyncState();
  }

  Future<void> _reloadSyncState() async {
    try {
      final syncState = await _controller.loadForegroundSyncState();
      if (mounted) setState(() => _syncState = syncState);
    } catch (error) {
      if (mounted) {
        setState(
          () => _syncStatus = 'Sync settings could not be loaded: $error',
        );
      }
    }
  }

  Future<void> _syncEnabledSources({
    bool force = false,
    bool userInitiated = false,
  }) async {
    if (!_initialLoadFinished ||
        _controller.error != null ||
        _controller.loading ||
        _controller.busy ||
        _syncing) {
      return;
    }
    final now = DateTime.now();
    if (!force &&
        _lastForegroundSyncAttempt != null &&
        now.difference(_lastForegroundSyncAttempt!) < _foregroundSyncCooldown) {
      return;
    }
    final syncState = _syncState;
    if (syncState == null || !syncState.hasAutoSync) return;

    _lastForegroundSyncAttempt = now;
    setState(() {
      _syncing = true;
      _syncStatus = 'Checking connected sources...';
    });
    final newRecords = <HealthRecord>[];
    final failures = <String>[];
    final sourceCount =
        (syncState.healthAutoSync ? 1 : 0) + (syncState.fhirAutoSync ? 1 : 0);
    var completedSources = 0;
    void reportSourceProgress(String source, ImportProgress progress) {
      _reportProgress(
        ImportProgress(
          fraction: (completedSources + progress.fraction) / sourceCount * 0.9,
          message: '$source: ${progress.message}',
        ),
      );
    }

    _reportProgress(
      const ImportProgress(fraction: 0, message: 'Starting automatic sync'),
    );
    if (syncState.healthAutoSync) {
      try {
        newRecords.addAll(
          await _controller.syncHealth(
            onProgress: (progress) =>
                reportSourceProgress('Health platform', progress),
          ),
        );
      } catch (error) {
        failures.add('Health platform: $error');
      } finally {
        completedSources++;
      }
    }
    if (syncState.fhirAutoSync) {
      try {
        newRecords.addAll(
          await _controller.syncFhir(
            onProgress: (progress) =>
                reportSourceProgress('FHIR portal', progress),
          ),
        );
      } catch (error) {
        failures.add('FHIR portal: $error');
      } finally {
        completedSources++;
      }
    }
    _reportProgress(
      const ImportProgress(fraction: 0.93, message: 'Checking notifications'),
    );
    if (newRecords.isNotEmpty) {
      try {
        await _notificationManager.notifyForImport(
          newlyImported: newRecords,
          allRecords: _controller.records,
        );
      } catch (error) {
        failures.add('Notifications: $error');
      }
    }
    await _reloadSyncState();
    if (!mounted) return;
    final status = failures.isEmpty
        ? newRecords.isEmpty
              ? 'Sync complete. No new records were found.'
              : 'Sync complete. ${newRecords.length} new ${newRecords.length == 1 ? 'record' : 'records'} found.'
        : 'Sync needs attention: ${failures.join(' · ')}';
    setState(() {
      _syncing = false;
      _syncStatus = status;
    });
    _finishProgress('Sync complete');
    if (userInitiated) _showMessage(status);
    await _finishAndClearProgress();
  }

  Future<void> _syncNow() =>
      _syncEnabledSources(force: true, userInitiated: true);

  Future<void> _runAction(
    Future<List<HealthRecord>> Function(ImportProgressCallback onProgress)
    action,
  ) async {
    _reportProgress(
      const ImportProgress(fraction: 0, message: 'Starting import'),
    );
    try {
      final newlyImported = await action(_reportProgress);
      if (!mounted) return;
      try {
        await _notificationManager.notifyForImport(
          newlyImported: newlyImported,
          allRecords: _controller.records,
        );
      } catch (error) {
        if (mounted) {
          _showMessage(
            'Records saved, but a notification could not be sent: $error',
          );
        }
        return;
      }
      if (!mounted) return;
      _showMessage(
        'Import complete. Your updated records are saved on this device.',
      );
      _finishProgress('Import complete');
    } catch (error) {
      if (!mounted) return;
      _showMessage(displayError(error));
    } finally {
      await _finishAndClearProgress();
    }
  }

  void _reportProgress(ImportProgress progress) {
    if (mounted) setState(() => _operationProgress = progress);
  }

  void _finishProgress(String message) {
    _reportProgress(ImportProgress(fraction: 1, message: message));
  }

  Future<void> _finishAndClearProgress() async {
    if (_operationProgress?.fraction == 1) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    if (mounted) setState(() => _operationProgress = null);
  }

  Future<void> _shareExport(Future<File> Function() buildFile) async {
    setState(() => _exporting = true);
    try {
      final file = await buildFile();
      if (!mounted) return;
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)], title: 'Your health records'),
      );
    } catch (error) {
      if (mounted) {
        _showMessage('Export failed: ${error.toString()}');
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _chooseStartDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _since,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      helpText: 'IMPORT RECORDS FROM',
    );
    if (date != null) setState(() => _since = date);
  }

  Future<void> _exportVaultBackup() async {
    final passwordController = TextEditingController();
    final confirmController = TextEditingController();
    String? errorText;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Export Encrypted Vault Backup'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Create a passphrase-protected backup file. You will need this passphrase to restore your records on another device.',
              ),
              const SizedBox(height: 16),
              TextField(
                key: const ValueKey('vault-backup-password-field'),
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Passphrase (min 6 characters)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('vault-backup-confirm-field'),
                controller: confirmController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm passphrase',
                  border: OutlineInputBorder(),
                ),
              ),
              if (errorText != null) ...[
                const SizedBox(height: 10),
                Text(
                  errorText!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const ValueKey('vault-backup-confirm-button'),
              onPressed: () {
                final pass = passwordController.text;
                final confirm = confirmController.text;
                if (pass.length < 6) {
                  setDialogState(() {
                    errorText = 'Passphrase must be at least 6 characters.';
                  });
                  return;
                }
                if (pass != confirm) {
                  setDialogState(() {
                    errorText = 'Passphrases do not match.';
                  });
                  return;
                }
                Navigator.pop(dialogCtx, true);
              },
              child: const Text('Create Backup'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && mounted) {
      final pass = passwordController.text;
      try {
        final backupJson = await _controller.exportVaultBackup(pass);
        await _shareExport(() => _exporter.createVaultBackup(backupJson));
        if (mounted) {
          _showMessage('Encrypted vault backup created.');
        }
      } catch (e) {
        if (mounted) {
          _showMessage('Failed to create backup: $e');
        }
      }
    }
  }

  Future<void> _restoreVaultBackup() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => VaultRestoreSheet(
        onRestore: (backupJson, passphrase, replaceAll) async {
          final count = await _controller.restoreVaultBackup(
            backupJson,
            passphrase,
            replaceAll: replaceAll,
          );
          if (sheetContext.mounted) {
            Navigator.pop(sheetContext);
          }
          if (mounted) {
            _showMessage(
              replaceAll
                  ? 'Vault restored with $count records (replaced existing).'
                  : 'Vault restored: $count new records imported.',
            );
          }
        },
      ),
    );
  }

  Future<void> _deleteAllRecords() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete records from this device?'),
        content: const Text(
          'This permanently deletes the encrypted records stored by this app, turns off automatic sync, and removes any saved FHIR refresh token. It does not change data in Apple Health, Health Connect, or your provider portal.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete records'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _controller.clear();
      await _reloadSyncState();
      if (mounted) {
        _showMessage(
          'Records deleted. Automatic sync is off and the saved portal token was removed.',
        );
      }
    } catch (error) {
      if (mounted) _showMessage('Could not delete records: $error');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    if (_isVaultLocked) {
      return VaultLockScreen(
        securityService: _vaultSecurityService,
        onUnlocked: () => setState(() => _isVaultLocked = false),
      );
    }

    final pages = [
      OverviewPage(
        records: _controller.records,
        loading: _controller.loading,
        error: _controller.error,
        syncState: _syncState,
        syncing: _syncing,
        pinnedSeries: _pinnedSeries,
        onConnect: () => setState(() => _selectedIndex = 3),
        onSeeAll: () => setState(() => _selectedIndex = 2),
        onSelectCategory: _openRecordsWithCategory,
        onViewOutOfRangeLabs: _openRecordsWithOutOfRange,
        onRecordTap: _showRecordDetails,
        onSyncNow: _syncNow,
        onRetry: _controller.load,
        onOpenTrends: () => setState(() => _selectedIndex = 1),
        onViewInTrends: _onViewInTrends,
        onOpenRecords: () => setState(() => _selectedIndex = 2),
        onOpenExport: () => setState(() => _selectedIndex = 4),
        onOpenGuidelines: _openGuidelines,
        onLogMeasurement: _openManualRecordEntry,
        onOpenMedications: _openMedications,
      ),
      HealthTrendsPage(
        records: _controller.records,
        loading: _controller.loading,
        initialSeriesId: _trendInitialSeriesId,
        onRecordTap: _showRecordDetails,
      ),
      RecordsPage(
        records: _controller.records,
        initialCategory: _preselectedCategoryFilter,
        initialOutOfRangeOnly: _recordsPageInitialOutOfRange,
        onViewInTrends: _onViewInTrends,
        onRecordTap: _showRecordDetails,
        onRefresh: _syncNow,
        onLogRecord: _openManualRecordEntry,
      ),
      ConnectionsPage(
        busy: _controller.busy,
        healthRecordCount: _controller.healthRecordCount,
        fhirRecordCount: _controller.fhirRecordCount,
        syntheticRecordCount: _controller.syntheticRecordCount,
        since: _since,
        syncState: _syncState,
        syncSettingsLoading: _syncSettingsLoading,
        syncing: _syncing,
        syncStatus: _syncStatus,
        onChooseDate: _chooseStartDate,
        onHealthImport: _importHealth,
        onFhirImport: _importFhir,
        onLoadSyntheticDemo: _loadSyntheticDemo,
        onClearSyntheticDemo: _clearSyntheticDemo,
        onImportFhirJson: _importFhirJson,
        onHealthAutoSyncChanged: _onHealthAutoSyncChanged,
        onFhirAutoSyncDisabled: _disableFhirAutoSync,
        onSyncNow: _syncNow,
        onDeleteRecords: _deleteAllRecords,
        notificationManager: _notificationManager,
        syncValueStore: _controller.syncValueStore,
        onProgress: _reportProgress,
        onRestoreVaultBackup: _restoreVaultBackup,
        onExportVaultBackup: _exportVaultBackup,
        vaultSecurityService: _vaultSecurityService,
        onLockVault: () => setState(() {
          _vaultSecurityService.lock();
          _isVaultLocked = true;
        }),
        onOpenGuidelines: _openGuidelines,
      ),
      ExportPage(
        records: _controller.records,
        exporting: _exporting,
        onPdf: (records) => _shareExport(() => _exporter.createPdf(records)),
        onDoctorVisitPdf:
            (
              records,
              range,
              questions, {
              includeVitals = true,
              includeLabs = true,
              includeMedications = true,
              includeConditions = true,
              includeAllergies = true,
              includeQuestions = true,
            }) => _shareExport(
              () => _exporter.createDoctorVisitSummaryPdf(
                records,
                dateRange: range,
                patientQuestions: questions,
                includeVitals: includeVitals,
                includeLabs: includeLabs,
                includeMedications: includeMedications,
                includeConditions: includeConditions,
                includeAllergies: includeAllergies,
                includeQuestions: includeQuestions,
              ),
            ),
        onFhir: (records) =>
            _shareExport(() => _exporter.createFhirBundle(records)),
        onCsv: (records) => _shareExport(() => _exporter.createCsv(records)),
        onTextSummary: (records) =>
            _shareExport(() => _exporter.createTextSummary(records)),
        onCopyTextSummary: (records) async {
          await Clipboard.setData(
            ClipboardData(text: _exporter.buildTextSummary(records)),
          );
          if (mounted) {
            _showMessage('Clinical text summary copied to clipboard');
          }
        },
        onVaultBackup: _exportVaultBackup,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 760;
        return Scaffold(
          appBar: AppBar(
            title: Text(
              _titles[_selectedIndex],
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            actions: [
              IconButton(
                tooltip: 'On-device privacy',
                onPressed: () => showAboutDialog(
                  context: context,
                  applicationName: 'Clinical Assistant',
                  applicationVersion: '1.0.0',
                  children: const [
                    Text(
                      'Your records are encrypted and stored on this device. '
                      'The app does not upload them to an account or cloud service. '
                      'Exported files are shared only when you choose an app in the system share sheet.',
                    ),
                  ],
                ),
                icon: const Icon(Icons.lock_outline),
              ),
              const SizedBox(width: 8),
            ],
            bottom: _operationProgress == null
                ? null
                : PreferredSize(
                    preferredSize: const Size.fromHeight(44),
                    child: OperationProgressIndicator(
                      progress: _operationProgress!,
                    ),
                  ),
          ),
          body: Row(
            children: [
              if (wide)
                LayoutBuilder(
                  builder: (context, railConstraints) => SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: railConstraints.maxHeight,
                      ),
                      child: IntrinsicHeight(
                        child: NavigationRail(
                          selectedIndex: _selectedIndex,
                          onDestinationSelected: (index) =>
                              setState(() => _selectedIndex = index),
                          labelType: NavigationRailLabelType.all,
                          destinations: const [
                            NavigationRailDestination(
                              icon: Icon(Icons.space_dashboard_outlined),
                              selectedIcon: Icon(Icons.space_dashboard),
                              label: Text('Overview'),
                            ),
                            NavigationRailDestination(
                              icon: Icon(Icons.show_chart_outlined),
                              selectedIcon: Icon(Icons.show_chart),
                              label: Text('Trends'),
                            ),
                            NavigationRailDestination(
                              icon: Icon(Icons.list_alt_outlined),
                              selectedIcon: Icon(Icons.list_alt),
                              label: Text('Records'),
                            ),
                            NavigationRailDestination(
                              icon: Icon(Icons.hub_outlined),
                              selectedIcon: Icon(Icons.hub),
                              label: Text('Sources'),
                            ),
                            NavigationRailDestination(
                              icon: Icon(Icons.ios_share_outlined),
                              selectedIcon: Icon(Icons.ios_share),
                              label: Text('Export'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              Expanded(child: pages[_selectedIndex]),
            ],
          ),
          bottomNavigationBar: wide
              ? null
              : Platform.isIOS
              ? CupertinoTabBar(
                  currentIndex: _selectedIndex,
                  activeColor: Theme.of(context).colorScheme.primary,
                  onTap: (index) => setState(() => _selectedIndex = index),
                  items: const [
                    BottomNavigationBarItem(
                      icon: Icon(CupertinoIcons.square_grid_2x2),
                      label: 'Overview',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(CupertinoIcons.chart_bar),
                      label: 'Trends',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(CupertinoIcons.list_bullet),
                      label: 'Records',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(CupertinoIcons.link),
                      label: 'Sources',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(CupertinoIcons.square_arrow_up),
                      label: 'Export',
                    ),
                  ],
                )
              : NavigationBar(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: (index) =>
                      setState(() => _selectedIndex = index),
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.space_dashboard_outlined),
                      selectedIcon: Icon(Icons.space_dashboard),
                      label: 'Overview',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.show_chart_outlined),
                      selectedIcon: Icon(Icons.show_chart),
                      label: 'Trends',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.list_alt_outlined),
                      selectedIcon: Icon(Icons.list_alt),
                      label: 'Records',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.hub_outlined),
                      selectedIcon: Icon(Icons.hub),
                      label: 'Sources',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.ios_share_outlined),
                      selectedIcon: Icon(Icons.ios_share),
                      label: 'Export',
                    ),
                  ],
                ),
        );
      },
    );
  }
}
