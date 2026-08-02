import 'dart:async';
import 'package:flutter/foundation.dart';
import 'data/services/stt/stt_bench_hook.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'core/theme/app_theme.dart';
import 'l10n/app_localizations.dart';
import 'core/diagnostics/safe_diagnostics.dart';
import 'presentation/routes/app_router.dart';
import 'presentation/providers/database_providers.dart';
import 'presentation/providers/daily_arrival_providers.dart';
import 'presentation/providers/feedback_providers.dart';
import 'presentation/providers/settings_providers.dart';
import 'presentation/providers/sync_providers.dart';
import 'presentation/widgets/celebration/celebration_host.dart';
import 'presentation/screens/onboarding/loading_screen.dart';

/// App entry point.
void main() {
  // Surface package:logging output during development; keep release quiet.
  Logger.root.level = kDebugMode ? Level.INFO : Level.WARNING;
  Logger.root.onRecord.listen((record) {
    debugPrint(
      '[${record.level.name}] ${record.loggerName}: '
      '${record.message}'
      '${record.error != null ? ' — ${record.error}' : ''}',
    );
  });

  // Catch unhandled async errors that would otherwise crash the app in
  // release/non-debug mode. In debug mode these are surfaced via the
  // Flutter Error widget; without this guard they terminate the process
  // silently when launched from the home screen.
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    SafeDiagnostics.error(
      'flutter_framework',
      details.exception,
      details.stack ?? StackTrace.current,
    );
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    SafeDiagnostics.error('unhandled_async', error, stack);
    return true; // Suppress — the app stays alive.
  };

  // Debug/profile only, and only when a model has been side-loaded — see
  // SttBenchHook. Unawaited so it never delays first paint.
  unawaited(SttBenchHook.maybeRun());

  runApp(const ProviderScope(child: CzechifyApp()));
}

/// Root app widget.
class CzechifyApp extends ConsumerWidget {
  const CzechifyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final initFuture = ref.watch(appInitializationProvider);
    final onboardingDone = ref.watch(onboardingDoneProvider);
    final arrivalDue = ref.watch(dailyArrivalDueProvider);
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(
      settingsProvider.select((settings) => settings.locale),
    );

    // Wait for both DB seeding and the onboarding flag before building the
    // router, so the initial location is decided from real data.
    if (initFuture.isLoading ||
        onboardingDone.isLoading ||
        arrivalDue.isLoading) {
      return const LoadingScreen();
    }
    if (initFuture.hasError) {
      return LoadingScreen(
        error: _startupErrorMessage(initFuture.error),
        onRetry: () {
          ref.invalidate(appInitializationProvider);
        },
      );
    }

    // Keep remote auth, sync, and curriculum refresh alive after the verified
    // local course is ready. Its failure must not replace the usable app UI.
    ref.watch(backgroundInitializationProvider);
    ref.watch(syncTriggerCoordinatorProvider);

    // Warm the answer sounds before the first lesson. Loading one on first use
    // costs enough to be heard as lag on a clip meant to land with the tap.
    ref.read(feedbackServiceProvider).preload();

    return MaterialApp.router(
      title: 'Czechify',
      debugShowCheckedModeBanner: false,
      theme: lightTheme(),
      darkTheme: darkTheme(),
      themeMode: themeMode,
      // Null lets Flutter resolve the device locale against supportedLocales.
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: kInterfaceLocales,
      routerConfig: ref.watch(appRouterProvider),
      // Above the router: finishing a lesson navigates away from the lesson
      // player, so a celebration owned by that screen would be disposed at
      // the moment it was supposed to play.
      builder:
          (context, child) =>
              CelebrationHost(child: child ?? const SizedBox.shrink()),
    );
  }
}

String _startupErrorMessage(Object? error) {
  final detail = error?.toString().toLowerCase() ?? '';
  if (detail.contains('incomplete') || detail.contains('missing')) {
    return 'The packaged course content is incomplete. Please reinstall or '
        'update the app.';
  }
  return 'The course could not be prepared on this device. Please try again.';
}
