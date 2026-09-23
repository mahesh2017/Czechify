import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:czechify/data/account/account_service.dart';
import 'package:czechify/data/database/database.dart';
import 'package:czechify/data/monetization/monetization_repository.dart';
import 'package:czechify/data/monetization/snapshot_verifier.dart';
import 'package:czechify/data/sync/backend_service.dart';
import 'package:czechify/data/sync/device_id.dart';
import 'package:czechify/data/sync/sync_service.dart';
import 'package:czechify/presentation/providers/account_providers.dart';
import 'package:czechify/presentation/providers/database_providers.dart';
import 'package:czechify/presentation/providers/monetization_providers.dart';
import 'package:czechify/presentation/providers/sync_providers.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A backend with no Supabase client: the entitlement service is unreachable,
/// as it is offline or before the backend is configured.
class _Backend extends BackendService {
  _Backend(this.events);
  final List<String> events;
  @override
  String? userId;
  bool failAnonymousSession = false;
  @override
  SupabaseClient? get client => null;
  @override
  Future<void> init() async {}
  @override
  Future<void> ensureAnonymousSession() async {
    if (failAnonymousSession) throw StateError('No network');
    events.add('anonymous session');
  }

  @override
  Future<Session> authenticateExisting({
    required String email,
    required String password,
  }) async => Session(
    accessToken: 'token',
    tokenType: 'bearer',
    user: const User(
      id: 'target-account',
      appMetadata: {},
      userMetadata: {},
      aud: 'authenticated',
      createdAt: '2026-09-21T12:00:00Z',
    ),
  );

  @override
  Future<void> installSession(Session session) async =>
      throw StateError('Session install failed');

  @override
  Future<void> clearLocalSession() async => events.add('cleared session');
}

