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

  test('the database snapshot covers exactly the declared export tables', () {
    // The latest migration that defines the export is the one in force.
    final definitions =
        Directory('supabase/migrations')
            .listSync()
            .whereType<File>()
            .where(
              (file) => file.readAsStringSync().contains(
                'function public.export_account_snapshot(',
              ),
            )
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));
    // Only the export's own body: the same migration may define others.
    final file = definitions.last.readAsStringSync();
    final start = file.indexOf('function public.export_account_snapshot(');
    final sql = file.substring(start, file.indexOf(r'$$;', start));
    final selected =
        RegExp(
          r"'([a-z_]+)', \(select",
        ).allMatches(sql).map((match) => match.group(1)!).toSet();
    final source = policy.readAsStringSync();
    expect(selected, {
      ..._exportList(source, 'syncedUserTables'),
      ..._exportList(source, 'serverOwnedExportKeys'),
    });
  });

  test('push-only entities are still exported', () {
    // A report travels up and never comes back — nothing in the app displays
    // one. That is a sync decision, not an export one: the rows are still the
    // learner's, and a subject-access request has to see them.
    for (final entity in SyncService.pushOnlyEntities) {
      expect(
        SyncService.conflictKeys.keys,
        contains(entity),
        reason: 'a push-only entity still pushes, so it needs a conflict key',
      );
    }
  });
}

/// Extracts the string literals from the `syncedUserTables` array.
Set<String> _syncedUserTables(String source) =>
    _exportList(source, 'syncedUserTables');

/// Extracts the string literals from the named exported array.
Set<String> _exportList(String source, String name) {
  final block = RegExp(
    'export const $name\\s*=\\s*\\[(.*?)\\]',
    dotAll: true,
  ).firstMatch(source);
  if (block == null) {
    fail('could not find $name in account_policy.ts');
  }
  return RegExp(
    r'"([a-z_]+)"',
  ).allMatches(block.group(1)!).map((match) => match.group(1)!).toSet();
}
