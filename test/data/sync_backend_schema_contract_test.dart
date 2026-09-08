import 'dart:io';

import 'package:czechify/data/sync/sync_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every synced entity has to satisfy the one writer that pushes it.
///
/// `SupabaseSyncBackend.send` is generic: whatever the entity, it stamps
/// `device_id` and `updated_at` onto the record and upserts it on the entity's
/// conflict key. That makes two demands of the backend table — the two columns
/// must exist, and `on conflict do update` needs UPDATE privilege — and
/// neither is visible from the Dart side.
///
/// `tutor_reply_reports` shipped with neither. Every push was rejected,
/// retried, and eventually dead-lettered, while the sheet told the learner
/// their report had been received. Nothing failed: not the analyzer, not the
/// 1,045 tests, not the local write the tests actually exercised. The mismatch
/// only exists between two files that never mention each other, which is
/// exactly what this test is for.
void main() {
  final sql = _migrationSql();

  group('backend schema matches what the sync backend pushes', () {
    for (final entity in SyncService.conflictKeys.keys) {
      test('$entity accepts a generic upsert', () {
        final columns = _columnsOf(entity, sql);
        expect(
          columns,
          isNotEmpty,
          reason:
              'No `create table public.$entity` found in supabase/migrations. '
              'A synced entity without a migration cannot have been verified.',
        );
        for (final required in const ['user_id', 'device_id', 'updated_at']) {
          expect(
            columns,
            contains(required),
            reason:
                '`$entity` has no `$required` column, but every push through '
                'SupabaseSyncBackend.send sets it. PostgREST rejects the row '
                'and the outbox retries in silence.',
          );
        }
        expect(
          _grantsUpdateToAuthenticated(entity, sql),
          isTrue,
          reason:
              '`$entity` does not grant UPDATE to authenticated. The push is '
              'an upsert, and `on conflict do update` needs it even when the '
              'row is new.',
        );
      });

      test('$entity is covered by the conflict key it is pushed on', () {
        final columns = _columnsOf(entity, sql);
        for (final key in SyncService.conflictKeys[entity]!.split(',')) {
          expect(
            columns,
            contains(key.trim()),
            reason:
                '`$entity` is upserted on `${SyncService.conflictKeys[entity]}`'
                ', but has no `${key.trim()}` column.',
          );
        }
      });
    }
  });
}

/// All migration SQL, in the order Postgres would apply it, comments stripped.
String _migrationSql() {
  final files =
      Directory('supabase/migrations')
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.sql'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  if (files.isEmpty) {
    throw StateError('No migrations found — run this from the repo root.');
  }
  final stripped = files
      .map((file) => file.readAsStringSync())
      .join('\n')
      .split('\n')
      .map((line) {
        final comment = line.indexOf('--');
        return comment == -1 ? line : line.substring(0, comment);
      })
      .join('\n');
  return stripped.toLowerCase();
}

/// Column names `public.[entity]` ends up with, from its `create table` block
/// plus any later `alter table ... add column`.
Set<String> _columnsOf(String entity, String sql) {
  final columns = <String>{};
  final create = RegExp(
    r'create\s+table\s+(?:if\s+not\s+exists\s+)?public\.' + entity + r'\s*\(',
  ).firstMatch(sql);
  if (create == null) return columns;

  // Balance parentheses so nested `check (...)` constraints do not end the
  // block early.
  var depth = 1;
  var index = create.end;
  while (index < sql.length && depth > 0) {
    if (sql[index] == '(') depth++;
    if (sql[index] == ')') depth--;
    index++;
  }
  for (final line in sql.substring(create.end, index - 1).split(',\n')) {
    final name = RegExp(r'^\s*([a-z_]+)\s').firstMatch(line)?.group(1);
    // Table-level constraints are not columns.
    if (name == null ||
        const {
          'primary',
          'constraint',
          'unique',
          'foreign',
          'check',
        }.contains(name)) {
      continue;
    }
    columns.add(name);
  }

  for (final alter in RegExp(
    r'alter\s+table\s+(?:only\s+)?public\.' + entity + r'\b([^;]*);',
  ).allMatches(sql)) {
    for (final added in RegExp(
      r'add\s+column\s+(?:if\s+not\s+exists\s+)?([a-z_]+)',
    ).allMatches(alter.group(1)!)) {
      columns.add(added.group(1)!);
    }
  }
  return columns;
}

/// Whether `authenticated` still holds UPDATE after every grant and revoke.
bool _grantsUpdateToAuthenticated(String entity, String sql) {
  var granted = false;
  final statements = RegExp(
    r'(grant|revoke)\s+([a-z,\s()_]*?)\s+on\s+table\s+public\.'
    '$entity'
    r'\s+(?:to|from)\s+([^;]*);',
  );
  for (final match in statements.allMatches(sql)) {
    final privileges = match.group(2)!;
    final roles = match.group(3)!;
    if (!roles.contains('authenticated')) continue;
    final touchesUpdate =
        privileges.contains('update') || privileges.contains('all');
    if (!touchesUpdate) continue;
    granted = match.group(1) == 'grant';
  }
  return granted;
}
