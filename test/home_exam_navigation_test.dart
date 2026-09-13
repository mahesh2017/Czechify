import 'package:czechify/core/theme/app_theme.dart';
import 'package:czechify/domain/entities/enums.dart';
import 'package:czechify/presentation/providers/curriculum_providers.dart';
import 'package:czechify/presentation/providers/gamification_providers.dart';
import 'package:czechify/presentation/providers/review_providers.dart';
import 'package:czechify/presentation/providers/settings_providers.dart';
import 'package:czechify/presentation/providers/tts_providers.dart';
import 'package:czechify/presentation/screens/home/home_screen.dart';
import 'package:czechify/presentation/screens/lesson/delayed_transfer_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/lesson_session_harness.dart';
import 'support/localized_app.dart';

void main() {
  for (final level in [CEFRLevel.a1, CEFRLevel.a2]) {
    testWidgets('Home opens mock exam for ${level.name}', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer(
        overrides: [
          gamificationProvider.overrideWith(TestGamificationNotifier.new),
          nextLessonProvider.overrideWith((ref) async => null),
          dueCardCountProvider.overrideWith((ref) async => 0),
          dueTransferProvider.overrideWith((ref) async => []),
          czechTtsAvailableProvider.overrideWith((ref) async => true),
        ],
      );
      addTearDown(container.dispose);
      final settings = container.read(settingsProvider.notifier);
      await settings.ready;
      await settings.setStartingLevel(level);
      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
          GoRoute(
            path: '/exam/:level',
            builder:
                (_, state) => Scaffold(
                  body: Text('Opened ${state.pathParameters['level']} exam'),
                ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            theme: lightTheme(),
            routerConfig: router,
            localizationsDelegates: testLocalizationsDelegates,
            supportedLocales: testSupportedLocales,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final shortcut = find.text('Mock exam');
      await tester.ensureVisible(shortcut);
      await tester.pumpAndSettle();
      await tester.tap(shortcut);
      await tester.pumpAndSettle();
      expect(find.text('Opened ${level.name} exam'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
