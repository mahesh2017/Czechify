import 'package:czechify/core/theme/app_theme.dart';
import 'package:czechify/data/database/database.dart';
import 'package:czechify/data/monetization/monetization_api.dart';
import 'package:czechify/data/sync/backend_service.dart';
import 'package:czechify/domain/entities/legacy_lesson_record.dart';
import 'package:czechify/presentation/providers/account_providers.dart';
import 'package:czechify/presentation/providers/billing_providers.dart';
import 'package:czechify/presentation/providers/course_admission_providers.dart';
import 'package:czechify/presentation/providers/database_providers.dart';
import 'package:czechify/presentation/providers/legacy_migration_providers.dart';
import 'package:czechify/presentation/providers/referral_providers.dart';
import 'package:czechify/presentation/providers/sync_providers.dart';
import 'package:czechify/presentation/screens/monetization/upgrade_screen.dart';
import 'package:czechify/presentation/widgets/monetization/legacy_migration_card.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

import 'support/localized_app.dart';

/// Learners from before subscriptions are told what they keep before any
/// paywall, and can send this device's record once. The server decides the
/// units; the app only sends lessons from before the cutoff.
class _Backend extends BackendService {
  @override
  String? userId = 'account-a';
}

final _cutoff = DateTime.utc(2026, 11, 1);
final _now = DateTime.now().toUtc();

LegacyMigrationStatus _status({
  bool eligible = true,
  bool windowOpen = true,
  bool graceOver = false,
  List<int> kept = const [1, 2],
  LegacyClaim? claim,
}) => LegacyMigrationStatus(
  cutoffAt: _cutoff,
  graceEndsAt:
      graceOver
          ? _now.subtract(const Duration(days: 1))
          : _now.add(const Duration(days: 20)),
  claimWindowEndsAt: _now.add(const Duration(days: 20)),
  eligible: eligible,
  claimWindowOpen: windowOpen,
  legacyUnitIds: kept,
  claim: claim,
);

const _record = LegacyLessonRecord(
  completedLessonIds: {100, 301},
  attemptedLessonIds: {401},
  unitIds: {1, 3, 4},
);

MonetizationApi _api(
  ApiResponse Function(String route, Map<String, Object?>? body) answer, [
  List<String>? calls,
]) =>
    MonetizationApi((route, {required method, body, headers = const {}}) async {
      calls?.add('$method $route ${body ?? ''}');
      return answer(route, body);
    });

