import 'dart:io';

import 'package:czechify/data/sync/sync_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// The account export lives in TypeScript and the sync map lives in Dart, so
/// nothing connected them. `custom_cards` was synced for months while the
/// subject-access export silently omitted it — deletion still worked, because
/// the foreign key cascades, which is precisely why nobody noticed.
///
/// This reads the Edge Function's own source so the two cannot drift apart:
/// adding a synced entity without exporting it fails here.
void main() {
  final policy = File('supabase/functions/account-data/account_policy.ts');

  test('the policy source is where this test expects it', () {
    expect(
      policy.existsSync(),
      isTrue,
      reason: 'moving ${policy.path} silently disables this contract check',
    );
  });

  test('every synced entity appears in the account export', () {
    final exported = _syncedUserTables(policy.readAsStringSync());

    // Not equality: the export is a superset. It also carries server-owned
    // rows the client never syncs, such as ai_daily_usage.
    for (final entity in SyncService.conflictKeys.keys) {
      expect(
        exported,
        contains(entity),
        reason:
            '"$entity" is synced to the backend but missing from '
            'syncedUserTables, so a data export would omit it',
      );
    }
  });

  test('the export list parses to something plausible', () {
    // Guards the parser itself: a regex that silently matched nothing would
    // make the test above vacuously pass.
    final exported = _syncedUserTables(policy.readAsStringSync());
    expect(exported, contains('lesson_progress'));
    expect(exported.length, greaterThanOrEqualTo(6));
  });
}

/// Extracts the string literals from the `syncedUserTables` array.
Set<String> _syncedUserTables(String source) {
  final block = RegExp(
    r'export const syncedUserTables\s*=\s*\[(.*?)\]',
    dotAll: true,
  ).firstMatch(source);
  if (block == null) {
    fail('could not find syncedUserTables in account_policy.ts');
  }
  return RegExp(r'"([a-z_]+)"')
      .allMatches(block.group(1)!)
      .map((match) => match.group(1)!)
      .toSet();
}
