import 'dart:async';

import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

import '../main.dart';
import '../services/storage_service.dart';
import '../theme/theme.dart';
import '../widgets/ui/ui.dart';

class AuthScreen extends StatefulWidget {
  final Widget child;
  final VoidCallback? onActivity;

  const AuthScreen({
    super.key,
    required this.child,
    this.onActivity,
  });

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with WidgetsBindingObserver {
  final _auth = LocalAuthentication();
  bool _authenticated = false;
  bool _biometricShowing = false;
  bool _wasPaused = false;
  Timer? _inactivityTimer;
  Timer? _resumeDelayTimer;

  static const _inactivityTimeout = Duration(minutes: 3);

  /// Delay before showing biometric on app resume so the phone's own
  /// lock-screen unlock cycle finishes first and the two prompts don't overlap.
  static const _resumeDelay = Duration(milliseconds: 1000);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    logoutHandler = _lockApp;
    fullLogoutHandler = _performLogout;
    _authenticate();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _inactivityTimer?.cancel();
    _resumeDelayTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (isSystemAuthPromptActive) return;

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _wasPaused = _authenticated;
      _inactivityTimer?.cancel();
      _resumeDelayTimer?.cancel();
      return;
    }

    if (state == AppLifecycleState.resumed && _wasPaused) {
      _wasPaused = false;
      _scheduleLockOnResume();
    }
  }

  void _scheduleLockOnResume() {
    _resumeDelayTimer?.cancel();
    _resumeDelayTimer = Timer(_resumeDelay, () {
      if (mounted) {
        _lockApp();
      }
    });
  }

  void _resetInactivityTimer() {
    _inactivityTimer?.cancel();
    if (_authenticated) {
      _inactivityTimer = Timer(_inactivityTimeout, _lockApp);
    }
  }

  void _lockApp() {
    _inactivityTimer?.cancel();
    _resumeDelayTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _authenticated = false;
      _biometricShowing = false;
    });
    _authenticate();
  }

  /// Clears the stored browser ID (breaking linkage to past submissions) and
  /// drops the user back to the biometric gate.
  Future<void> _performLogout() async {
    await StorageService.clearBrowserId();
    if (!mounted) return;
    _lockApp();
  }

  Future<void> _authenticate() async {
    if (!mounted) return;
    setState(() {
      _biometricShowing = true;
    });

    try {
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

      if (!mounted) return;

      if (didAuthenticate) {
        setState(() {
          _authenticated = true;
          _biometricShowing = false;
        });
        _resetInactivityTimer();
      } else {
        // User cancelled — stay on lock screen, clear the spinner.
        setState(() {
          _biometricShowing = false;
        });
      }
    } on Exception {
      isSystemAuthPromptActive = false;
      if (!mounted) return;
      setState(() {
        _biometricShowing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_authenticated) {
      return _buildAuthenticatedContent();
    }
    return _buildLockScreen();
  }

  Widget _buildAuthenticatedContent() {
    return Listener(
      onPointerDown: (_) => _onActivity(),
      onPointerSignal: (_) => _onActivity(),
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
                      if (_biometricShowing) ...[
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
                      ] else ...[
                        PrimaryButton(
                          label: 'Unlock',
                          icon: Icons.fingerprint,
                          onPressed: _authenticate,
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
