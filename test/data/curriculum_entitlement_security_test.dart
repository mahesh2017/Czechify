import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final migration = File(
    'supabase/migrations/20260825120000_add_curriculum_entitlements.sql',
  );

  test('entitlements are readable by their owner but client-writes are denied', () {
    expect(migration.existsSync(), isTrue);
    final sql = migration.readAsStringSync().toLowerCase();

    expect(sql, contains('enable row level security'));
    expect(sql, contains('(select auth.uid()) = user_id'));
    expect(
      sql,
      contains(
        'revoke all on table public.curriculum_entitlements from public, anon, authenticated',
      ),
    );
    expect(
      sql,
      contains(
        'grant select on table public.curriculum_entitlements to authenticated',
      ),
    );
    expect(
      sql,
      isNot(
        contains(
          'grant select, insert, update, delete on table public.curriculum_entitlements\n  to authenticated',
        ),
      ),
    );
  });
}
