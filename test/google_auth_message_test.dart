import 'package:czechify/data/account/google_auth_service.dart';
import 'package:czechify/l10n/app_localizations_cs.dart';
import 'package:czechify/l10n/app_localizations_en.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Google sign-in had no test of any kind.
///
/// Most of what it does cannot be tested here — the plugin talks to Play
/// Services and an account chooser, and no test provokes a real
/// `GoogleSignInException`. What *can* be tested is the only part a learner
/// ever sees: which sentence each failure produces. Every one of those was a
/// hardcoded English string inside a `catch`, shown straight to the user by
/// `account_screen`, and invisible to `localization_coverage_test` because it
/// sits in an `AuthException(...)` rather than a widget.
void main() {
  test('every Google failure code has its own sentence', () {
    final l10n = AppLocalizationsEn();
    final messages = <GoogleSignInExceptionCode, String>{
      for (final code in GoogleSignInExceptionCode.values)
        code: googleAuthMessage(code, l10n),
    };

    // `values` rather than a list written here: a code added by a future
    // version of the plugin is then a compile error in `googleAuthMessage`,
    // which has no default branch, instead of silently landing on "unknown".
    expect(messages, hasLength(GoogleSignInExceptionCode.values.length));
    for (final entry in messages.entries) {
      expect(
        entry.value.trim(),
        isNotEmpty,
        reason: '${entry.key} produces an empty message',
      );
    }

    // The two configuration codes deliberately share one sentence — a learner
    // cannot act differently on them. Everything else says something
    // distinct, because a message that does not distinguish a cancelled
    // sign-in from a broken one is not worth showing.
    final distinct = messages.values.toSet();
    expect(
      distinct,
      hasLength(GoogleSignInExceptionCode.values.length - 1),
      reason: 'Two codes other than the configuration pair share a message',
    );
    expect(
      googleAuthMessage(
        GoogleSignInExceptionCode.clientConfigurationError,
        l10n,
      ),
      googleAuthMessage(
        GoogleSignInExceptionCode.providerConfigurationError,
        l10n,
      ),
    );
  });

  test('the sentences are translated, not passed through', () {
    final english = AppLocalizationsEn();
    final czech = AppLocalizationsCs();
    for (final code in GoogleSignInExceptionCode.values) {
      final cs = googleAuthMessage(code, czech);
      expect(cs.trim(), isNotEmpty);
      expect(
        cs,
        isNot(googleAuthMessage(code, english)),
        reason: '$code still reads in English in the Czech build',
      );
    }
  });

  test('the resolver is not consulted until something fails', () {
    // The service outlives a language change and the message is read after
    // the failure, so holding an AppLocalizations from construction time
    // would pin a learner's errors to whatever language they opened the app
    // in. Constructing the service must therefore resolve nothing.
    var calls = 0;
    NativeGoogleAuthService(
      localizations: () {
        calls++;
        return AppLocalizationsEn();
      },
    );
    expect(calls, 0);
  });
}
