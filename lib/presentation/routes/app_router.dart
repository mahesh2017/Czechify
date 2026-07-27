import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../core/theme/app_tokens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../screens/home/home_screen.dart';
import '../screens/curriculum/curriculum_screen.dart';
import '../screens/lesson/lesson_player_screen.dart';
import '../screens/review/srs_review_screen.dart';
import '../screens/chat/chat_screen.dart';
import '../screens/pronunciation/pronunciation_screen.dart';
import '../screens/exam/mock_exam_screen.dart';
import '../screens/stats/stats_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/settings/account_screen.dart';
import '../screens/grammar/grammar_reference_screen.dart';
import '../screens/grammar/quick_reference_screen.dart';
import '../screens/onboarding/offline_setup_screen.dart';
import '../screens/settings/about_screen.dart';
import '../screens/settings/privacy_policy_screen.dart';
import '../screens/onboarding/onboarding_screen.dart';
import '../screens/placement/placement_screen.dart';
import '../screens/lesson/delayed_transfer_screen.dart';
import '../providers/settings_providers.dart';
import 'app_scaffold.dart';
import '../../domain/entities/enums.dart';

/// App router. First launch starts at onboarding; after that, home.
///
/// The onboarding flag is only read for the INITIAL location — finishing
/// onboarding navigates with `context.go('/')`, so the provider is not
/// invalidated mid-session (that would recreate the router and reset
/// navigation state).
final appRouterProvider = Provider<GoRouter>((ref) {
  final onboardingDone = ref
      .watch(onboardingDoneProvider)
      .maybeWhen(data: (done) => done, orElse: () => true);

  return GoRouter(
    initialLocation: onboardingDone ? '/' : '/onboarding',
    // Unknown paths and malformed parameters land here instead of crashing.
    errorBuilder:
        (context, state) => Scaffold(
          appBar: AppBar(title: const Text('Not found')),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.explore_off, size: 48, color: context.tokens.muted),
                const SizedBox(height: 16),
                const Text('That page could not be opened.'),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => context.go('/'),
                  child: Text(AppLocalizations.of(context).goHome),
                ),
              ],
            ),
          ),
        ),
    routes: [
      // Tab destinations live inside the adaptive shell.
      ShellRoute(
        builder: (context, state, child) => AdaptiveScaffold(child: child),
        routes: [
          GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
          GoRoute(
            path: '/curriculum',
            builder: (context, state) => const CurriculumScreen(),
          ),
          GoRoute(
            path: '/review',
            builder: (context, state) => const SrsReviewScreen(),
          ),
          GoRoute(
            path: '/chat',
            builder: (context, state) => const ChatScreen(),
          ),
          GoRoute(
            path: '/stats',
            builder: (context, state) => const StatsScreen(),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsScreen(),
          ),
        ],
      ),

      // Full-screen flows — no bottom nav / side rail. These are pushed
      // (context.push) so closing them pops back to where the user was.
      GoRoute(
        path: '/account',
        builder: (context, state) => const AccountScreen(),
      ),
      // Reached with go() from the end of onboarding, so it replaces the flow
      // rather than sitting on top of it — there is nothing to go back to.
      GoRoute(path: '/about', builder: (context, state) => const AboutScreen()),
      GoRoute(
        path: '/privacy',
        builder: (context, state) => const PrivacyPolicyScreen(),
      ),
      GoRoute(
        path: '/setup',
        builder: (context, state) => const OfflineSetupScreen(),
      ),
      GoRoute(
        path: '/lesson/:id',
        // tryParse: a malformed deep link must not crash the router.
        redirect:
            (context, state) =>
                int.tryParse(state.pathParameters['id'] ?? '') == null
                    ? '/'
                    : null,
        builder:
            (context, state) => LessonPlayerScreen(
              lessonId: int.parse(state.pathParameters['id']!),
            ),
      ),
      GoRoute(
        path: '/pronunciation/:id',
        builder:
            (context, state) =>
                PronunciationScreen(exerciseId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/exam/:level',
        builder:
            (context, state) => MockExamScreen(
              level:
                  state.pathParameters['level']! == 'a2'
                      ? ExamLevel.a2
                      : ExamLevel.a1,
            ),
      ),
      GoRoute(
        path: '/grammar',
        builder:
            (context, state) => GrammarReferenceScreen(
              highlightRuleId: state.uri.queryParameters['rule'],
            ),
      ),
      GoRoute(
        path: '/reference/:type',
        builder:
            (context, state) =>
                QuickReferenceScreen(type: state.pathParameters['type']!),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/placement',
        builder: (context, state) => const PlacementScreen(),
      ),
      GoRoute(
        path: '/transfer/:id',
        builder:
            (context, state) => DelayedTransferScreen(
              assignmentId: state.pathParameters['id']!,
            ),
      ),
    ],
  );
});
