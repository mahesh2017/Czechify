import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../../../core/age_signals/play_age_signals_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/settings_providers.dart';

class AgeSignalsGateApp extends StatelessWidget {
  const AgeSignalsGateApp({
    required this.decision,
    required this.onRetry,
    required this.onOpenPlayStore,
    super.key,
  });

  final AgeEligibilityDecision decision;
  final VoidCallback onRetry;
  final VoidCallback onOpenPlayStore;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: lightTheme(),
      darkTheme: darkTheme(),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: kInterfaceLocales,
      home: AgeSignalsGateScreen(
        decision: decision,
        onRetry: onRetry,
        onOpenPlayStore: onOpenPlayStore,
      ),
    );
  }
}

class AgeSignalsGateScreen extends StatelessWidget {
  const AgeSignalsGateScreen({
    required this.decision,
    required this.onRetry,
    required this.onOpenPlayStore,
    super.key,
  });

  final AgeEligibilityDecision decision;
  final VoidCallback onRetry;
  final VoidCallback onOpenPlayStore;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final (icon, title, body, showPlayStore) = switch (decision.outcome) {
      AgeEligibilityOutcome.underMinimumAge => (
        Icons.shield_outlined,
        l10n.ageSignalsUnderAgeTitle,
        l10n.ageSignalsUnderAgeBody,
        true,
      ),
      AgeEligibilityOutcome.verificationRequired => (
        Icons.verified_user_outlined,
        l10n.ageSignalsVerificationTitle,
        l10n.ageSignalsVerificationBody,
        true,
      ),
      AgeEligibilityOutcome.parentApprovalPending => (
        Icons.family_restroom_rounded,
        l10n.ageSignalsApprovalPendingTitle,
        l10n.ageSignalsApprovalPendingBody,
        false,
      ),
      AgeEligibilityOutcome.parentApprovalDeclined => (
        Icons.family_restroom_rounded,
        l10n.ageSignalsApprovalDeclinedTitle,
        l10n.ageSignalsApprovalDeclinedBody,
        false,
      ),
      AgeEligibilityOutcome.temporarilyUnavailable => (
        Icons.cloud_off_outlined,
        l10n.ageSignalsUnavailableTitle,
        l10n.ageSignalsUnavailableBody,
        true,
      ),
      AgeEligibilityOutcome.allowed =>
        throw StateError(
          'The age-signals gate must not be shown for an allowed decision.',
        ),
    };

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 68,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    body,
                    textAlign: TextAlign.center,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyLarge?.copyWith(height: 1.5),
                  ),
                  if (showPlayStore) ...[
                    const SizedBox(height: 28),
                    FilledButton.icon(
                      onPressed: onOpenPlayStore,
                      icon: const Icon(Icons.shop_outlined),
                      label: Text(l10n.ageSignalsOpenPlayStore),
                    ),
                  ],
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(l10n.ageSignalsCheckAgain),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    l10n.ageSignalsPrivacyNote,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
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
