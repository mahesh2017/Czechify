import 'package:supabase_flutter/supabase_flutter.dart';

/// Returns whether [user] is connected to [provider].
///
/// Supabase normally returns linked identities in [User.identities], but a
/// freshly linked session can expose the provider in app metadata before that
/// list is populated. Checking both representations keeps account controls in
/// sync with the server-confirmed link.
bool userHasIdentityProvider(User? user, String provider) {
  if (user == null) return false;
  if (user.identities?.any((identity) => identity.provider == provider) ==
      true) {
    return true;
  }

  final providers = user.appMetadata['providers'];
  if (providers is Iterable) {
    return providers.any((value) => value == provider);
  }
  return user.appMetadata['provider'] == provider;
}
