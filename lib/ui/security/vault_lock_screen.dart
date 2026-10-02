import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/vault_security_service.dart';

class VaultLockScreen extends StatefulWidget {
  const VaultLockScreen({
    super.key,
    required this.securityService,
    required this.onUnlocked,
    this.title = 'Vault Locked',
    this.subtitle = 'Enter your PIN to access your health records',
    this.canCancel = false,
    this.onCancel,
  });

  final VaultSecurityService securityService;
  final VoidCallback onUnlocked;
  final String title;
  final String subtitle;
  final bool canCancel;
  final VoidCallback? onCancel;

  @override
  State<VaultLockScreen> createState() => _VaultLockScreenState();
}

class _VaultLockScreenState extends State<VaultLockScreen> {
  String _enteredPin = '';
  String? _errorMessage;
  bool _isVerifying = false;
  Timer? _countdownTimer;
  int _lockoutSeconds = 0;

  @override
  void initState() {
    super.initState();
    _checkLockout();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _checkLockout() {
    final remaining = widget.securityService.remainingLockoutSeconds;
    if (remaining > 0) {
      setState(() {
        _lockoutSeconds = remaining;
        _errorMessage = 'Too many failed attempts. Try again in $remaining s';
      });
      _startLockoutCountdown();
    }
  }

  void _startLockoutCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final remaining = widget.securityService.remainingLockoutSeconds;
      if (remaining <= 0) {
        timer.cancel();
        setState(() {
          _lockoutSeconds = 0;
          _errorMessage = null;
        });
      } else {
        setState(() {
          _lockoutSeconds = remaining;
          _errorMessage = 'Too many failed attempts. Try again in $remaining s';
        });
      }
    });
  }

  void _onDigitPressed(String digit) {
    if (_lockoutSeconds > 0 || _isVerifying) return;
    if (_enteredPin.length >= 6) return;

    setState(() {
      _errorMessage = null;
      _enteredPin += digit;
    });

    if (_enteredPin.length == 4) {
      _verify();
    }
  }

  void _onBackspacePressed() {
    if (_enteredPin.isEmpty || _isVerifying) return;
    setState(() {
      _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
      _errorMessage = null;
    });
  }

  void _onClearPressed() {
    if (_enteredPin.isEmpty || _isVerifying) return;
    setState(() {
      _enteredPin = '';
      _errorMessage = null;
    });
  }

  Future<void> _verify() async {
    if (_enteredPin.length < 4 || _isVerifying) return;
    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    final success = await widget.securityService.verifyPin(_enteredPin);
    if (!mounted) return;

    if (success) {
      setState(() {
        _isVerifying = false;
        _enteredPin = '';
      });
      widget.onUnlocked();
    } else {
      final lockout = widget.securityService.remainingLockoutSeconds;
      setState(() {
        _isVerifying = false;
        _enteredPin = '';
        if (lockout > 0) {
          _lockoutSeconds = lockout;
          _errorMessage = 'Too many failed attempts. Try again in $lockout s';
          _startLockoutCountdown();
        } else {
          final attempts = widget.securityService.failedAttempts;
          _errorMessage = 'Incorrect PIN ($attempts/5 attempts)';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return PopScope(
      canPop: widget.canCancel,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop && widget.onCancel != null) {
          widget.onCancel!();
        }
      },
      child: Scaffold(
        backgroundColor: colorScheme.surface,
        appBar: widget.canCancel
            ? AppBar(
                leading: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    widget.onCancel?.call();
                    Navigator.of(context).maybePop();
                  },
                ),
                backgroundColor: Colors.transparent,
                elevation: 0,
              )
            : null,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.lock_rounded,
                      size: 36,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    widget.title,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.subtitle,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // PIN dots indicator
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(4, (index) {
                      final isFilled = index < _enteredPin.length;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        margin: const EdgeInsets.symmetric(horizontal: 10),
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isFilled
                              ? colorScheme.primary
                              : colorScheme.outlineVariant.withValues(
                                  alpha: 0.5,
                                ),
                          border: Border.all(
                            color: isFilled
                                ? colorScheme.primary
                                : colorScheme.outline,
                            width: 1.5,
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 16),

                  // Error / Status Message
                  SizedBox(
                    height: 24,
                    child: _errorMessage != null
                        ? Text(
                            _errorMessage!,
                            key: const ValueKey('vault-pin-error'),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.error,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : _isVerifying
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : null,
                  ),
                  const SizedBox(height: 24),

                  // Keypad
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 280),
                    child: Column(
                      children: [
                        _buildKeypadRow(['1', '2', '3']),
                        const SizedBox(height: 16),
                        _buildKeypadRow(['4', '5', '6']),
                        const SizedBox(height: 16),
                        _buildKeypadRow(['7', '8', '9']),
                        const SizedBox(height: 16),
                        _buildBottomRow(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKeypadRow(List<String> digits) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: digits.map((d) => _buildKeypadButton(d)).toList(),
    );
  }

  Widget _buildBottomRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Clear or OK button
        SizedBox(
          width: 72,
          height: 72,
          child: _enteredPin.length > 4
              ? IconButton(
                  key: const ValueKey('vault-pin-submit-key'),
                  onPressed: _lockoutSeconds > 0 ? null : _verify,
                  icon: const Icon(Icons.check_circle_outline, size: 28),
                )
              : TextButton(
                  onPressed: _enteredPin.isNotEmpty ? _onClearPressed : null,
                  child: const Text('Clear', style: TextStyle(fontSize: 14)),
                ),
        ),
        _buildKeypadButton('0'),
        SizedBox(
          width: 72,
          height: 72,
          child: IconButton(
            key: const ValueKey('vault-pin-backspace-key'),
            onPressed: _enteredPin.isNotEmpty ? _onBackspacePressed : null,
            icon: const Icon(Icons.backspace_outlined, size: 24),
          ),
        ),
      ],
    );
  }

  Widget _buildKeypadButton(String digit) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SizedBox(
      width: 72,
      height: 72,
      child: Material(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        shape: const CircleBorder(),
        child: InkWell(
          key: ValueKey('vault-pin-digit-$digit'),
          customBorder: const CircleBorder(),
          onTap: _lockoutSeconds > 0 ? null : () => _onDigitPressed(digit),
          child: Center(
            child: Text(
              digit,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
