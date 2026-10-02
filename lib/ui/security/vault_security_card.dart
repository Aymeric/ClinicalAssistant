import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/vault_security_service.dart';
import '../shared/record_widgets.dart';

class VaultSecurityCard extends StatefulWidget {
  const VaultSecurityCard({
    super.key,
    required this.securityService,
    this.onLockNow,
  });

  final VaultSecurityService securityService;
  final VoidCallback? onLockNow;

  @override
  State<VaultSecurityCard> createState() => _VaultSecurityCardState();
}

class _VaultSecurityCardState extends State<VaultSecurityCard> {
  bool _isLoading = true;
  bool _hasPin = false;
  AutoLockTimeout _timeout = AutoLockTimeout.immediate;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final hasPin = await widget.securityService.isPinConfigured();
    final timeout = await widget.securityService.getTimeout();
    if (mounted) {
      setState(() {
        _hasPin = hasPin;
        _timeout = timeout;
        _isLoading = false;
      });
    }
  }

  Future<void> _promptSetPin() async {
    final pinController = TextEditingController();
    final confirmController = TextEditingController();
    String? errorText;

    final created = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Set Vault Passcode'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Enter a 4-digit passcode to protect your health records.',
              ),
              const SizedBox(height: 16),
              TextField(
                key: const ValueKey('set-pin-input'),
                controller: pinController,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 4,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'New 4-digit PIN',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('confirm-pin-input'),
                controller: confirmController,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 4,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: 'Confirm 4-digit PIN',
                  border: const OutlineInputBorder(),
                  errorText: errorText,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const ValueKey('save-pin-button'),
              onPressed: () {
                final pin = pinController.text.trim();
                final confirm = confirmController.text.trim();
                if (pin.length != 4) {
                  setDialogState(
                    () => errorText = 'PIN must be exactly 4 digits',
                  );
                  return;
                }
                if (pin != confirm) {
                  setDialogState(() => errorText = 'PINs do not match');
                  return;
                }
                Navigator.pop(dialogCtx, true);
              },
              child: const Text('Set Passcode'),
            ),
          ],
        ),
      ),
    );

    if (created == true) {
      await widget.securityService.setPin(pinController.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vault passcode enabled.')),
        );
        _loadState();
      }
    }
  }

  Future<void> _promptChangePin() async {
    final oldPinController = TextEditingController();
    final newPinController = TextEditingController();
    final confirmController = TextEditingController();
    String? errorText;

    final changed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Change Vault Passcode'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                key: const ValueKey('change-old-pin-input'),
                controller: oldPinController,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 4,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Current PIN',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('change-new-pin-input'),
                controller: newPinController,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 4,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'New 4-digit PIN',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('change-confirm-pin-input'),
                controller: confirmController,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 4,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: 'Confirm New PIN',
                  border: const OutlineInputBorder(),
                  errorText: errorText,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const ValueKey('update-pin-button'),
              onPressed: () async {
                final oldPin = oldPinController.text.trim();
                final newPin = newPinController.text.trim();
                final confirm = confirmController.text.trim();

                if (newPin.length != 4) {
                  setDialogState(() => errorText = 'New PIN must be 4 digits');
                  return;
                }
                if (newPin != confirm) {
                  setDialogState(() => errorText = 'New PINs do not match');
                  return;
                }

                final validOld = await widget.securityService.verifyPin(oldPin);
                if (!dialogCtx.mounted) return;
                if (!validOld) {
                  setDialogState(() => errorText = 'Current PIN is incorrect');
                  return;
                }

                Navigator.pop(dialogCtx, true);
              },
              child: const Text('Update Passcode'),
            ),
          ],
        ),
      ),
    );

    if (changed == true) {
      await widget.securityService.setPin(newPinController.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vault passcode updated.')),
        );
        _loadState();
      }
    }
  }

  Future<void> _promptRemovePin() async {
    final pinController = TextEditingController();
    String? errorText;

    final removed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Disable Passcode Lock'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Enter your current PIN to turn off passcode lock.'),
              const SizedBox(height: 16),
              TextField(
                key: const ValueKey('remove-pin-input'),
                controller: pinController,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 4,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: 'Current PIN',
                  border: const OutlineInputBorder(),
                  errorText: errorText,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const ValueKey('confirm-remove-pin-button'),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(dialogCtx).colorScheme.error,
              ),
              onPressed: () async {
                final pin = pinController.text.trim();
                final success = await widget.securityService.removePin(pin);
                if (!dialogCtx.mounted) return;
                if (!success) {
                  setDialogState(() => errorText = 'Incorrect PIN');
                  return;
                }
                Navigator.pop(dialogCtx, true);
              },
              child: const Text('Disable Passcode'),
            ),
          ],
        ),
      ),
    );

    if (removed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passcode protection disabled.')),
      );
      _loadState();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_isLoading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(18),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconStamp(
                  icon: _hasPin ? Icons.lock_outline : Icons.lock_open_outlined,
                  background: _hasPin
                      ? colorScheme.primaryContainer
                      : colorScheme.surfaceContainerHighest,
                  foreground: _hasPin
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Vault Security & App Lock',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        _hasPin
                            ? 'Protected by 4-digit PIN'
                            : 'Passcode protection disabled',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: _hasPin
                              ? colorScheme.primary
                              : colorScheme.onSurfaceVariant,
                          fontWeight: _hasPin
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Require a PIN to access records upon opening the app or after inactivity, shielding health data from unauthorized viewing.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            if (!_hasPin) ...[
              FilledButton.tonalIcon(
                key: const ValueKey('set-vault-passcode-button'),
                onPressed: _promptSetPin,
                icon: const Icon(Icons.pin, size: 18),
                label: const Text('Set 4-digit Passcode'),
              ),
            ] else ...[
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    key: const ValueKey('change-vault-passcode-button'),
                    onPressed: _promptChangePin,
                    icon: const Icon(Icons.password, size: 18),
                    label: const Text('Change PIN'),
                  ),
                  OutlinedButton.icon(
                    key: const ValueKey('remove-vault-passcode-button'),
                    onPressed: _promptRemovePin,
                    icon: const Icon(Icons.lock_open, size: 18),
                    label: const Text('Disable PIN'),
                  ),
                  if (widget.onLockNow != null)
                    FilledButton.tonalIcon(
                      key: const ValueKey('lock-vault-now-button'),
                      onPressed: widget.onLockNow,
                      icon: const Icon(Icons.lock, size: 18),
                      label: const Text('Lock Vault Now'),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.timer_outlined, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Auto-Lock Timeout:',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 12),
                  DropdownButton<AutoLockTimeout>(
                    key: const ValueKey('vault-timeout-dropdown'),
                    value: _timeout,
                    underline: const SizedBox.shrink(),
                    items: AutoLockTimeout.values.map((timeout) {
                      return DropdownMenuItem<AutoLockTimeout>(
                        value: timeout,
                        child: Text(timeout.label),
                      );
                    }).toList(),
                    onChanged: (newVal) async {
                      if (newVal != null) {
                        await widget.securityService.setTimeout(newVal);
                        setState(() => _timeout = newVal);
                      }
                    },
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
