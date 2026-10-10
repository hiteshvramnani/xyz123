import 'package:flutter/material.dart';
import 'package:screen_protector/screen_protector.dart';

import 'screens/auth_screen.dart';
import 'screens/submit_screen.dart';
import 'services/api_service.dart';
import 'theme/theme.dart';
import 'widgets/ui/ui.dart';
import 'config.dart';

late final ApiService apiService;

/// Global state handlers accessible by child screens
void Function() logoutHandler = () {};
bool isSystemAuthPromptActive = false;

/// Shows the shared overflow menu as a themed options sheet. Kept as a single
/// entry point so the submit, log and detail screens share one menu instead of
/// re-declaring it each time.
void showMenu(
  BuildContext context, {
  required void Function() onNavigateSubmissions,
  required void Function() onLock,
  void Function()? onNavigateNew,
}) {
  showAppOptionsSheet(
    context,
    options: [
      if (onNavigateNew != null)
        AppSheetOption(
          icon: Icons.add_circle_outline,
          label: 'New Submission',
          onTap: onNavigateNew,
        ),
      AppSheetOption(
        icon: Icons.list_alt_outlined,
        label: 'My Submissions',
        onTap: onNavigateSubmissions,
      ),
      AppSheetOption(
        icon: Icons.lock_outline,
        label: 'Lock',
        onTap: onLock,
        isDestructive: true,
      ),
    ],
  );
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  apiService = ApiService(baseUrl: baseUrl);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Data Collection Platform',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: const _AppWrapper(),
    );
  }
}

class _AppWrapper extends StatefulWidget {
  const _AppWrapper();

  @override
  State<_AppWrapper> createState() => _AppWrapperState();
}

class _AppWrapperState extends State<_AppWrapper> with WidgetsBindingObserver {
  bool _isAppInBackground = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initScreenProtection();
  }

  void _initScreenProtection() async {
    await ScreenProtector.preventScreenshotOn();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;

    // Ignore lifecycle evaluation if the OS biometrics box is active
    if (isSystemAuthPromptActive) return;

    setState(() {
      _isAppInBackground =
          (state == AppLifecycleState.paused ||
          state == AppLifecycleState.inactive);
    });
  }

  @override
  Widget build(BuildContext context) {
    return _isAppInBackground
        ? const _PrivacyShield()
        : const AuthScreen(child: _AppRoot());
  }
}

/// Shown while the app is backgrounded to keep sensitive content out of the
/// app switcher preview.
class _PrivacyShield extends StatelessWidget {
  const _PrivacyShield();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: c.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline, color: c.danger, size: AppIconSize.xl),
            AppSpacing.gapLg,
            Text(
              'App is minimized for your security',
              style: textTheme.bodyLarge?.copyWith(color: c.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppRoot extends StatelessWidget {
  const _AppRoot();

  @override
  Widget build(BuildContext context) {
    return const SubmitScreen();
  }
}
