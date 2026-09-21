import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:czechify/data/database/database.dart';
import 'package:czechify/data/monetization/monetization_repository.dart';
import 'package:czechify/data/monetization/snapshot_verifier.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final vector =
      jsonDecode(
            File(
              'test/fixtures/monetization/signed_snapshot.v1.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  final account = vector['payload']['user_id'] as String;
  final jws = vector['jws'] as String;
  final publicKey = base64Url.decode(
    base64Url.normalize(vector['public_key']['x'] as String),
  );
  final verifier = SnapshotVerifier({'test-only': publicKey});
  final date = DateTime.utc(2026, 9, 21, 12);

  test(
    'JOSE-signed vector verifies with Dart Ed25519 and exact schema',
    () async {
      final result = await verifier.verify(jws, accountId: account);
      expect(result.snapshot.revision, 7);
      expect(result.snapshot.permanentGrants.single.unitId, 3);
      expect(result.snapshot.core.isActiveAt(date, offline: true), isTrue);
      expect(result.staff.unlockAll, isFalse);
    },
  );
  test(
    'tampering, wrong account/key/header and malformed tokens are rejected',
    () async {
      final parts = jws.split('.');
      parts[1] = base64Url
          .encode(utf8.encode('{"user_id":"other"}'))
          .replaceAll('=', '');
      for (final bad in ['', parts.join('.'), 'a.b.c', '$jws.extra']) {
        await expectLater(
          verifier.verify(bad, accountId: account),
          throwsFormatException,
        );
      }
      await expectLater(
        verifier.verify(jws, accountId: 'other'),
        throwsFormatException,
      );
      await expectLater(
        SnapshotVerifier({}).verify(jws, accountId: account),
        throwsFormatException,
      );
      expect(
        () => SnapshotVerifier({
          'bad': [1, 2],
        }),
        throwsArgumentError,
      );
    },
  );
  test(
    'valid signatures still reject unknown schemas and invalid feature bounds',
    () async {
      final pair = await Ed25519().newKeyPair();
      final key = await pair.extractPublicKey();
      final v = SnapshotVerifier({'test': key.bytes});
      Future<String> sign(Map<String, dynamic> body) async {
        String segment(Object value) => base64Url
            .encode(utf8.encode(jsonEncode(value)))
            .replaceAll('=', '');
        final text =
            '${segment({'alg': 'EdDSA', 'typ': 'czechify-entitlements+jws', 'kid': 'test'})}.${segment(body)}';
        final sig = await Ed25519().sign(ascii.encode(text), keyPair: pair);
        return '$text.${base64Url.encode(sig.bytes).replaceAll('=', '')}';
      }

      final original = vector['payload'] as Map<String, dynamic>;
      for (final replacement in [
        {'schema_version': 2},
        {'revision': -1},
        {'manifest_revision': 99},
        {'verified_at': '2026-10-01T00:00:00Z'},
        {'staff_course_unlimited': 'true'},
        {
          'features': {
            'core': {
              'state': 'active',
              'valid_until': null,
              'offline_valid_until': null,
            },
            'ai_chat': original['features']['ai_chat'],
          },
        },
        {
          'permanent_unit_grants': [
            {'grant_id': 'bad', 'unit_id': 16, 'source': 'referral'},
          ],
        },
      ]) {
        await expectLater(
          v.verify(
            await sign({...original, ...replacement}),
            accountId: account,
          ),
          throwsFormatException,
        );
      }
    },
  );

  group('account-scoped cache', () {
    late AppDatabase db;
    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });
    tearDown(() => db.close());
    test(
      'network loss preserves verified grants and bounded subscription document',
      () async {
        var online = true;
        final repo = MonetizationRepository(
          database: db,
          verifier: verifier,
          wallNow: () => date,
          fetch: (_) async {
            if (!online) throw const FormatException('offline');
            return jws;
          },
        )..setAccount(account);
        addTearDown(repo.dispose);
        expect((await repo.load()).offline, isFalse);
        online = false;
        final offline = await repo.load();
        expect(offline.offline, isTrue);
        expect(offline.document?.snapshot.permanentGrants.single.unitId, 3);
        repo.setAccount('other');
        expect((await repo.load()).document, isNull);
      },
    );
    test(
      'account transition rejects a late reply and prevents cache resurrection',
      () async {
        final reply = Completer<String>();
        final requested = Completer<void>();
        final repo = MonetizationRepository(
          database: db,
          verifier: verifier,
          fetch: (_) {
            requested.complete();
            return reply.future;
          },
        )..setAccount(account);
        addTearDown(repo.dispose);
        final pending = repo.load();
        final rejected = expectLater(pending, throwsStateError);
        await requested.future;
        repo.suspend();
        repo.setAccount(account); // Auth event while switching must be ignored.
        await db.clearLearnerData();
        reply.complete(jws);
        await rejected;
        expect(await db.select(db.monetizationSnapshots).get(), isEmpty);
        expect((await repo.load()).document, isNull);
      },
    );
    test(
      'clock rollback after restart requires reverification and remains sticky',
      () async {
        final writer = MonetizationRepository(
          database: db,
          verifier: verifier,
          fetch: (_) async => jws,
          wallNow: () => date,
        )..setAccount(account);
        await writer.load();
        writer.dispose();
        final reader = MonetizationRepository(
          database: db,
          verifier: verifier,
          fetch: (_) async => throw const FormatException('offline'),
          wallNow: () => date.subtract(const Duration(days: 2)),
        )..setAccount(account);
        addTearDown(reader.dispose);
        expect((await reader.load()).requiresReverification, isTrue);
        expect((await reader.load()).requiresReverification, isTrue);
        await db.clearLearnerData();
        expect(await db.select(db.monetizationSnapshots).get(), isEmpty);
      },
    );
    test(
      'replayed server document cannot restart the paid offline clock',
      () async {
        final first = MonetizationRepository(
          database: db,
          verifier: verifier,
          fetch: (_) async => jws,
          wallNow: () => date,
        )..setAccount(account);
        await first.load();
        first.dispose();
        final later = MonetizationRepository(
          database: db,
          verifier: verifier,
          fetch: (_) async => jws,
          wallNow: () => date.add(const Duration(days: 8)),
        )..setAccount(account);
        addTearDown(later.dispose);
        final replay = await later.load();
        expect(replay.offline, isTrue);
        expect(
          replay.document!.snapshot.core.isActiveAt(replay.now, offline: true),
          isFalse,
        );
      },
    );

    test('simultaneous callers share one request', () async {
      var requests = 0;
      final repo = MonetizationRepository(
        database: db,
        verifier: verifier,
        fetch: (_) async {
          requests++;
          return jws;
        },
      )..setAccount(account);
      addTearDown(repo.dispose);
      await Future.wait([repo.load(), repo.load()]);
      expect(requests, 1);
    });
  });
}
