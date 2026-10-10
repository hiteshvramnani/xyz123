// Widget/unit tests for the redesigned foundation.
//
// These intentionally avoid pumping the full `MyApp`, because the app shell
// drives biometric auth (`local_auth`) and screenshot protection
// (`screen_protector`) through platform channels that aren't available in a
// widget-test harness. Instead we cover the pure design-system pieces and
// deterministic helpers, which is where the redesign's logic lives.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:native_app/theme/theme.dart';
import 'package:native_app/widgets/date_formatter.dart';
import 'package:native_app/widgets/ui/ui.dart';

Widget _host(Widget child) => MaterialApp(
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  group('formatFileSize', () {
    test('formats across unit boundaries', () {
      expect(formatFileSize(0), '0 B');
      expect(formatFileSize(500), '500 B');
      expect(formatFileSize(1024), '1 KB');
      expect(formatFileSize(1536), '1.5 KB');
      expect(formatFileSize(1024 * 1024), '1 MB');
    });
  });

  group('formatDate', () {
    test('passes through empty and unparseable input', () {
      expect(formatDate(''), '');
      expect(formatDate(null), '');
      expect(formatDate('not-a-date'), 'not-a-date');
    });

    test('renders a parseable timestamp with its year', () {
      expect(formatDate('2025-10-08T14:14:00'), contains('2025'));
      expect(formatDate('2025-10-08T14:14:00'), contains('Oct'));
    });
  });

  group('PrimaryButton', () {
    testWidgets('shows a spinner and is disabled while loading',
        (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _host(PrimaryButton(
          label: 'Submit',
          loading: true,
          onPressed: () => tapped = true,
        )),
      );

      expect(find.text('Submit'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.tap(find.byType(PrimaryButton));
      await tester.pump();
      expect(tapped, isFalse);
    });

    testWidgets('invokes onPressed when enabled', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _host(PrimaryButton(
          label: 'Submit',
          onPressed: () => tapped = true,
        )),
      );

      expect(find.text('Submit'), findsOneWidget);
      await tester.tap(find.byType(PrimaryButton));
      await tester.pump();
      expect(tapped, isTrue);
    });
  });

  group('StatusBanner', () {
    testWidgets('renders its message', (tester) async {
      await tester.pumpWidget(
        _host(const StatusBanner(message: 'Something went wrong')),
      );
      expect(find.text('Something went wrong'), findsOneWidget);
    });
  });

  group('AppTheme', () {
    test('exposes the AppColors extension in both themes', () {
      expect(AppTheme.dark.extension<AppColors>(), isNotNull);
      expect(AppTheme.light.extension<AppColors>(), isNotNull);
      expect(AppTheme.dark.extension<AppColors>()!.brightness, Brightness.dark);
      expect(
          AppTheme.light.extension<AppColors>()!.brightness, Brightness.light);
    });
  });
}
