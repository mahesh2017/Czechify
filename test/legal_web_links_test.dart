import 'package:czechify/core/legal/legal_content.dart';
import 'package:czechify/presentation/providers/account_providers.dart';
import 'package:czechify/presentation/screens/settings/about_screen.dart';
import 'package:czechify/presentation/screens/settings/account_screen.dart';
import 'package:czechify/presentation/screens/settings/privacy_policy_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/localized_app.dart';

const _launcherChannel = MethodChannel('plugins.flutter.io/url_launcher');

void main() {
  late String? launchedUrl;

  setUp(() {
    launchedUrl = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_launcherChannel, (call) async {
          final arguments = call.arguments;
          if (arguments is Map) launchedUrl = arguments['url'] as String?;
          return true;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_launcherChannel, null);
  });

  Widget app(Widget home) => MaterialApp(
    localizationsDelegates: testLocalizationsDelegates,
    supportedLocales: testSupportedLocales,
    home: home,
  );

  testWidgets('About opens the canonical Czechify website', (tester) async {
    await tester.pumpWidget(ProviderScope(child: app(const AboutScreen())));
    final link = find.text('Official Czechify website');
    await tester.scrollUntilVisible(link, 600);

    await tester.tap(link);
    await tester.pumpAndSettle();

    expect(launchedUrl, kWebsiteUrl);
  });

  testWidgets('About names Sabiko Apps and links the terms', (tester) async {
    // Build 31 shipped with "Mahesh Pathak" here after the Play account had
    // become Sabiko Global's.
    await tester.pumpWidget(ProviderScope(child: app(const AboutScreen())));
    await tester.scrollUntilVisible(find.text('Sabiko Apps'), 600);
    expect(find.text('Sabiko Apps'), findsOneWidget);
    expect(
      find.text('Designed, built and maintained by Sabiko Apps.'),
      findsOneWidget,
    );
    expect(find.textContaining('Mahesh Pathak'), findsNothing);

    final terms = find.text('Terms of Service');
    await tester.scrollUntilVisible(terms, 600);
    await tester.tap(terms);
    await tester.pumpAndSettle();
    expect(launchedUrl, kTermsOfServiceUrl);
  });

  testWidgets('Privacy keeps full in-app text and links the public policy', (
    tester,
  ) async {
    await tester.pumpWidget(app(const PrivacyPolicyScreen()));
    expect(find.text('Who is responsible'), findsOneWidget);

    final link = find.text('View privacy policy on the Czechify website');
    await tester.scrollUntilVisible(link, 800);
    await tester.tap(link);
    await tester.pumpAndSettle();

    expect(launchedUrl, kPrivacyPolicyUrl);
  });

  testWidgets('Account data screen links the external deletion route', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountUserProvider.overrideWith((ref) => Stream.value(null)),
        ],
        child: app(const AccountScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final link = find.text('Account deletion instructions online');
    await tester.scrollUntilVisible(link, 800);
    expect(link, findsOneWidget);
    await tester.tap(link);
    await tester.pumpAndSettle();

    expect(launchedUrl, kAccountDeletionUrl);
  });
}
