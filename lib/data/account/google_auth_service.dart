import 'dart:io';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/backend_config.dart';

class GoogleAuthTokens {
  const GoogleAuthTokens({required this.idToken, required this.accessToken});

  final String idToken;
  final String accessToken;
}

abstract interface class GoogleAuthService {
  Future<GoogleAuthTokens> authenticate();
}

/// Obtains Google tokens without changing the active Supabase session.
///
/// Keeping these two authentication steps separate is what lets AccountService
/// validate a returning Google account before replacing any local learner data.
class NativeGoogleAuthService implements GoogleAuthService {
  NativeGoogleAuthService({GoogleSignIn? signIn})
    : _signIn = signIn ?? GoogleSignIn.instance;

  final GoogleSignIn _signIn;
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
      throw const AuthException(
        'Google sign-in is not configured in this build.',
      );
    }
    if (Platform.isIOS && iosClientId.isEmpty) {
      throw const AuthException(
        'Google sign-in is not configured for iOS in this build.',
      );
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
        throw const AuthException('Google did not return an identity token.');
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
      switch (error.code) {
        case GoogleSignInExceptionCode.canceled:
          throw const AuthException('Google sign-in was cancelled.');
        case GoogleSignInExceptionCode.clientConfigurationError:
        case GoogleSignInExceptionCode.providerConfigurationError:
          throw const AuthException(
            'Google sign-in configuration is unavailable. Try again later.',
          );
        case GoogleSignInExceptionCode.interrupted:
          throw const AuthException(
            'Google sign-in was interrupted. Try again.',
          );
        case GoogleSignInExceptionCode.uiUnavailable:
          throw const AuthException(
            'Google sign-in could not open on this device.',
          );
        case GoogleSignInExceptionCode.userMismatch:
          throw const AuthException(
            'The selected Google account changed. Try again.',
          );
        case GoogleSignInExceptionCode.unknownError:
          throw const AuthException(
            'Google sign-in could not be completed. Try again.',
          );
      }
    }
  }
}
