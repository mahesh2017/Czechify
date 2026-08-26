import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the account-isolation invariants around native Google Sign-In.
///
/// These span the native token provider, Supabase session handling, and the
/// local snapshot transition, so a source-level contract is more useful than a
/// mock that could accidentally bypass the production wiring.
void main() {
  final backend = File('lib/data/sync/backend_service.dart');
  final account = File('lib/data/account/account_service.dart');
  final googleAuth = File('lib/data/account/google_auth_service.dart');

  test('native Google authorization requests required identity scopes', () {
    final source = googleAuth.readAsStringSync();
    expect(source, contains("'openid'"));
    expect(source, contains('userinfo.email'));
    expect(source, contains('userinfo.profile'));
    expect(source, isNot(contains('authorizeScopes(const <String>[])')));
  });

  test('Google credentials are validated on an isolated Supabase client', () {
    final source = backend.readAsStringSync();
    final method = _method(source, 'Future<Session> authenticateGoogle');
    expect(method, contains('final temporary = SupabaseClient('));
    expect(method, contains('temporary.auth.signInWithIdToken('));
    expect(method, contains('await temporary.dispose()'));
  });

  test('linking verifies that the active Supabase user id did not change', () {
    final source = backend.readAsStringSync();
    final method = _method(source, 'Future<void> linkGoogleIdentity');
    expect(method, contains('final before ='));
    expect(method, contains('response.user?.id != before'));
  });

  test(
    'returning Google users use the guarded account snapshot transition',
    () {
      final source = account.readAsStringSync();
      final completion = _method(
        source,
        'Future<void> completeGoogleSwitch',
        expressionBody: true,
      );
      expect(completion, contains('_switchToSession(pending._session)'));
      final transition = _method(source, 'Future<void> _switchToSession');
      expect(transition, contains('beginAccountTransition()'));
      expect(transition, contains('downloadAccountSnapshot()'));
      expect(transition, contains('clearLearnerDataRows'));
      expect(transition, contains('installAccountSnapshot(snapshot)'));
    },
  );
}

String _method(String source, String signature, {bool expressionBody = false}) {
  final start = source.indexOf(signature);
  if (start < 0) fail('Could not find $signature');
  if (expressionBody) {
    final end = source.indexOf(';', start);
    if (end < 0) fail('Could not find end of $signature');
    return source.substring(start, end + 1);
  }
  final nextMethod = source.indexOf('\n  Future<', start + signature.length);
  return source.substring(start, nextMethod < 0 ? source.length : nextMethod);
}
