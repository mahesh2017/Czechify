import 'package:czechify/core/theme/app_theme.dart';
import 'package:czechify/domain/entities/curriculum_entitlement.dart';
import 'package:czechify/presentation/providers/account_providers.dart';
import 'package:czechify/presentation/providers/curriculum_providers.dart';
import 'package:czechify/presentation/screens/settings/account_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support/localized_app.dart';

void main() {
  testWidgets('account screen identifies active reviewer access', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountUserProvider.overrideWith((ref) => Stream.value(null)),
          curriculumEntitlementProvider.overrideWith(
            (ref) async => const CurriculumEntitlement(unlockAll: true),
          ),
        ],
        child: MaterialApp(
          theme: lightTheme(),
          localizationsDelegates: testLocalizationsDelegates,
          supportedLocales: testSupportedLocales,
          home: const AccountScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Reviewer access active'), findsOneWidget);
    expect(find.bySemanticsLabel('Sign in with Google'), findsOneWidget);
    expect(
      find.text('All course units and lessons are available on this account.'),
      findsOneWidget,
    );
  });

  testWidgets('linked Google account shows status instead of sign-in button', (
    tester,
  ) async {
    final user = User.fromJson({
      'id': 'learner',
      'aud': 'authenticated',
      'email': 'learner@example.com',
      'created_at': '2026-08-25T00:00:00Z',
      'app_metadata': {
        'provider': 'google',
        'providers': ['google'],
      },
      'user_metadata': <String, Object?>{},
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountUserProvider.overrideWith((ref) => Stream.value(user)),
          curriculumEntitlementProvider.overrideWith(
            (ref) async => CurriculumEntitlement.none,
          ),
        ],
        child: MaterialApp(
          theme: lightTheme(),
          localizationsDelegates: testLocalizationsDelegates,
          supportedLocales: testSupportedLocales,
          home: const AccountScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Google account connected'), findsOneWidget);
    expect(find.bySemanticsLabel('Sign in with Google'), findsNothing);
  });
}
