import 'dart:async';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import '../main.dart' as app;

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
    app.logout = logout;
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

    if (state == AppLifecycleState.paused) {
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

  /// Called by the logout button in the app bar.
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
      final didAuthenticate = await _auth.authenticate(
        localizedReason: 'Authenticate to access the app',
        options: const AuthenticationOptions(
          stickyAuth: true,
          useErrorDialogs: false,
          biometricOnly: false,
        ),
      );

      if (mounted) {
        setState(() {
          if (didAuthenticate) {
            _authenticated = true;
            _cancelled = false;
          } else {
            _cancelled = true;
          }
        });
      }
    } on Exception catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Authentication failed: ${e.toString().replaceAll('Exception: ', '')}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Keep child in tree so nav stack is preserved,
    // but overlay the lock screen when not authenticated.
    return Stack(
      children: [
        if (_authenticated) _buildAuthenticatedContent(),
        if (!_authenticated)
          Positioned.fill(child: _buildLockScreen()),
      ],
    );
  }

  Widget _buildAuthenticatedContent() {
    _resetInactivityTimer();
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
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0A0A0F),
              Color(0xFF111827),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(
                      Icons.cloud_upload_outlined,
                      size: 40,
                      color: Color(0xFF60A5FA),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Data Collection Platform',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFE5E7EB),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const SizedBox(height: 48),

                  // Real error — red box
                  if (_error != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7F1D1D).withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: const Color(0xFFB91C1C).withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        _error!,
                        style: const TextStyle(
                            color: Color(0xFFFCA5A5), fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _authenticate,
                        icon: const Icon(Icons.fingerprint, size: 20),
                        label: const Text('Try Again'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          textStyle: const TextStyle(fontSize: 15),
                        ),
                      ),
                    ),
                  // User cancelled — neutral state
                  ] else if (_cancelled) ...[
                    const SizedBox(height: 24),
                    Text(
                      'Re-authenticate when ready.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _authenticate,
                        icon: const Icon(Icons.fingerprint, size: 20),
                        label: const Text('Authenticate'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          textStyle: const TextStyle(fontSize: 15),
                        ),
                      ),
                    ),
                  // Waiting for Face ID
                  ] else
                    const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                            Color(0xFF2563EB)),
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
}
