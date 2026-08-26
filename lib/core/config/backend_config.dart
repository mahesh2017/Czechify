/// Backend (Supabase) configuration.
///
/// Backend selection is explicit: source builds never default to production.
/// The publishable key is safe to ship in the client, but accidentally targeting
/// production from development still creates users, writes sync data, and can
/// consume paid AI quota.
///
/// For staging or local projects, override them at build time:
///   flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
///
/// Setting either value to an empty string disables the backend.
class BackendConfig {
  const BackendConfig._();

  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  /// True once a project URL + anon key are supplied.
  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}

/// Public OAuth client identifiers used by native Google Sign-In.
///
/// These identifiers are not secrets, but keeping them in release-time config
/// avoids coupling source builds to one Google Cloud project. Android needs the
/// Web client ID as its server client ID. iOS additionally needs its native
/// client ID and reversed-client-ID URL scheme (see docs/GOOGLE_SIGN_IN.md).
class GoogleAuthConfig {
  const GoogleAuthConfig._();

  static const String webClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue: '',
  );

  static const String iosClientId = String.fromEnvironment(
    'GOOGLE_IOS_CLIENT_ID',
    defaultValue: '',
  );
}
