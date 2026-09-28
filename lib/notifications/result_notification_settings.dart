import 'package:flutter/material.dart';

import 'result_notification_manager.dart';
import 'result_notification_preferences.dart';

class ResultNotificationSettings extends StatefulWidget {
  const ResultNotificationSettings({super.key, required this.manager});

  final ResultNotificationManager manager;

  @override
  State<ResultNotificationSettings> createState() =>
      _ResultNotificationSettingsState();
}

class _ResultNotificationSettingsState
    extends State<ResultNotificationSettings> {
  var _loading = true;
  var _saving = false;
  var _preferencesLoaded = false;
  String? _error;
  ResultNotificationPreferences _preferences =
      const ResultNotificationPreferences();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final preferences = await widget.manager.loadPreferences();
      if (mounted) {
        setState(() {
          _preferences = preferences;
          _preferencesLoaded = true;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'Could not load notification settings: $error');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _setEnabled(bool enabled) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (enabled && !await widget.manager.requestPermission()) {
        if (mounted) {
          setState(
            () => _error =
                'Allow notifications in your device settings, then try again.',
          );
        }
        return;
      }
      await _save(_preferences.copyWith(enabled: enabled));
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = 'Could not update notification settings: $error',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _save(ResultNotificationPreferences preferences) async {
    await widget.manager.savePreferences(preferences);
    if (mounted) setState(() => _preferences = preferences);
  }

  Future<void> _update(ResultNotificationPreferences preferences) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _save(preferences);
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'Could not save notification settings: $error');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitle = _loading
        ? 'Loading settings...'
        : _error == null
        ? _preferences.enabled
              ? 'On · checked after imports'
              : 'Off · checked after imports'
        : 'Settings need attention';
    return Card(
      child: ExpansionTile(
        leading: const Icon(Icons.notifications_outlined),
        title: Text(
          'Result notifications',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(subtitle),
        childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
        children: [
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Loading notification settings...'),
              ),
            )
          else if (!_preferencesLoaded)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _error ?? 'Notification settings could not be loaded.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                  TextButton(
                    onPressed: _saving ? null : _load,
                    child: const Text('Try again'),
                  ),
                ],
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Alerts run after manual imports or automatic foreground sync. The app does not check sources while closed.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF52696B),
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Enable notifications'),
                  subtitle: const Text('Alerts stay on this device.'),
                  value: _preferences.enabled,
                  onChanged: _saving ? null : _setEnabled,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('New lab results'),
                  subtitle: const Text(
                    'When an import adds previously unseen lab records.',
                  ),
                  value: _preferences.newLabResults,
                  onChanged: _saving
                      ? null
                      : (value) => _update(
                          _preferences.copyWith(newLabResults: value),
                        ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('New health records'),
                  subtitle: const Text(
                    'Include imported vitals, activity, sleep, nutrition, and cycle records.',
                  ),
                  value: _preferences.newMeasurements,
                  onChanged: _saving
                      ? null
                      : (value) => _update(
                          _preferences.copyWith(newMeasurements: value),
                        ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Trend changes'),
                  subtitle: const Text(
                    'Compare consecutive numeric readings of the same measure.',
                  ),
                  value: _preferences.trends,
                  onChanged: _saving
                      ? null
                      : (value) =>
                            _update(_preferences.copyWith(trends: value)),
                ),
                DropdownButtonFormField<int>(
                  initialValue: _preferences.trendThresholdPercent,
                  decoration: const InputDecoration(
                    labelText: 'Minimum change for a trend alert',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final threshold
                        in ResultNotificationPreferences.trendThresholdOptions)
                      DropdownMenuItem(
                        value: threshold,
                        child: Text('$threshold%'),
                      ),
                  ],
                  onChanged: _saving || !_preferences.trends
                      ? null
                      : (value) {
                          if (value != null) {
                            _update(
                              _preferences.copyWith(
                                trendThresholdPercent: value,
                              ),
                            );
                          }
                        },
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Repeated patterns'),
                  subtitle: const Text(
                    'Three consecutive readings of the same measure moving in one direction.',
                  ),
                  value: _preferences.patterns,
                  onChanged: _saving
                      ? null
                      : (value) =>
                            _update(_preferences.copyWith(patterns: value)),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    _error!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  'Alerts contain counts and rule summaries, not record names or values. Trends and patterns describe numbers only; they are not medical advice.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF52696B),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