User _signedIn(String id) => User(
  id: id,
  appMetadata: const {},
  userMetadata: const {},
  aud: 'authenticated',
  createdAt: '2026-09-21T12:00:00Z',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final vector =
      jsonDecode(
            File(
              'test/fixtures/monetization/signed_snapshot.v1.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  final account = vector['payload']['user_id'] as String;
  final jws = vector['jws'] as String;
  final verifier = SnapshotVerifier({
    'test-only': base64Url.decode(
      base64Url.normalize(vector['public_key']['x'] as String),
    ),
  });
  final issued = DateTime.utc(2026, 9, 21, 12);

  late AppDatabase db;
  late List<String> events;
  late _Backend backend;
  late Directory temp;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    events = [];
    backend = _Backend(events)..userId = account;
    temp = Directory.systemTemp.createTempSync('czechify-lifecycle-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => temp.path,
        );
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
    await db.close();
    if (temp.existsSync()) await temp.delete(recursive: true);
  });

  Future<void> seedCache() => db
      .into(db.monetizationSnapshots)
      .insert(
        MonetizationSnapshotsCompanion.insert(
          accountId: account,
          signedPayload: jws,
          revision: 7,
          serverAnchor: issued,
          localAnchor: DateTime.now().toUtc(),
          maximumObservedTime: issued,
        ),
      );

  ProviderContainer container() {
    final c = ProviderContainer(
      overrides: [
        backendServiceProvider.overrideWithValue(backend),
        backendInitProvider.overrideWith((ref) async {}),
        databaseProvider.overrideWithValue(db),
        snapshotVerifierProvider.overrideWithValue(verifier),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  AccountService accountService() => AccountService(
    backend,
    db,
    SyncService(
      db: db,
      backend: SupabaseSyncBackend(
        backend: backend,
        deviceId: DeviceId(const FlutterSecureStorage()),
      ),
    ),
    onAccountTransitionStarted: () => events.add('transition started'),
    onAccountTransitionEnded: () => events.add('transition ended'),
    onLocalDataChanged: () => events.add('local data changed'),
  );

  group('entitlement providers', () {
    test('a sign-in change reloads entitlements for the new session', () async {
      await seedCache();
      final users = StreamController<User?>();
      addTearDown(users.close);
      final c = ProviderContainer(
        overrides: [
          backendServiceProvider.overrideWithValue(backend),
          backendInitProvider.overrideWith((ref) async {}),
          databaseProvider.overrideWithValue(db),
          snapshotVerifierProvider.overrideWithValue(verifier),
          accountUserProvider.overrideWith((ref) => users.stream),
        ],
      );
      addTearDown(c.dispose);
      final loads = <MonetizationLoad>[];
      c.listen(
        monetizationLoadProvider,
        (_, next) => next.whenData(loads.add),
        fireImmediately: true,
      );
      users.add(_signedIn(account));
      await pumpEventQueue();
      expect(loads.last.document?.snapshot.userId, account);

      // Another account signs in: its load must not show the first
      // account's cached access.
      backend.userId = 'account-b';
      users.add(_signedIn('account-b'));
      await pumpEventQueue();
      expect(loads.last.document, isNull);
    });

    test(
      'a lagging account stream cannot restore the previous account',
      () async {
        await seedCache();
        final c = ProviderContainer(
          overrides: [
            backendServiceProvider.overrideWithValue(backend),
            backendInitProvider.overrideWith((ref) async {}),
            databaseProvider.overrideWithValue(db),
            snapshotVerifierProvider.overrideWithValue(verifier),
            // Still reports the previous account throughout.
            accountUserProvider.overrideWith(
              (ref) => Stream.value(_signedIn(account)),
            ),
          ],
        );
        addTearDown(c.dispose);
        // Held open as a screen would: Riverpod pauses an unlistened
        // provider instead of rebuilding it when a dependency changes.
        c.listen(monetizationLoadProvider, (_, _) {});
        final service = c.read(accountServiceProvider);
        expect(
          (await c.read(monetizationLoadProvider.future)).document,
          isNotNull,
        );
        // The session switched, but the account stream has not caught up.
        service.onAccountTransitionStarted!();
        backend.userId = 'account-b';
        service.onAccountTransitionEnded!();
        final after = await c.read(monetizationLoadProvider.future);
        expect(after.document, isNull);
      },
    );

    test('an unconfigured build trusts no signing key', () async {
      await seedCache();
      final c = ProviderContainer(
        overrides: [
          backendServiceProvider.overrideWithValue(backend),
          backendInitProvider.overrideWith((ref) async {}),
          databaseProvider.overrideWithValue(db),
        ],
      );
      addTearDown(c.dispose);
      final load = await c.read(monetizationLoadProvider.future);
      expect(load.document, isNull);
      expect(load.requiresReverification, isTrue);
    });

    test(
      'an unreachable service falls back to the verified cached document',
      () async {
        await seedCache();
        final load = await container().read(monetizationLoadProvider.future);
        expect(load.offline, isTrue);
        expect(load.requiresReverification, isFalse);
        expect(load.document?.snapshot.revision, 7);
        final access = load.courseAccess(account);
        expect(access.canAccessUnit(1), isTrue);
        expect(access.canAccessUnit(3), isTrue);
      },
    );

    test('without an account nothing is loaded from the cache', () async {
      await seedCache();
      backend.userId = null;
      final load = await container().read(monetizationLoadProvider.future);
      expect(load.document, isNull);
    });

    test(
      'the account service suspends entitlements for the whole transition',
      () async {
        await seedCache();
        final c = container();
        final service = c.read(accountServiceProvider);

        service.onAccountTransitionStarted!();
        final during = await c.read(monetizationLoadProvider.future);
        expect(during.accountTransition, isTrue);
        expect(during.document, isNull);

        service.onAccountTransitionEnded!();
        final after = await c.read(monetizationLoadProvider.future);
        expect(after.accountTransition, isFalse);
        expect(after.document?.snapshot.userId, account);
      },
    );
  });

  group('account transitions bracket entitlement access', () {
    test('deleting local data reports start and end around the work', () async {
      backend.userId = null;
      await accountService().deleteAccountAndLocalData();
      expect(events, [
        'transition started',
        'anonymous session',
        'local data changed',
        'transition ended',
      ]);
    });

    test('a failed deletion still ends the transition', () async {
      backend
        ..userId = null
        ..failAnonymousSession = true;
      await expectLater(
        accountService().deleteAccountAndLocalData(),
        throwsStateError,
      );
      expect(events, ['transition started', 'transition ended']);
    });

    test('a failed account switch still ends the transition', () async {
      await expectLater(
        accountService().switchToExistingAccount(
          email: 'learner@example.com',
          password: 'password',
        ),
        throwsStateError,
      );
      expect(events, [
        'transition started',
        'cleared session',
        'transition ended',
      ]);
    });
  });
}
