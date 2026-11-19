import 'package:flutter/material.dart';

import '../providers/settings_provider.dart';
import '../services/app_lock_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/theme_scope.dart';
import 'common.dart';

/// Menampilkan layar kunci di atas aplikasi saat launch dan saat aplikasi
/// kembali dari background. Perpindahan halaman di dalam aplikasi tidak
/// memicu kunci ulang.
class AppLockGate extends StatefulWidget {
  final SettingsController settings;
  final AppLockService service;
  final Widget child;

  const AppLockGate({
    super.key,
    required this.settings,
    required this.service,
    required this.child,
  });

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate> with WidgetsBindingObserver {
  bool _checking = true;
  bool _locked = false;
  bool _shouldLockOnResume = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.settings.addListener(_onSettingsChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkInitialLock());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      if (!_locked) {
        _shouldLockOnResume = true;
      }
      return;
    }
    if (state == AppLifecycleState.resumed && _shouldLockOnResume) {
      _shouldLockOnResume = false;
      _maybeLock(showChecking: true);
    }
  }

  Future<void> _checkInitialLock() async {
    await _maybeLock();
    if (mounted) {
      setState(() => _checking = false);
    }
  }

  Future<void> _maybeLock({bool showChecking = false}) async {
    if (!widget.settings.biometricLockEnabled) {
      if (mounted && (_locked || _checking)) {
        setState(() {
          _locked = false;
          _checking = false;
        });
      }
      return;
    }
    if (_locked) {
      return;
    }
    if (showChecking && mounted) {
      setState(() => _checking = true);
    }

    final bool hasPin = await widget.service.hasPin();
    if (!mounted) {
      return;
    }
    if (!hasPin && widget.settings.biometricLockEnabled) {
      widget.settings.setBiometricLock(false);
    }
    setState(() {
      _checking = false;
      _locked = hasPin;
    });
  }

  void _onSettingsChanged() {
    if (!widget.settings.biometricLockEnabled && (_locked || _checking)) {
      setState(() {
        _locked = false;
        _checking = false;
      });
    }
  }

  void _unlock() {
    if (mounted) {
      setState(() => _locked = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.settings.removeListener(_onSettingsChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_checking && widget.settings.biometricLockEnabled) {
      return ColoredBox(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    return Stack(
      children: [
        IgnorePointer(ignoring: _locked, child: widget.child),
        if (_locked)
          Positioned.fill(
            child: Navigator(
              onGenerateRoute: (RouteSettings settings) =>
                  MaterialPageRoute<void>(
                    settings: settings,
                    builder: (BuildContext context) => AppLockScreen(
                      service: widget.service,
                      onUnlocked: _unlock,
                    ),
                  ),
            ),
          ),
      ],
    );
  }
}

class AppLockScreen extends StatefulWidget {
  final AppLockService service;
  final VoidCallback onUnlocked;

  const AppLockScreen({
    super.key,
    required this.service,
    required this.onUnlocked,
  });

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> {
  final TextEditingController _pinController = TextEditingController();
  bool _canUseBiometrics = false;
  bool _isAuthenticating = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final bool available = await widget.service.canUseBiometrics();
      if (!mounted) {
        return;
      }
      setState(() => _canUseBiometrics = available);
      if (available) {
        await _authenticate();
      }
    });
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _authenticate() async {
    if (_isAuthenticating) {
      return;
    }
    setState(() {
      _isAuthenticating = true;
      _errorText = null;
    });
    final bool authenticated = await widget.service
        .authenticateWithBiometrics();
    if (!mounted) {
      return;
    }
    setState(() => _isAuthenticating = false);
    if (authenticated) {
      widget.onUnlocked();
    }
  }

  Future<void> _verifyPin() async {
    final String pin = _pinController.text.trim();
    if (pin.length < 4 || pin.length > 6) {
      setState(() => _errorText = 'PIN harus terdiri dari 4-6 digit.');
      return;
    }

    setState(() => _isAuthenticating = true);
    final bool valid = await widget.service.verifyPin(pin);
    if (!mounted) {
      return;
    }
    if (valid) {
      widget.onUnlocked();
      return;
    }
    setState(() {
      _isAuthenticating = false;
      _errorText = 'PIN salah. Coba lagi.';
      _pinController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = ThemeScope.of(context).colors;
    return PopScope(
      canPop: false,
      child: Material(
        color: c.bg,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: AppCard(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: c.blueDim,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.lock_outline,
                          color: c.blue,
                          size: 30,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'AturAja terkunci',
                        style: AppTypography.title(c.text),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Masukkan PIN atau gunakan biometrik untuk melanjutkan.',
                        textAlign: TextAlign.center,
                        style: AppTypography.body(c.textSub),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      TextField(
                        controller: _pinController,
                        autofocus: !_canUseBiometrics,
                        obscureText: true,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        enabled: !_isAuthenticating,
                        onSubmitted: (_) => _verifyPin(),
                        decoration: InputDecoration(
                          labelText: 'PIN aplikasi',
                          errorText: _errorText,
                          counterText: '',
                        ),
                        style: AppTypography.body(c.text),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _isAuthenticating ? null : _verifyPin,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(
                              AppSpacing.target,
                            ),
                          ),
                          child: _isAuthenticating
                              ? const SizedBox(
                                  width: AppSpacing.iconSmall,
                                  height: AppSpacing.iconSmall,
                                  child: CircularProgressIndicator(
                                    strokeWidth: AppSpacing.xxs,
                                  ),
                                )
                              : const Text('Buka dengan PIN'),
                        ),
                      ),
                      if (_canUseBiometrics) ...[
                        const SizedBox(height: AppSpacing.sm),
                        TextButton.icon(
                          onPressed: _isAuthenticating ? null : _authenticate,
                          icon: const Icon(Icons.fingerprint),
                          label: const Text('Gunakan biometrik'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
