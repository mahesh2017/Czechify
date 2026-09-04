import 'package:czechify/data/account/account_identity.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('detects a linked provider from identities', () {
    final user = User.fromJson({
      'id': 'learner',
      'aud': 'authenticated',
      'created_at': '2026-08-25T00:00:00Z',
      'app_metadata': <String, Object?>{},
      'user_metadata': <String, Object?>{},
      'identities': [
        {
          'id': 'google-id',
          'user_id': 'learner',
          'identity_data': <String, Object?>{},
          'provider': 'google',
          'created_at': '2026-08-25T00:00:00Z',
          'updated_at': '2026-08-25T00:00:00Z',
        },
      ],
    });

    expect(userHasIdentityProvider(user, 'google'), isTrue);
  });

  test('detects a freshly linked provider from app metadata', () {
    final user = User.fromJson({
      'id': 'learner',
      'aud': 'authenticated',
      'created_at': '2026-08-25T00:00:00Z',
      'app_metadata': {
        'provider': 'email',
        'providers': ['email', 'google'],
      },
      'user_metadata': <String, Object?>{},
      'identities': <Object?>[],
    });

    expect(userHasIdentityProvider(user, 'google'), isTrue);
  });

  test('does not infer an unlinked provider', () {
    final user = User.fromJson({
      'id': 'learner',
      'aud': 'authenticated',
      'created_at': '2026-08-25T00:00:00Z',
      'app_metadata': {
        'provider': 'email',
        'providers': ['email'],
      },
      'user_metadata': <String, Object?>{},
    });

    expect(userHasIdentityProvider(user, 'google'), isFalse);
  });
}