void main() {
  group('API', () {
    test('reads an applied migration', () async {
      final status =
          await _api(
            (_, _) => const ApiResponse(200, {
              'available': true,
              'cutoff_at': '2026-11-01T00:00:00+00:00',
              'grace_ends_at': '2026-12-01T00:00:00+00:00',
              'claim_window_ends_at': '2026-12-01T00:00:00+00:00',
              'eligible': true,
              'claim_window_open': true,
              'legacy_unit_ids': [1, 2, 'x'],
              'claim': {
                'status': 'needs_review',
                'unit_ids': [3, 4],
              },
            }),
          ).fetchLegacyStatus();
      expect(status!.cutoffAt, _cutoff);
      expect(status.graceEndsAt, DateTime.utc(2026, 12, 1));
      expect(status.legacyUnitIds, [1, 2]);
      expect(status.claim!.status, 'needs_review');
      expect(status.claim!.unitIds, [3, 4]);
      expect(status.canClaim, isFalse);
    });

    test('no migration, an old server or a broken answer is none', () async {
      for (final response in [
        const ApiResponse(200, {'available': false}),
        const ApiResponse(404, {'code': 'not_found'}),
        const ApiResponse(200, {'available': true, 'cutoff_at': 'soon'}),
      ]) {
        expect(await _api((_, _) => response).fetchLegacyStatus(), isNull);
      }
      final throwing = MonetizationApi(
        (route, {required method, body, headers = const {}}) =>
            throw Exception('offline'),
      );
      expect(await throwing.fetchLegacyStatus(), isNull);
    });

    test(
      'a claim sends only lesson IDs and returns the server answer',
      () async {
        final calls = <String>[];
        final claim = await _api(
          (_, _) => const ApiResponse(200, {
            'status': 'applied',
            'unit_ids': [3],
          }),
          calls,
        ).submitLegacyClaim(
          completedLessonIds: [100],
          attemptedLessonIds: [401],
        );
        expect(claim.status, 'applied');
        expect(claim.unitIds, [3]);
        expect(calls, [
          'POST legacy/claim {completed_lesson_ids: [100], '
              'attempted_lesson_ids: [401]}',
        ]);
      },
    );

    test('a refusal carries its code', () async {
      final api = _api(
        (_, _) => const ApiResponse(409, {'code': 'already_claimed'}),
      );
      await expectLater(
        api.submitLegacyClaim(completedLessonIds: [], attemptedLessonIds: []),
        throwsA(
          isA<LegacyClaimException>()
              .having((e) => e.code, 'code', 'already_claimed')
              .having((e) => '$e', 'text', contains('already_claimed')),
        ),
      );
      expect(LegacyClaim.parse('nope'), isNull);
      expect(LegacyClaim.parse({'unit_ids': []}), isNull);
    });
  });

  group('local record', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
    tearDown(() => db.close());

    Future<void> attempt(int lesson, int unit, DateTime committed) => db
        .into(db.lessonAttempts)
        .insert(
          LessonAttemptsCompanion.insert(
            attemptId: 'a$lesson-${committed.millisecondsSinceEpoch}',
            lessonId: lesson,
            unitId: unit,
            phase: 'initial',
            score: 1,
            correctCount: 1,
            incorrectCount: 0,
            skippedCount: 0,
            startedAt: committed,
            committedAt: committed,
          ),
        );
    Future<void> progress(int lesson, int unit, bool done, DateTime? last) => db
        .into(db.lessonProgress)
        .insertOnConflictUpdate(
          LessonProgressCompanion.insert(
            lessonId: Value(lesson),
            unitId: unit,
            isCompleted: Value(done),
            lastAttempted: Value(last),
          ),
        );

    test('only lessons from before the cutoff count', () async {
      final before = _cutoff.subtract(const Duration(days: 3));
      final after = _cutoff.add(const Duration(days: 3));
      await attempt(100, 1, before);
      await attempt(201, 2, before);
      // Learned during grace: never part of a legacy claim.
      await attempt(301, 3, after);
      await progress(301, 3, true, after);
      // An older device recorded progress but no attempts.
      await progress(101, 1, true, before);
      // Started before the cutoff, never finished.
      await progress(401, 4, false, before);
      // A default row with no evidence.
      await progress(501, 5, false, null);
      // Completed before and practised again after: the attempt still counts.
      await progress(201, 2, true, after);

      final record = await db.progressDao.legacyLessonRecord(_cutoff);
      expect(record.completedLessonIds, {100, 101, 201});
      expect(record.attemptedLessonIds, {401});
      expect(record.unitIds, {1, 2, 4});
      expect(record.isEmpty, isFalse);
    });

    test('a completed lesson is not also sent as attempted', () async {
      final before = _cutoff.subtract(const Duration(days: 1));
      await attempt(100, 1, before);
      await progress(100, 1, false, before);
      final record = await db.progressDao.legacyLessonRecord(_cutoff);
      expect(record.completedLessonIds, {100});
      expect(record.attemptedLessonIds, isEmpty);
    });

    test('a fresh install has nothing to claim', () async {
      final record = await db.progressDao.legacyLessonRecord(_cutoff);
      expect(record.isEmpty, isTrue);
    });
  });

  test('a record adds units only beyond those already kept', () {
    expect(_record.addsTo([1, 3, 4]), isFalse);
    expect(_record.addsTo([1, 2]), isTrue);
  });

  group('providers', () {
    late AppDatabase db;
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });
    tearDown(() => db.close());

    ProviderContainer container({
      bool paywall = true,
      MonetizationApi? api,
      _Backend? backend,
    }) {
      final c = ProviderContainer(
        overrides: [
          backendInitProvider.overrideWith((_) async {}),
          accountUserProvider.overrideWith((_) => Stream<User?>.value(null)),
          coursePaywallEnabledProvider.overrideWith((_) async => paywall),
          monetizationApiProvider.overrideWithValue(api),
          databaseProvider.overrideWithValue(db),
          backendServiceProvider.overrideWithValue(backend ?? _Backend()),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    ApiResponse statusResponse({Map<String, Object?>? claim}) =>
        ApiResponse(200, {
          'available': true,
          'cutoff_at': _cutoff.toIso8601String(),
          'grace_ends_at': _now.add(const Duration(days: 20)).toIso8601String(),
          'claim_window_ends_at':
              _now.add(const Duration(days: 20)).toIso8601String(),
          'eligible': true,
          'claim_window_open': true,
          'legacy_unit_ids': [1],
          'claim': claim,
        });

    Future<void> seedBeforeCutoff() => db
        .into(db.lessonProgress)
        .insert(
          LessonProgressCompanion.insert(
            lessonId: const Value(201),
            unitId: 2,
            isCompleted: const Value(true),
            lastAttempted: Value(_cutoff.subtract(const Duration(days: 2))),
          ),
        );

    test('nothing is asked while the paywall is off', () async {
      final calls = <String>[];
      final c = container(
        paywall: false,
        api: _api((_, _) => statusResponse(), calls),
      );
      expect(await c.read(legacyMigrationStatusProvider.future), isNull);
      expect(calls, isEmpty);
    });

    test('without a backend there is nothing to explain', () async {
      final c = container();
      expect(await c.read(legacyMigrationStatusProvider.future), isNull);
      expect(await c.read(legacyLessonRecordProvider.future), isNull);
    });

    test('a record is offered only when it would add units', () async {
      final c = container(api: _api((_, _) => statusResponse()));
      final sub = c.listen(legacyLessonRecordProvider.future, (_, _) {});
      addTearDown(sub.close);
      expect(await sub.read(), isNull, reason: 'no lessons before the cutoff');
      await seedBeforeCutoff();
      c.invalidate(legacyLessonRecordProvider);
      expect((await c.read(legacyLessonRecordProvider.future))!.unitIds, {2});
    });

    test('an account that already claimed is not offered again', () async {
      await seedBeforeCutoff();
      final c = container(
        api: _api(
          (_, _) =>
              statusResponse(claim: {'status': 'applied', 'unit_ids': []}),
        ),
      );
      expect(await c.read(legacyLessonRecordProvider.future), isNull);
    });

    test(
      'a claim sends the record and refreshes what the account keeps',
      () async {
        await seedBeforeCutoff();
        final calls = <String>[];
        var claimed = false;
        final c = container(
          api: _api((route, _) {
            if (route == 'legacy/claim') {
              claimed = true;
              return const ApiResponse(200, {
                'status': 'applied',
                'unit_ids': [2],
              });
            }
            return statusResponse(
              claim:
                  claimed
                      ? {
                        'status': 'applied',
                        'unit_ids': [2],
                      }
                      : null,
            );
          }, calls),
        );
        final sub = c.listen(legacyLessonRecordProvider.future, (_, _) {});
        addTearDown(sub.close);
        await sub.read();
        final claim = await c.read(legacyClaimProvider)();
        expect(claim.unitIds, [2]);
        expect(
          calls,
          contains(
            'POST legacy/claim {completed_lesson_ids: [201], '
            'attempted_lesson_ids: []}',
          ),
        );
        expect(
          (await c.read(legacyMigrationStatusProvider.future))!.claim!.status,
          'applied',
        );
      },
    );

    test('an answer for an account that left is not shown', () async {
      await seedBeforeCutoff();
      final backend = _Backend();
      final c = container(
        backend: backend,
        api: _api((route, _) {
          if (route == 'legacy/claim') backend.userId = 'account-b';
          return route == 'legacy/claim'
              ? const ApiResponse(200, {'status': 'applied', 'unit_ids': []})
              : statusResponse();
        }),
      );
      final sub = c.listen(legacyLessonRecordProvider.future, (_, _) {});
      addTearDown(sub.close);
      await sub.read();
      await expectLater(
        c.read(legacyClaimProvider)(),
        throwsA(isA<LegacyClaimException>()),
      );
    });

    test('nothing to send is refused locally', () async {
      final c = container(api: _api((_, _) => statusResponse()));
      await expectLater(
        c.read(legacyClaimProvider)(),
        throwsA(isA<LegacyClaimException>()),
      );
    });

    test('putting the notice away is remembered per account', () async {
      final backend = _Backend();
      final c = container(backend: backend);
      expect(await c.read(legacyNoticeDismissedProvider.future), isFalse);
      await c.read(dismissLegacyNoticeProvider)();
      expect(await c.read(legacyNoticeDismissedProvider.future), isTrue);
      backend.userId = 'account-b';
      c.invalidate(legacyNoticeDismissedProvider);
      expect(await c.read(legacyNoticeDismissedProvider.future), isFalse);
      backend.userId = null;
      c.invalidate(legacyNoticeDismissedProvider);
      expect(await c.read(legacyNoticeDismissedProvider.future), isFalse);
      await c.read(dismissLegacyNoticeProvider)();
    });
  });

  group('card', () {
    Future<List<String>> pump(
      WidgetTester tester, {
      LegacyMigrationStatus? status,
      LegacyLessonRecord? record,
      bool dismissible = false,
      bool dismissed = false,
      Future<LegacyClaim> Function()? claim,
      Widget? home,
    }) async {
      final events = <String>[];
      tester.view.physicalSize = const Size(400, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          // A fresh scope and card state on every pump.
          key: UniqueKey(),
          overrides: [
            legacyMigrationStatusProvider.overrideWith((_) async => status),
            legacyLessonRecordProvider.overrideWith((_) async => record),
            legacyNoticeDismissedProvider.overrideWith((_) async => dismissed),
            dismissLegacyNoticeProvider.overrideWithValue(
              () async => events.add('dismissed'),
            ),
            legacyClaimProvider.overrideWithValue(
              claim ?? () async => const LegacyClaim('applied', [3, 4]),
            ),
            referralsEnabledProvider.overrideWith((_) async => false),
          ],
          child: MaterialApp(
            theme: lightTheme(),
            localizationsDelegates: testLocalizationsDelegates,
            supportedLocales: testSupportedLocales,
            home:
                home ??
                Scaffold(
                  body: ListView(
                    children: [LegacyMigrationCard(dismissible: dismissible)],
                  ),
                ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return events;
    }

    testWidgets('the upgrade screen explains grace and kept units first', (
      tester,
    ) async {
      await pump(tester, status: _status(), home: const UpgradeScreen());
      expect(find.text('You were here before subscriptions'), findsOneWidget);
      expect(
        find.textContaining('the whole course stays open until'),
        findsOneWidget,
      );
      expect(find.textContaining('Nov 1, 2026'), findsOneWidget);
      expect(
        find.text("The units you'd reached stay yours for good: 1, 2."),
        findsOneWidget,
      );
      expect(find.text('Got it'), findsNothing);
      expect(find.text('Subscribe to Czechify Core'), findsOneWidget);
    });

    testWidgets('nothing shows for newer accounts or without a migration', (
      tester,
    ) async {
      await pump(tester, status: _status(eligible: false));
      expect(find.text('You were here before subscriptions'), findsNothing);
      await pump(tester);
      expect(find.text('You were here before subscriptions'), findsNothing);
    });

    testWidgets('after grace the paywall still says what stays', (
      tester,
    ) async {
      await pump(tester, status: _status(graceOver: true, kept: const []));
      expect(find.textContaining('access ended on'), findsOneWidget);
      expect(find.textContaining('units 1 and 2 stay free'), findsOneWidget);
    });

    testWidgets('on Home it can be put away and ends with grace', (
      tester,
    ) async {
      final events = await pump(tester, status: _status(), dismissible: true);
      await tester.tap(find.text('Got it'));
      expect(events, ['dismissed']);
      await pump(tester, status: _status(), dismissible: true, dismissed: true);
      expect(find.text('You were here before subscriptions'), findsNothing);
      await pump(tester, status: _status(graceOver: true), dismissible: true);
      expect(find.text('You were here before subscriptions'), findsNothing);
    });

    testWidgets('sending the record shows the units it added', (tester) async {
      await pump(tester, status: _status(), record: _record);
      expect(
        find.textContaining('Each account can do this once'),
        findsOneWidget,
      );
      await tester.tap(find.text("Send this phone's record"));
      await tester.pumpAndSettle();
      expect(
        find.text('Done. These units are yours for good: 3, 4.'),
        findsOneWidget,
      );
      expect(find.text("Send this phone's record"), findsNothing);
    });

    testWidgets('each answer is explained', (tester) async {
      final answers = <Future<LegacyClaim> Function(), String>{
        () async => const LegacyClaim('applied', []):
            'Done. You already keep every unit',
        () async => const LegacyClaim('needs_review', [3, 4, 5, 6]):
            'Support will check this record',
        () async => const LegacyClaim('rejected', []):
            'has no lessons from before',
        () async => throw const LegacyClaimException('already_claimed'):
            'already sent its record',
        () async => throw const LegacyClaimException('claim_window_closed'):
            'The time to send a record has ended',
      };
      for (final MapEntry(key: claim, value: text) in answers.entries) {
        await pump(tester, status: _status(), record: _record, claim: claim);
        await tester.tap(find.text("Send this phone's record"));
        await tester.pumpAndSettle();
        expect(find.textContaining(text), findsOneWidget, reason: text);
      }
    });

    testWidgets('a failed send leaves the button for another try', (
      tester,
    ) async {
      for (final failure in [
        const LegacyClaimException('verification_unavailable'),
        Exception('offline'),
      ]) {
        await pump(
          tester,
          status: _status(),
          record: _record,
          claim: () async => throw failure,
        );
        await tester.tap(find.text("Send this phone's record"));
        await tester.pumpAndSettle();
        expect(
          find.text("Couldn't reach Czechify. Try again."),
          findsOneWidget,
        );
        expect(find.text("Send this phone's record"), findsOneWidget);
        await tester.pump(const Duration(seconds: 5));
      }
    });

    testWidgets('a claim waiting for support says so on every visit', (
      tester,
    ) async {
      await pump(
        tester,
        status: _status(claim: const LegacyClaim('needs_review', [3, 4, 5, 6])),
      );
      expect(find.textContaining('Support will check'), findsOneWidget);
    });
  });
}
