import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/backend_config.dart';
import '../../l10n/app_localizations.dart';

class GoogleAuthTokens {
  const GoogleAuthTokens({required this.idToken, required this.accessToken});

  final String idToken;
  final String accessToken;
}

abstract interface class GoogleAuthService {
  Future<GoogleAuthTokens> authenticate();
}

/// What a learner is told when Google sign-in fails.
///
/// A pure function of the code, so every branch can be exercised without
/// standing up the plugin — which was the whole of this file's test coverage
/// problem. Google's own failure modes are not something a test can provoke,
/// but what we say about each of them is, and that is the part a learner
/// reads.
///
/// Exhaustive on purpose: no default branch, so a new code in a future
/// version of `google_sign_in` fails the build here rather than silently
/// becoming "unknown error".
String googleAuthMessage(
  GoogleSignInExceptionCode code,
  AppLocalizations l10n,
) => switch (code) {
  GoogleSignInExceptionCode.canceled => l10n.googleAuthCancelled,
  GoogleSignInExceptionCode.clientConfigurationError ||
  GoogleSignInExceptionCode.providerConfigurationError =>
    l10n.googleAuthConfigUnavailable,
  GoogleSignInExceptionCode.interrupted => l10n.googleAuthInterrupted,
  GoogleSignInExceptionCode.uiUnavailable => l10n.googleAuthUiUnavailable,
  GoogleSignInExceptionCode.userMismatch => l10n.googleAuthAccountChanged,
  GoogleSignInExceptionCode.unknownError => l10n.googleAuthUnknown,
};

/// Obtains Google tokens without changing the active Supabase session.
///
/// Keeping these two authentication steps separate is what lets AccountService
/// validate a returning Google account before replacing any local learner data.
class NativeGoogleAuthService implements GoogleAuthService {
  NativeGoogleAuthService({
    GoogleSignIn? signIn,
    AppLocalizations Function()? localizations,
  }) : _signIn = signIn ?? GoogleSignIn.instance,
       _localizations =
           localizations ?? (() => lookupAppLocalizations(const Locale('en')));

  final GoogleSignIn _signIn;

  /// Resolved at throw time, not construction time: this service outlives a
  /// language change, and the message is read after the failure, not before.
  final AppLocalizations Function() _localizations;
  Future<void>? _initialization;

  // Supabase needs an access token when Google's ID token includes `at_hash`.
  // Request the same non-sensitive identity scopes configured on the Google
  // consent screen; an empty scope list is rejected by Android's authorization
  // client on some devices.
  static const List<String> _identityScopes = <String>[
    'openid',
    'https://www.googleapis.com/auth/userinfo.email',
    'https://www.googleapis.com/auth/userinfo.profile',
  ];

  Future<void> _initialize() => _initialization ??= _initializeOnce();

  Future<void> _initializeOnce() async {
    final webClientId = GoogleAuthConfig.webClientId.trim();
    final iosClientId = GoogleAuthConfig.iosClientId.trim();
    if (webClientId.isEmpty) {
      throw AuthException(_localizations().googleAuthNotConfigured);
    }
    if (Platform.isIOS && iosClientId.isEmpty) {
      throw AuthException(_localizations().googleAuthNotConfiguredIos);
    }
    await _signIn.initialize(
      clientId: Platform.isIOS ? iosClientId : null,
      serverClientId: webClientId,
    );
  }

  @override
  Future<GoogleAuthTokens> authenticate() async {
    await _initialize();
    try {
      // Signing out here forces an account chooser and avoids accidentally
      // reusing a Google account selected during an earlier account switch.
      await _signIn.signOut();
      final account = await _signIn.authenticate();
      final authentication = account.authentication;
      final idToken = authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw AuthException(_localizations().googleAuthNoIdToken);
      }

      // Supabase verifies the access-token hash when Google includes `at_hash`
      // in the ID token. An empty scope list requests only the authorization
      // established by the sign-in itself and no extra Google data access.
      final authorization =
          await account.authorizationClient.authorizationForScopes(
            _identityScopes,
          ) ??
          await account.authorizationClient.authorizeScopes(_identityScopes);
      return GoogleAuthTokens(
        idToken: idToken,
        accessToken: authorization.accessToken,
      );
    } on GoogleSignInException catch (error) {
      throw AuthException(googleAuthMessage(error.code, _localizations()));
    }
  }
}
