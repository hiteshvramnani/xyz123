import 'package:flutter/material.dart';
import 'screens/auth_screen.dart';
import 'screens/submit_screen.dart';
import 'services/api_service.dart';
import 'config.dart';

late final ApiService apiService;

/// Called to lock the app and re-prompt Face ID.
void Function() logout = () {};

/// Show the hamburger menu.
void showMenu(BuildContext context, {required void Function() onNavigateSubmissions, required void Function() onLock, void Function()? onNavigateNew}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF111827),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onNavigateNew != null)
            ListTile(
              leading: const Icon(Icons.add_circle_outline, color: Color(0xFF9CA3AF)),
              title: const Text('New Submission', style: TextStyle(color: Color(0xFFE5E7EB))),
              onTap: () {
                Navigator.pop(ctx);
                onNavigateNew();
              },
            ),
          ListTile(
            leading: const Icon(Icons.list, color: Color(0xFF9CA3AF)),
            title: const Text('My Submissions', style: TextStyle(color: Color(0xFFE5E7EB))),
            onTap: () {
              Navigator.pop(ctx);
              onNavigateSubmissions();
            },
          ),
          ListTile(
            leading: const Icon(Icons.lock_outline, color: Color(0xFFEF4444)),
            title: const Text('Lock', style: TextStyle(color: Color(0xFFEF4444))),
            onTap: () {
              Navigator.pop(ctx);
              onLock();
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

void main() {
  apiService = ApiService(baseUrl: baseUrl);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Data',
      debugShowCheckedModeBanner: false,
      theme: darkTheme,
      home: const AuthScreen(child: _AppRoot()),
    );
  }
}

/// Navigable app content shown only after authentication.
class _AppRoot extends StatelessWidget {
  const _AppRoot();

  @override
  Widget build(BuildContext context) {
    return const SubmitScreen();
  }
}

final darkTheme = ThemeData.from(
  colorScheme: const ColorScheme.dark(
    primary: Color(0xFF2563EB),
    onPrimary: Colors.white,
    surface: Color(0xFF111827),
    onSurface: Color(0xFFE5E7EB),
    onSurfaceVariant: Color(0xFF9CA3AF),
    outline: Color(0xFF1F2937),
  ),
).copyWith(
  scaffoldBackgroundColor: const Color(0xFF0A0A0F),
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFF111827),
    elevation: 0,
    titleTextStyle: TextStyle(
      color: Color(0xFFE5E7EB),
      fontSize: 20,
      fontWeight: FontWeight.bold,
    ),
    iconTheme: IconThemeData(color: Color(0xFF9CA3AF)),
  ),
  cardTheme: const CardThemeData(
    color: Color(0xFF111827),
    elevation: 0,
    margin: EdgeInsets.zero,
  ),
  inputDecorationTheme: const InputDecorationTheme(
    filled: true,
    fillColor: Color(0xFF111827),
    border: OutlineInputBorder(
      borderSide: BorderSide(color: Color(0xFF1F2937)),
      borderRadius: BorderRadius.all(Radius.circular(6)),
    ),
    enabledBorder: OutlineInputBorder(
      borderSide: BorderSide(color: Color(0xFF1F2937)),
      borderRadius: BorderRadius.all(Radius.circular(6)),
    ),
    focusedBorder: OutlineInputBorder(
      borderSide: BorderSide(color: Color(0xFF2563EB)),
      borderRadius: BorderRadius.all(Radius.circular(6)),
    ),
    hintStyle: TextStyle(color: Color(0xFF6B7280)),
    labelStyle: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  ),
  textTheme: const TextTheme(
    bodyLarge: TextStyle(color: Color(0xFFE5E7EB)),
    bodyMedium: TextStyle(color: Color(0xFF9CA3AF)),
    bodySmall: TextStyle(color: Color(0xFF6B7280)),
    labelLarge: TextStyle(color: Color(0xFFE5E7EB), fontWeight: FontWeight.w500),
  ),
  iconTheme: const IconThemeData(color: Color(0xFF9CA3AF)),
);
