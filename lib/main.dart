import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'core/theme/app_theme.dart';
import 'l10n/app_localizations.dart';
import 'core/diagnostics/safe_diagnostics.dart';
import 'core/notifications/notification_service.dart';
import 'core/notifications/navigation_intent.dart';
import 'presentation/routes/app_router.dart';
import 'presentation/routes/app_shell_keys.dart';
import 'presentation/providers/database_providers.dart';
import 'presentation/providers/daily_arrival_providers.dart';
import 'presentation/providers/curriculum_providers.dart';
import 'presentation/providers/feedback_providers.dart';
import 'presentation/providers/settings_providers.dart';
import 'presentation/providers/sync_providers.dart';
import 'presentation/providers/reminder_coordinator.dart';
import 'presentation/providers/learner_profile_providers.dart';
import 'presentation/widgets/celebration/celebration_host.dart';
import 'presentation/widgets/common/app_update_coordinator.dart';
import 'presentation/screens/onboarding/loading_screen.dart';

/// App entry point.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Portrait only. Every screen in this app is drawn against a tall viewport —
  // notch-sized top paddings, fixed-height exercise images, decorations placed
  // in portrait coordinates — and none of that was ever adapted. Rotated to
  // landscape the app stayed usable but showed its seams: the name step
  // overflowed by 99px once the keyboard was up, and 115 listening-
  // comprehension cards overflowed outright, every single one carrying an
  // image among them.
  //
  // Nothing had ever asked for portrait; the platform manifests simply carried
  // Flutter's default template, which permits both landscape modes. This is
  // the request, and the iOS and Android manifests are narrowed to match so
  // the OS enforces it rather than merely being asked.
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  try {
    await NotificationService.instance.initialize();
  } catch (e, stack) {
    SafeDiagnostics.error('notification_init_failed', e, stack);
  }

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

  runApp(const ProviderScope(child: CzechifyApp()));
}

/// Root app widget.
class CzechifyApp extends ConsumerStatefulWidget {
  const CzechifyApp({super.key});

  @override
  ConsumerState<CzechifyApp> createState() => _CzechifyAppState();
}

class _CzechifyAppState extends ConsumerState<CzechifyApp>
    with WidgetsBindingObserver {
  StreamSubscription<NavigationTarget>? _navigationSubscription;
  NavigationTarget? _pendingNavigation;
  bool _navigationFlushScheduled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _navigationSubscription = NavigationIntent.stream.listen((target) {
      if (!mounted) return;
      setState(() => _pendingNavigation = target);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _navigationSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Reviewer/support access is server-owned and may have changed while
      // the app was backgrounded. Invalidating its provider also invalidates
      // the curriculum graph that watches it; the repository retains the last
      // result for this auth user if the refresh is offline.
      ref.invalidate(curriculumEntitlementProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
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
    // Backfill account-scoped profile data from legacy local preferences. It
    // is deliberately background work and never delays a usable first frame.
    ref.watch(learnerProfileBootstrapProvider);
    // Keep the reminder coordinator alive so it can react to settings
    // changes, XP transitions, and app lifecycle events.
    ref.watch(reminderCoordinatorProvider);

    _flushNotificationNavigation();

    // Warm the answer sounds before the first lesson. Loading one on first use
    // costs enough to be heard as lag on a clip meant to land with the tap.
    ref.read(feedbackServiceProvider).preload();

    return MaterialApp.router(
      scaffoldMessengerKey: rootScaffoldMessengerKey,
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
          (context, child) => AppUpdateCoordinator(
            // Never interrupt first-run setup with a store prompt. The saved
            // flag enables the quiet Play check on the next app launch.
            enabled: onboardingDone.value ?? false,
            child: CelebrationHost(child: child ?? const SizedBox.shrink()),
          ),
    );
  }

  void _flushNotificationNavigation() {
    if (_pendingNavigation == null || _navigationFlushScheduled) return;
    _navigationFlushScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _navigationFlushScheduled = false;
      if (!mounted) return;
      final target = _pendingNavigation;
      _pendingNavigation = null;
      final location = switch (target) {
        NavigationTarget.curriculum => '/curriculum',
        NavigationTarget.review => '/review',
        null => null,
      };
      if (location != null) ref.read(appRouterProvider).go(location);
    });
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
