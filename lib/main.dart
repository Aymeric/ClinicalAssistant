import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:share_plus/share_plus.dart';

import 'data/encrypted_record_store.dart';
import 'exports/export_selection.dart';
import 'exports/health_export_service.dart';
import 'integrations/fhir_portal_importer.dart';
import 'integrations/health_platform_importer.dart';
import 'models/health_record.dart';
import 'notifications/result_notification_manager.dart';
import 'notifications/result_notification_settings.dart';
import 'sync/foreground_sync_state.dart';
import 'sync/import_progress.dart';
import 'trends/health_trends_page.dart';

void main() {
  runApp(const ClinicalAssistantApp());
}

class ClinicalAssistantApp extends StatelessWidget {
  const ClinicalAssistantApp({super.key, this.controller});

  static const _ink = Color(0xFF153E45);
  static const _teal = Color(0xFF17645E);
  static const _mutedInk = Color(0xFF52696B);

  final HealthDataController? controller;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Clinical Assistant',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      home: HealthHome(controller: controller),
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
  const HealthHome({super.key, this.controller, this.notificationManager});

  final HealthDataController? controller;
  final ResultNotificationManager? notificationManager;

  @override
  State<HealthHome> createState() => _HealthHomeState();
}

class _HealthHomeState extends State<HealthHome> with WidgetsBindingObserver {
  late final _controller = widget.controller ?? HealthDataController();
  late final _notificationManager =
      widget.notificationManager ??
      LocalResultNotificationManager(onNotificationTap: _openRecords);
  final _exporter = HealthExportService();
  var _selectedIndex = 0;
  var _since = DateTime(1900);
  var _exporting = false;
  var _syncSettingsLoading = true;
  var _syncing = false;
  var _initialLoadFinished = false;
  ForegroundSyncState? _syncState;
  String? _syncStatus;
  ImportProgress? _operationProgress;
  DateTime? _lastForegroundSyncAttempt;

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
    if (state == AppLifecycleState.resumed && _initialLoadFinished) {
      unawaited(_syncEnabledSources());
    }
  }

  Future<void> _loadInitialState() async {
    await _controller.load();
    if (!mounted) return;
    try {
      final syncState = await _controller.loadForegroundSyncState();
      if (!mounted) return;
      setState(() {
        _syncState = syncState;
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
    if (mounted) setState(() => _selectedIndex = 2);
  }

  Future<void> _importHealth() async {
    await _runAction(
      (onProgress) =>
          _controller.importHealth(since: _since, onProgress: onProgress),
    );
    await _reloadSyncState();
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
      if (mounted) _showMessage(_displayError(error));
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
      _showMessage(_displayError(error));
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
    final pages = [
      _OverviewPage(
        records: _controller.records,
        loading: _controller.loading,
        error: _controller.error,
        onConnect: () => setState(() => _selectedIndex = 3),
        onSeeAll: () => setState(() => _selectedIndex = 2),
        onRetry: _controller.load,
      ),
      HealthTrendsPage(
        records: _controller.records,
        loading: _controller.loading,
      ),
      _RecordsPage(records: _controller.records),
      _ConnectionsPage(
        busy: _controller.busy,
        healthRecordCount: _controller.healthRecordCount,
        fhirRecordCount: _controller.fhirRecordCount,
        since: _since,
        syncState: _syncState,
        syncSettingsLoading: _syncSettingsLoading,
        syncing: _syncing,
        syncStatus: _syncStatus,
        onChooseDate: _chooseStartDate,
        onHealthImport: _importHealth,
        onFhirImport: _importFhir,
        onHealthAutoSyncChanged: _onHealthAutoSyncChanged,
        onFhirAutoSyncDisabled: _disableFhirAutoSync,
        onSyncNow: _syncNow,
        onDeleteRecords: _deleteAllRecords,
        notificationManager: _notificationManager,
        syncValueStore: _controller.syncValueStore,
        onProgress: _reportProgress,
      ),
      _ExportPage(
        records: _controller.records,
        exporting: _exporting,
        onPdf: (records) => _shareExport(() => _exporter.createPdf(records)),
        onFhir: (records) =>
            _shareExport(() => _exporter.createFhirBundle(records)),
        onCsv: (records) => _shareExport(() => _exporter.createCsv(records)),
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
                    child: _OperationProgressIndicator(
                      progress: _operationProgress!,
                    ),
                  ),
          ),
          body: Row(
            children: [
              if (wide)
                NavigationRail(
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
              Expanded(
                child: IndexedStack(index: _selectedIndex, children: pages),
              ),
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

class HealthDataController extends ChangeNotifier {
  HealthDataController({
    EncryptedRecordStore? store,
    HealthPlatformImporter? healthImporter,
    FhirPortalImporter? fhirImporter,
    FlutterSecureStorage? secureStorage,
    SyncValueStore? syncValueStore,
  }) : _store = store ?? EncryptedRecordStore(),
       _healthImporter = healthImporter ?? HealthPlatformImporter(),
       _fhirImporter = fhirImporter ?? FhirPortalImporter(),
       _syncValueStore =
           syncValueStore ??
           SecureSyncValueStore(
             storage: secureStorage ?? const FlutterSecureStorage(),
           );

  static const _fhirBaseKey = 'fhir_base_url_v1';
  static const _fhirClientKey = 'fhir_client_id_v1';
  static const _healthAutoSyncKey = 'health_auto_sync_v1';
  static const _fhirAutoSyncKey = 'fhir_auto_sync_v1';
  static const _lastHealthSyncKey = 'last_health_sync_v1';
  static const _lastFhirSyncKey = 'last_fhir_sync_v1';
  static const _fhirRefreshTokenKey = 'fhir_refresh_token_v1';
  static const _fhirPatientIdKey = 'fhir_patient_id_v1';
  static const _fhirAuthorizationEndpointKey = 'fhir_authorization_endpoint_v1';
  static const _fhirTokenEndpointKey = 'fhir_token_endpoint_v1';
  final EncryptedRecordStore _store;
  final HealthPlatformImporter _healthImporter;
  final FhirPortalImporter _fhirImporter;
  final SyncValueStore _syncValueStore;
  List<HealthRecord> records = const [];
  bool loading = true;
  bool busy = false;
  Object? error;
  SyncValueStore get syncValueStore => _syncValueStore;

  @override
  void dispose() {
    _fhirImporter.close();
    super.dispose();
  }

  int get healthRecordCount => records
      .where(
        (record) =>
            record.id.startsWith('health:') ||
            record.id.startsWith('health-clinical:'),
      )
      .length;
  int get fhirRecordCount =>
      records.where((record) => record.id.startsWith('fhir:')).length;

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      records = await _store.load();
    } catch (exception) {
      error = exception;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<List<HealthRecord>> importHealth({
    required DateTime since,
    ImportProgressCallback? onProgress,
  }) async {
    return _withBusy(() async {
      final imported = await _healthImporter.importRecords(
        since: since,
        onProgress: (progress) => onProgress?.call(progress.scale(0.9)),
      );
      if (imported.isEmpty) {
        throw StateError(
          'No supported health records or clinical lab results were returned. Check the date range and review the requested permissions.',
        );
      }
      onProgress?.call(
        const ImportProgress(
          fraction: 0.95,
          message: 'Saving imported records',
        ),
      );
      final newlyImported = await _mergeAndSave(imported);
      await _recordSuccessfulSync(_lastHealthSyncKey);
      onProgress?.call(
        const ImportProgress(fraction: 1, message: 'Import complete'),
      );
      return newlyImported;
    });
  }

  Future<void> setHealthAutoSync(bool enabled) =>
      _syncValueStore.write(_healthAutoSyncKey, enabled.toString());

  Future<void> disableFhirAutoSync() async {
    await _syncValueStore.write(_fhirAutoSyncKey, 'false');
    await Future.wait([
      _syncValueStore.delete(_fhirRefreshTokenKey),
      _syncValueStore.delete(_fhirPatientIdKey),
      _syncValueStore.delete(_fhirAuthorizationEndpointKey),
      _syncValueStore.delete(_fhirTokenEndpointKey),
    ]);
  }

  Future<ForegroundSyncState> loadForegroundSyncState() async {
    final values = await Future.wait([
      _syncValueStore.read(_healthAutoSyncKey),
      _syncValueStore.read(_fhirAutoSyncKey),
      _syncValueStore.read(_fhirRefreshTokenKey),
      _syncValueStore.read(_fhirPatientIdKey),
      _syncValueStore.read(_fhirAuthorizationEndpointKey),
      _syncValueStore.read(_fhirTokenEndpointKey),
      _syncValueStore.read(_lastHealthSyncKey),
      _syncValueStore.read(_lastFhirSyncKey),
    ]);
    return ForegroundSyncState(
      healthAutoSync: _readStoredBoolean(values[0], _healthAutoSyncKey),
      fhirAutoSync: _readStoredBoolean(values[1], _fhirAutoSyncKey),
      fhirRefreshTokenAvailable:
          values[2] != null &&
          values[3] != null &&
          values[4] != null &&
          values[5] != null,
      lastHealthSyncAt: _readStoredDate(values[6], _lastHealthSyncKey),
      lastFhirSyncAt: _readStoredDate(values[7], _lastFhirSyncKey),
    );
  }

  Future<List<HealthRecord>> importFhir({
    required String baseUrl,
    required String clientId,
    ImportProgressCallback? onProgress,
  }) async {
    final result = await connectFhir(
      baseUrl: baseUrl,
      clientId: clientId,
      onProgress: onProgress,
    );
    if (result.fetchedRecordCount == 0) {
      throw StateError(
        'The provider returned no supported laboratory Observations.',
      );
    }
    return result.newlyImported;
  }

  Future<FhirConnectionOutcome> connectFhir({
    required String baseUrl,
    required String clientId,
    bool rememberPortalForAutoSync = false,
    ImportProgressCallback? onProgress,
  }) async {
    return _withBusy(() async {
      final result = await _fhirImporter.authorizeAndImportLabResults(
        fhirBaseUrl: baseUrl,
        clientId: clientId,
        requestRefreshToken: rememberPortalForAutoSync,
        onProgress: (progress) => onProgress?.call(progress.scale(0.9)),
      );
      await Future.wait([
        _syncValueStore.write(_fhirBaseKey, baseUrl.trim()),
        _syncValueStore.write(_fhirClientKey, clientId.trim()),
      ]);
      final canAutoSync =
          rememberPortalForAutoSync && result.refreshToken != null;
      if (canAutoSync) {
        await Future.wait([
          _syncValueStore.write(_fhirRefreshTokenKey, result.refreshToken!),
          _syncValueStore.write(_fhirPatientIdKey, result.patientId),
          _syncValueStore.write(
            _fhirAuthorizationEndpointKey,
            result.authorizationEndpoint,
          ),
          _syncValueStore.write(_fhirTokenEndpointKey, result.tokenEndpoint),
          _syncValueStore.write(_fhirAutoSyncKey, 'true'),
        ]);
      } else {
        await disableFhirAutoSync();
      }
      onProgress?.call(
        const ImportProgress(
          fraction: 0.95,
          message: 'Saving imported records',
        ),
      );
      final newlyImported = result.records.isEmpty
          ? const <HealthRecord>[]
          : await _mergeAndSave(result.records);
      await _recordSuccessfulSync(_lastFhirSyncKey);
      onProgress?.call(
        const ImportProgress(fraction: 1, message: 'Import complete'),
      );
      return FhirConnectionOutcome(
        newlyImported: newlyImported,
        fetchedRecordCount: result.records.length,
        autoSyncEnabled: canAutoSync,
        autoSyncUnavailable:
            rememberPortalForAutoSync && result.refreshToken == null,
      );
    });
  }

  Future<List<HealthRecord>> syncHealth({
    ImportProgressCallback? onProgress,
  }) async {
    return _withBusy(() async {
      final lastSync = _readStoredDate(
        await _syncValueStore.read(_lastHealthSyncKey),
        _lastHealthSyncKey,
      );
      final since =
          lastSync?.subtract(const Duration(days: 3)) ??
          DateTime.now().subtract(const Duration(days: 30));
      final imported = await _healthImporter.importRecords(
        since: since,
        onProgress: (progress) => onProgress?.call(progress.scale(0.9)),
      );
      final newlyImported = imported.isEmpty
          ? const <HealthRecord>[]
          : await _mergeAndSave(imported);
      await _recordSuccessfulSync(_lastHealthSyncKey);
      onProgress?.call(
        const ImportProgress(fraction: 1, message: 'Health sync complete'),
      );
      return newlyImported;
    });
  }

  Future<List<HealthRecord>> syncFhir({
    ImportProgressCallback? onProgress,
  }) async {
    return _withBusy(() async {
      final values = await Future.wait([
        _syncValueStore.read(_fhirBaseKey),
        _syncValueStore.read(_fhirClientKey),
        _syncValueStore.read(_fhirRefreshTokenKey),
        _syncValueStore.read(_fhirPatientIdKey),
        _syncValueStore.read(_fhirAuthorizationEndpointKey),
        _syncValueStore.read(_fhirTokenEndpointKey),
        _syncValueStore.read(_lastFhirSyncKey),
      ]);
      final baseUrl = values[0];
      final clientId = values[1];
      final refreshToken = values[2];
      final patientId = values[3];
      final authorizationEndpoint = values[4];
      final tokenEndpoint = values[5];
      if (baseUrl == null ||
          clientId == null ||
          refreshToken == null ||
          patientId == null ||
          authorizationEndpoint == null ||
          tokenEndpoint == null) {
        throw StateError(
          'The saved FHIR portal authorization is incomplete. Reauthorize the portal to resume automatic sync.',
        );
      }
      final lastSync = _readStoredDate(values[6], _lastFhirSyncKey);
      final since =
          lastSync?.subtract(const Duration(days: 3)) ??
          DateTime.now().subtract(const Duration(days: 30));
      final result = await _fhirImporter.refreshAndImportLabResults(
        fhirBaseUrl: baseUrl,
        clientId: clientId,
        patientId: patientId,
        refreshToken: refreshToken,
        authorizationEndpoint: authorizationEndpoint,
        tokenEndpoint: tokenEndpoint,
        since: since,
        onRefreshTokenUpdated: (token) =>
            _syncValueStore.write(_fhirRefreshTokenKey, token),
        onProgress: (progress) => onProgress?.call(progress.scale(0.9)),
      );
      final newlyImported = result.records.isEmpty
          ? const <HealthRecord>[]
          : await _mergeAndSave(result.records);
      await _recordSuccessfulSync(_lastFhirSyncKey);
      onProgress?.call(
        const ImportProgress(fraction: 1, message: 'Portal sync complete'),
      );
      return newlyImported;
    });
  }

  Future<List<HealthRecord>> _mergeAndSave(List<HealthRecord> imported) async {
    final existingIds = records.map((record) => record.id).toSet();
    final addedIds = <String>{};
    final newlyImported = imported
        .where(
          (record) =>
              !existingIds.contains(record.id) && addedIds.add(record.id),
        )
        .toList();
    final merged = <String, HealthRecord>{
      for (final record in records) record.id: record,
      for (final record in imported) record.id: record,
    }.values.toList()..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    await _store.save(merged);
    records = merged;
    return newlyImported;
  }

  Future<void> clear() async {
    await _syncValueStore.write(_healthAutoSyncKey, 'false');
    await disableFhirAutoSync();
    await Future.wait([
      _syncValueStore.delete(_lastHealthSyncKey),
      _syncValueStore.delete(_lastFhirSyncKey),
    ]);
    await _store.clear();
    records = const [];
    notifyListeners();
  }

  Future<void> _recordSuccessfulSync(String key) =>
      _syncValueStore.write(key, DateTime.now().toUtc().toIso8601String());

  bool _readStoredBoolean(String? value, String key) {
    if (value == null || value == 'false') return false;
    if (value == 'true') return true;
    throw FormatException('The saved sync setting "$key" is invalid.');
  }

  DateTime? _readStoredDate(String? value, String key) {
    if (value == null) return null;
    final date = DateTime.tryParse(value);
    if (date == null) {
      throw FormatException('The saved sync date "$key" is invalid.');
    }
    return date.toUtc();
  }

  Future<T> _withBusy<T>(Future<T> Function() action) async {
    if (busy) throw StateError('An import is already in progress.');
    busy = true;
    notifyListeners();
    try {
      return await action();
    } finally {
      busy = false;
      notifyListeners();
    }
  }
}

class FhirConnectionOutcome {
  const FhirConnectionOutcome({
    required this.newlyImported,
    required this.fetchedRecordCount,
    required this.autoSyncEnabled,
    required this.autoSyncUnavailable,
  });

  final List<HealthRecord> newlyImported;
  final int fetchedRecordCount;
  final bool autoSyncEnabled;
  final bool autoSyncUnavailable;
}

typedef FhirPortalConnectCallback = Future<FhirConnectionOutcome?> Function({
  required String baseUrl,
  required String clientId,
  required bool rememberPortalForAutoSync,
  required ImportProgressCallback onProgress,
});

class _OverviewPage extends StatelessWidget {
  const _OverviewPage({
    required this.records,
    required this.loading,
    required this.error,
    required this.onConnect,
    required this.onSeeAll,
    required this.onRetry,
  });

  final List<HealthRecord> records;
  final bool loading;
  final Object? error;
  final VoidCallback onConnect;
  final VoidCallback onSeeAll;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final labs = records.where(
      (record) => record.category == RecordCategory.lab,
    );
    final latest = [...records]
      ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    return _PageContent(
      children: [
        if (error != null)
          _ErrorNotice(message: error.toString(), onRetry: onRetry),
        const SizedBox(height: 8),
        Text(
          'Your health history,\nall together.',
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
            fontWeight: FontWeight.w700,
            height: 1.06,
            letterSpacing: -1.1,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Bring records from your health platforms and care providers into one private place.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _IconStamp(
                      icon: Icons.lock_outline,
                      background: Theme.of(context)
                          .colorScheme
                          .primaryContainer,
                      foreground: Theme.of(context)
                          .colorScheme
                          .onPrimaryContainer,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'Kept on this device',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  loading
                      ? 'Opening your encrypted record vault...'
                      : '${records.length} ${records.length == 1 ? 'record' : 'records'} saved  ·  ${labs.length} lab ${labs.length == 1 ? 'result' : 'results'}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                if (records.isEmpty)
                  FilledButton.icon(
                    onPressed: loading ? null : onConnect,
                    icon: const Icon(Icons.add_link),
                    label: const Text('Connect a health source'),
                  )
                else
                  OutlinedButton.icon(
                    onPressed: onConnect,
                    icon: const Icon(Icons.add_link),
                    label: const Text('Add another source'),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 26),
        _SectionHeading(
          title: 'Recent records',
          trailing: TextButton(
            onPressed: onSeeAll,
            child: const Text('See all'),
          ),
        ),
        if (records.isEmpty && !loading)
          const _QuietEmptyState(
            icon: Icons.notes_outlined,
            title: 'Your timeline starts here',
            message: 'Imported health records and lab results will appear here with their source and date.',
          )
        else
          _RecordLedger(records: latest.take(4).toList()),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _RecordsPage extends StatefulWidget {
  const _RecordsPage({required this.records});

  final List<HealthRecord> records;

  @override
  State<_RecordsPage> createState() => _RecordsPageState();
}

class _RecordsPageState extends State<_RecordsPage> {
  final _searchController = TextEditingController();
  RecordCategory? _filter;
  DateTimeRange? _selectedDateRange;
  String _searchQuery = '';

  @override
  void didUpdateWidget(covariant _RecordsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_selectedDateRange != null &&
        !widget.records.any((record) {
          final date = DateUtils.dateOnly(record.recordedAt.toLocal());
          return !date.isBefore(_selectedDateRange!.start) &&
              !date.isAfter(_selectedDateRange!.end);
        })) {
      _selectedDateRange = null;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchQuery.trim().toLowerCase();
    final availableDates =
        widget.records
            .map((record) => DateUtils.dateOnly(record.recordedAt.toLocal()))
            .toSet()
            .toList()
          ..sort((a, b) => b.compareTo(a));
    final filtered = widget.records.where((record) {
      if (_filter != null && record.category != _filter) return false;
      if (_selectedDateRange != null) {
        final date = DateUtils.dateOnly(record.recordedAt.toLocal());
        if (date.isBefore(_selectedDateRange!.start) ||
            date.isAfter(_selectedDateRange!.end)) {
          return false;
        }
      }
      if (query.isEmpty) return true;
      final searchable = [
        record.name,
        record.displayValue,
        record.source,
        record.code,
        record.referenceRange,
        record.status,
      ].whereType<String>().join(' ').toLowerCase();
      return searchable.contains(query);
    }).toList()..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(22, 16, 22, 18),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'A dated trail of what you’ve collected.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 4,
                      children: [
                        IconButton(
                          tooltip: 'Older records',
                          onPressed: _stepDateRange(availableDates, -1),
                          icon: const Icon(Icons.chevron_left),
                        ),
                        OutlinedButton.icon(
                          key: const ValueKey('record-date-picker'),
                          onPressed: availableDates.isEmpty
                              ? null
                              : () => _chooseDateRange(availableDates),
                          icon: const Icon(Icons.calendar_month_outlined),
                          label: Text(_dateRangeLabel(context)),
                        ),
                        IconButton(
                          tooltip: 'Newer records',
                          onPressed: _stepDateRange(availableDates, 1),
                          icon: const Icon(Icons.chevron_right),
                        ),
                        if (_selectedDateRange != null)
                          TextButton(
                            key: const ValueKey('record-date-clear'),
                            onPressed: () =>
                                setState(() => _selectedDateRange = null),
                            child: const Text('All dates'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      key: const ValueKey('record-search'),
                      controller: _searchController,
                      textInputAction: TextInputAction.search,
                      onChanged: (value) =>
                          setState(() => _searchQuery = value),
                      decoration: InputDecoration(
                        hintText: 'Search records, values, or sources',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchQuery.isEmpty
                            ? null
                            : IconButton(
                                key: const ValueKey('record-search-clear'),
                                tooltip: 'Clear search',
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                                icon: const Icon(Icons.close),
                              ),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _FilterChip(
                            label: 'All',
                            selected: _filter == null,
                            onSelected: () => setState(() => _filter = null),
                          ),
                          for (final category in RecordCategory.values)
                            _FilterChip(
                              label: _categoryLabel(category),
                              selected: _filter == category,
                              onSelected: () =>
                                  setState(() => _filter = category),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (filtered.isEmpty)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 28),
                sliver: SliverToBoxAdapter(
                  child: widget.records.isEmpty
                      ? const _QuietEmptyState(
                          icon: Icons.manage_search,
                          title: 'No records in this view',
                          message: 'Connect Apple Health, Health Connect, or a FHIR-enabled provider portal to import records.',
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _QuietEmptyState(
                              icon: Icons.manage_search,
                              title: 'No matching records',
                              message: 'Try another search term, category, or date range.',
                            ),
                            TextButton.icon(
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                  _filter = null;
                                  _selectedDateRange = null;
                                });
                              },
                              icon: const Icon(Icons.filter_alt_off_outlined),
                              label: const Text(
                                'Clear search, filters, and date range',
                              ),
                            ),
                          ],
                        ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 28),
                sliver: SliverList.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) => _RecordRow(
                    key: ValueKey(filtered[index].id),
                    record: filtered[index],
                    isLast: index == filtered.length - 1,
                    onTap: () => _showRecordDetails(filtered[index]),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _dateRangeLabel(BuildContext context) {
    final range = _selectedDateRange;
    if (range == null) return 'Choose date range';
    final localizations = MaterialLocalizations.of(context);
    final start = localizations.formatMediumDate(range.start);
    if (DateUtils.isSameDay(range.start, range.end)) return start;
    return '$start – ${localizations.formatMediumDate(range.end)}';
  }

  VoidCallback? _stepDateRange(List<DateTime> availableDates, int direction) {
    final range = _selectedDateRange;
    if (range == null || availableDates.length < 2) return null;
    final duration = range.end.difference(range.start);
    final target = direction < 0
        ? availableDates.firstWhere(
            (date) => date.isBefore(range.start),
            orElse: () => range.start,
          )
        : availableDates.firstWhere(
            (date) => date.isAfter(range.end),
            orElse: () => range.end,
          );
    if (DateUtils.isSameDay(target, direction < 0 ? range.start : range.end)) {
      return null;
    }
    final newStart = direction < 0 ? target : target.subtract(duration);
    final newEnd = direction < 0 ? target.add(duration) : target;
    return () => setState(
      () => _selectedDateRange = DateTimeRange(start: newStart, end: newEnd),
    );
  }

  Future<void> _chooseDateRange(List<DateTime> availableDates) async {
    final selectedRange = await showDateRangePicker(
      context: context,
      initialDateRange: _selectedDateRange,
      firstDate: availableDates.last,
      lastDate: availableDates.first,
      helpText: 'Choose a date range',
      builder: (context, child) {
        final theme = Theme.of(context);
        return Theme(
          data: theme.copyWith(
            datePickerTheme: theme.datePickerTheme.copyWith(
              rangePickerHeaderHeadlineStyle:
                  MediaQuery.sizeOf(context).width < 420
                  ? theme.textTheme.titleMedium
                  : null,
            ),
          ),
          child: child!,
        );
      },
    );
    if (!mounted || selectedRange == null) return;
    setState(
      () => _selectedDateRange = DateTimeRange(
        start: DateUtils.dateOnly(selectedRange.start),
        end: DateUtils.dateOnly(selectedRange.end),
      ),
    );
  }

  Future<void> _showRecordDetails(HealthRecord record) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                record.name,
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 18),
              _DetailLine(label: 'Value', value: record.displayValue),
              _DetailLine(
                label: 'Recorded',
                value: record.recordedAt.toLocal().toString().split('.').first,
              ),
              _DetailLine(label: 'Source', value: record.source),
              _DetailLine(
                label: 'Category',
                value: _categoryLabel(record.category),
              ),
              if (record.referenceRange != null)
                _DetailLine(
                  label: 'Reference range',
                  value: record.referenceRange!,
                ),
              if (record.status != null)
                _DetailLine(label: 'Source status', value: record.status!),
              if (record.code != null)
                _DetailLine(label: 'Code', value: record.code!),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConnectionsPage extends StatelessWidget {
  const _ConnectionsPage({
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
  });

  final bool busy;
  final int healthRecordCount;
  final int fhirRecordCount;
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

  @override
  Widget build(BuildContext context) {
    return _PageContent(
      children: [
        Text(
          'Choose what you connect. Imports stay in your encrypted on-device vault.',
          style: Theme.of(context).textTheme.bodyLarge
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 22),
        _ForegroundSyncPanel(
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
          _SourcePanel(
            icon: CupertinoIcons.heart_fill,
            title: 'Apple Health',
            description: 'Read supported measurements and stored lab results. Steps are summarized by day.',
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
          _SourcePanel(
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
        _FhirConnectionForm(
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

class _OperationProgressIndicator extends StatelessWidget {
  const _OperationProgressIndicator({required this.progress});

  final ImportProgress progress;

  @override
  Widget build(BuildContext context) {
    final fraction = progress.fraction.clamp(0, 1).toDouble();
    final percentage = (fraction * 100).round();
    return Semantics(
      liveRegion: true,
      label: '${progress.message}: $percentage percent',
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      progress.message,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '$percentage%',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              LinearProgressIndicator(value: fraction, minHeight: 4),
            ],
          ),
        ),
      ),
    );
  }
}

class _ForegroundSyncPanel extends StatelessWidget {
  const _ForegroundSyncPanel({
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
                  'First check reads the last 30 days; later checks overlap the last 3 days. Use Import for older history.',
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
                'Last health sync: ${_formatSyncTimestamp(state?.lastHealthSyncAt)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            if (state?.fhirAutoSync == true)
              Text(
                'Last portal sync: ${_formatSyncTimestamp(state?.lastFhirSyncAt)}',
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

String _formatSyncTimestamp(DateTime? value) {
  if (value == null) return 'Not synced yet';
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final period = local.hour < 12 ? 'AM' : 'PM';
  return '$month/$day/${local.year} at $hour:$minute $period';
}

class _FhirConnectionForm extends StatefulWidget {
  const _FhirConnectionForm({
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
  State<_FhirConnectionForm> createState() => _FhirConnectionFormState();
}

class _FhirConnectionFormState extends State<_FhirConnectionForm> {
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
  void didUpdateWidget(covariant _FhirConnectionForm oldWidget) {
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
        _configError = 'Saved portal auto-sync authorization is incomplete. Reauthorize the portal to restore it.';
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
                  _IconStamp(
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
                    _CountPill(count: widget.importedCount),
                ],
              ),
              if (widget.connected) ...[
                const SizedBox(height: 8),
                const _ConnectionStatusPill(),
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

class _ExportPage extends StatefulWidget {
  const _ExportPage({
    required this.records,
    required this.exporting,
    required this.onPdf,
    required this.onFhir,
    required this.onCsv,
  });

  final List<HealthRecord> records;
  final bool exporting;
  final ValueChanged<List<HealthRecord>> onPdf;
  final ValueChanged<List<HealthRecord>> onFhir;
  final ValueChanged<List<HealthRecord>> onCsv;

  @override
  State<_ExportPage> createState() => _ExportPageState();
}

class _ExportPageState extends State<_ExportPage> {
  final _selectedCategories = RecordCategory.values.toSet();

  List<HealthRecord> get _selectedRecords =>
      selectRecordsForExport(widget.records, _selectedCategories);

  @override
  Widget build(BuildContext context) {
    final selectedRecords = _selectedRecords;
    final availableCategories = widget.records
        .map((record) => record.category)
        .toSet();
    return _PageContent(
      children: [
        Text(
          'Choose which records to include, then create a copy or share it with someone you trust.',
          style: Theme.of(context).textTheme.bodyLarge
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 22),
        if (widget.records.isEmpty)
          const _QuietEmptyState(
            icon: Icons.ios_share_outlined,
            title: 'Nothing to export yet',
            message: 'Connect a source and import records first. You can choose the destination when the system share sheet opens.',
          )
        else ...[
          _SectionHeading(title: 'Include in export'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final category in RecordCategory.values)
                if (availableCategories.contains(category))
                  FilterChip(
                    label: Text(
                      '${_categoryLabel(category)} (${widget.records.where((record) => record.category == category).length})',
                    ),
                    selected: _selectedCategories.contains(category),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedCategories.add(category);
                        } else {
                          _selectedCategories.remove(category);
                        }
                      });
                    },
                  ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${selectedRecords.length} of ${widget.records.length} ${widget.records.length == 1 ? 'record' : 'records'} selected',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          if (selectedRecords.isEmpty) ...[
            const SizedBox(height: 12),
            const _QuietEmptyState(
              icon: Icons.filter_alt_off_outlined,
              title: 'Choose a category to continue',
              message: 'Select at least one category to enable an export.',
            ),
          ],
          const SizedBox(height: 18),
          _ExportAction(
            icon: Icons.description_outlined,
            title: 'Readable summary',
            detail: 'PDF with dates, values, reference ranges, and sources',
            buttonText: 'Create PDF',
            onPressed: widget.exporting || selectedRecords.isEmpty
                ? null
                : () => widget.onPdf(selectedRecords),
          ),
          const SizedBox(height: 12),
          _ExportAction(
            icon: Icons.data_object,
            title: 'FHIR Bundle',
            detail: 'Portable JSON; imported FHIR Observations are preserved',
            buttonText: 'Export FHIR JSON',
            onPressed: widget.exporting || selectedRecords.isEmpty
                ? null
                : () => widget.onFhir(selectedRecords),
          ),
          const SizedBox(height: 12),
          _ExportAction(
            icon: Icons.table_chart_outlined,
            title: 'Spreadsheet',
            detail: 'CSV with values, units, dates, and source provenance',
            buttonText: 'Export CSV',
            onPressed: widget.exporting || selectedRecords.isEmpty
                ? null
                : () => widget.onCsv(selectedRecords),
          ),
          const SizedBox(height: 16),
          const _PrivacyNote(
            text: 'Exports are created temporarily on this device. They leave the app only if you choose a destination in the system share sheet.',
          ),
        ],
      ],
    );
  }
}

class _ExportAction extends StatelessWidget {
  const _ExportAction({
    required this.icon,
    required this.title,
    required this.detail,
    required this.buttonText,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String detail;
  final String buttonText;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(detail, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onPressed, child: Text(buttonText)),
          ],
        ),
      ),
    );
  }
}

class _SourcePanel extends StatelessWidget {
  const _SourcePanel({
    required this.icon,
    required this.title,
    required this.description,
    required this.count,
    required this.connected,
    required this.busy,
    required this.buttonLabel,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String description;
  final int count;
  final bool connected;
  final bool busy;
  final String buttonLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _IconStamp(
                  icon: icon,
                  background: Theme.of(context).colorScheme.primaryContainer,
                  foreground: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                if (count > 0) _CountPill(count: count),
              ],
            ),
            if (connected) ...[
              const SizedBox(height: 8),
              const _ConnectionStatusPill(),
            ],
            const SizedBox(height: 14),
            Text(description),
            const SizedBox(height: 8),
            Text(
              'Data types available depend on your device, permissions, and connected apps.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onPressed,
              icon: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync),
              label: Text(busy ? 'Importing...' : buttonLabel),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConnectionStatusPill extends StatelessWidget {
  const _ConnectionStatusPill();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, size: 14, color: colors.onPrimaryContainer),
          const SizedBox(width: 4),
          Text(
            'Connected',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colors.onPrimaryContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordLedger extends StatelessWidget {
  const _RecordLedger({required this.records});

  final List<HealthRecord> records;

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) {
      return const _QuietEmptyState(
        icon: Icons.timeline_outlined,
        title: 'No records yet',
        message: 'When you connect a source, its records will be organized here by date.',
      );
    }
    return Column(
      children: [
        for (var index = 0; index < records.length; index++)
          _RecordRow(
            record: records[index],
            isLast: index == records.length - 1,
          ),
      ],
    );
  }
}

class _RecordRow extends StatelessWidget {
  const _RecordRow({
    super.key,
    required this.record,
    required this.isLast,
    this.onTap,
  });

  final HealthRecord record;
  final bool isLast;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = record.category == RecordCategory.lab
        ? colors.tertiary
        : colors.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 40,
              child: Column(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    margin: const EdgeInsets.only(top: 5),
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  if (!isLast)
                    Container(
                      width: 1,
                      height: 50,
                      margin: const EdgeInsets.only(top: 5),
                      color: colors.outlineVariant,
                    ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.name,
                    style: Theme.of(context).textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${_formatRecordDate(record.recordedAt)}  ·  ${record.source}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: colors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              record.displayValue,
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _PageContent extends StatelessWidget {
  const _PageContent({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 28),
          children: children,
        ),
      ),
    );
  }
}

class _QuietEmptyState extends StatelessWidget {
  const _QuietEmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 22,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 5),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorNotice extends StatelessWidget {
  const _ErrorNotice({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Could not open your records',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
            TextButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

class _IconStamp extends StatelessWidget {
  const _IconStamp({
    required this.icon,
    required this.background,
    required this.foreground,
  });

  final IconData icon;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: foreground),
    );
  }
}

class _CountPill extends StatelessWidget {
  const _CountPill({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text('$count imported'),
    );
  }
}

class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.lock_outline, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(text)),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 116,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

String _categoryLabel(RecordCategory category) => switch (category) {
  RecordCategory.lab => 'Labs',
  RecordCategory.vital => 'Vitals',
  RecordCategory.activity => 'Activity',
  RecordCategory.sleep => 'Sleep',
  RecordCategory.nutrition => 'Nutrition',
  RecordCategory.cycleTracking => 'Cycle tracking',
};

String _formatRecordDate(DateTime date) {
  final local = date.toLocal();
  return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
}

String _displayError(Object error) {
  if (error is StateError) return error.message.toString();
  if (error is FormatException) return error.message;
  return error.toString().replaceFirst('Exception: ', '');
}
