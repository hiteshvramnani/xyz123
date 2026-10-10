import 'dart:async';

import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

import '../main.dart'; // Imports the global variables without naming collisions
import '../theme/theme.dart';
import '../widgets/ui/ui.dart';

typedef ActivityCallback = void Function();

class AuthScreen extends StatefulWidget {
  final Widget child;
  final void Function()? onLogout;
  final ActivityCallback? onActivity;

  const AuthScreen({
    super.key,
    required this.child,
    this.onLogout,
    this.onActivity,
  });

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with WidgetsBindingObserver {
  final _auth = LocalAuthentication();
  bool _authenticated = false;
  bool _cancelled = false;
  String? _error;
  bool _wasPaused = false;
  Timer? _inactivityTimer;

  static const _inactivityTimeout = Duration(minutes: 3);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    logoutHandler = logout; // Safely sets the global lock tracker callback
    _authenticate();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _inactivityTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // Stop evaluation if the OS biometric window is on top
    if (isSystemAuthPromptActive) return;

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _wasPaused = _authenticated;
      _inactivityTimer?.cancel();
      return;
    }

    if (state == AppLifecycleState.resumed && _wasPaused) {
      _wasPaused = false;
      _lockApp();
    }
  }

  void _resetInactivityTimer() {
    _inactivityTimer?.cancel();
    if (_authenticated) {
      _inactivityTimer = Timer(_inactivityTimeout, _lockApp);
    }
  }

  void _lockApp() {
    _inactivityTimer?.cancel();
    if (mounted) {
      setState(() {
        _authenticated = false;
        _cancelled = false;
        _error = null;
      });
      _authenticate();
    }
  }

  void logout() {
    _lockApp();
  }

  Future<void> _authenticate() async {
    if (!mounted) return;
    setState(() {
      _cancelled = false;
      _error = null;
    });

    try {
      // Toggle the global state variable
      isSystemAuthPromptActive = true;

      final didAuthenticate = await _auth.authenticate(
        localizedReason: 'Authenticate to access the app',
        options: const AuthenticationOptions(
          stickyAuth: true,
          useErrorDialogs: false,
          biometricOnly: false,
        ),
      );

      isSystemAuthPromptActive = false;

      if (mounted) {
        setState(() {
          if (didAuthenticate) {
            _authenticated = true;
            _cancelled = false;
            _resetInactivityTimer();
          } else {
            _cancelled = true;
          }
        });
      }
    } on Exception catch (e) {
      isSystemAuthPromptActive = false;
      if (mounted) {
        setState(() {
          _error =
              'Authentication failed: ${e.toString().replaceAll('Exception: ', '')}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (_authenticated) _buildAuthenticatedContent(),
        if (!_authenticated) Positioned.fill(child: _buildLockScreen()),
      ],
    );
  }

  Widget _buildAuthenticatedContent() {
    return Listener(
      onPointerDown: (_) => _onActivity(),
      onPointerSignal: (event) => _onActivity(),
      behavior: HitTestBehavior.opaque,
      child: widget.child,
    );
  }

  void _onActivity() {
    widget.onActivity?.call();
    _resetInactivityTimer();
  }

  Widget _buildLockScreen() {
    final c = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [c.background, c.surface],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: AppRadii.brLg,
                    border: Border.all(color: c.outline),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: c.primarySubtle,
                          borderRadius: AppRadii.brMd,
                        ),
                        child: Icon(
                          Icons.lock_outline,
                          size: 26,
                          color: c.accent,
                        ),
                      ),
                      AppSpacing.gapLg,
                      Text(
                        'Data Collection Platform',
                        style: textTheme.titleLarge,
                      ),
                      AppSpacing.gapXs,
                      Text(
                        'Unlock to continue to your workspace.',
                        style: textTheme.bodyMedium,
                      ),
                      AppSpacing.gapLg,
                      Divider(height: 1, color: c.outline),
                      AppSpacing.gapLg,
                      if (_error != null) ...[
                        StatusBanner(message: _error!),
                        AppSpacing.gapLg,
                        PrimaryButton(
                          label: 'Try again',
                          icon: Icons.fingerprint,
                          onPressed: _authenticate,
                        ),
                      ] else if (_cancelled) ...[
                        Text(
                          'Your session is locked.',
                          style: textTheme.bodyMedium,
                        ),
                        AppSpacing.gapLg,
                        PrimaryButton(
                          label: 'Unlock',
                          icon: Icons.fingerprint,
                          onPressed: _authenticate,
                        ),
                      ] else
                        Row(
                          children: [
                            const SizedBox(
                              height: AppIconSize.md,
                              width: AppIconSize.md,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            AppSpacing.gapHMd,
                            Text(
                              'Authenticating…',
                              style: textTheme.bodyMedium,
                            ),
                          ],
                        ),
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
