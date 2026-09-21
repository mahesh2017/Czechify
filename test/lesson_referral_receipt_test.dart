import 'package:czechify/data/referrals/referral_api.dart';
import 'package:czechify/data/monetization/monetization_api.dart';
import 'package:czechify/data/referrals/referral_store.dart';
import 'package:czechify/data/sync/backend_service.dart';
import 'package:czechify/domain/entities/enums.dart';
import 'package:czechify/domain/entities/exercise.dart';
import 'package:czechify/domain/entities/exercise_outcome.dart';
import 'package:czechify/domain/entities/lesson.dart';
import 'package:czechify/domain/entities/referral_receipt.dart';
import 'package:czechify/presentation/providers/database_providers.dart';
import 'package:czechify/presentation/providers/gamification_providers.dart';
import 'package:czechify/presentation/providers/lesson_providers.dart';
import 'package:czechify/presentation/providers/referral_providers.dart';
import 'package:czechify/presentation/providers/sync_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support/lesson_session_harness.dart';

/// Receipts are the player's own record of how each exercise was first met.
/// They must follow the claim held when the attempt began, and never reach a
/// different account.
class _Backend extends BackendService {
  @override
  String? userId = 'account-a';
  @override
  SupabaseClient? get client => null;
}

class _Store implements ReferralStore {
  final Map<String, String> claims;
  _Store(Map<String, String> claims) : claims = Map.of(claims);
  @override
  Future<void> saveClaim(String accountId, String claimId, DateTime at) async {
    claims[accountId] = claimId;
  }

  @override
  Future<String?> activeClaim(String accountId) async => claims[accountId];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Session extends LessonSessionNotifier {
  _Session(this.unitId, {this.examMode = false});
  final int unitId;
  final bool examMode;

  @override
  LessonSessionState build() => LessonSessionState(
    lesson: Lesson(
      id: 100,
      unitId: unitId,
      orderInUnit: 0,
      title: 'Lesson',
      description: '',
    ),
    exercises: const [
      Exercise(
        id: 898,
        lessonId: 100,
        type: ExerciseType.teaching,
        prompt: 'Read this',
        data: {},
        xpReward: 0,
      ),
      Exercise(
        id: 899,
        lessonId: 100,
        type: ExerciseType.multipleChoice,
        prompt: 'Pick one',
        data: {},
      ),
    ],
    originalCount: 2,
    isExamMode: examMode,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<FakeProgressRepository> play({
    int unitId = 1,
    bool examMode = false,
    String? serverClaim,
    Map<String, String> claims = const {'account-a': 'claim-1'},
    void Function(_Backend backend)? duringLesson,
  }) async {
    final repo = FakeProgressRepository();
    final backend = _Backend();
    final container = ProviderContainer(
      overrides: [
        progressRepositoryProvider.overrideWithValue(repo),
        curriculumRepositoryProvider.overrideWithValue(
          FakeCurriculumRepository(),
        ),
        gamificationProvider.overrideWith(TestGamificationNotifier.new),
        backendServiceProvider.overrideWithValue(backend),
        referralStoreProvider.overrideWithValue(_Store(claims)),
        if (serverClaim != null)
          referralApiProvider.overrideWithValue(
            ReferralApi(
              (route, {required method, body, headers = const {}}) async =>
                  ApiResponse(200, {
                    'own_claim': {'claim_id': serverClaim},
                  }),
            ),
          ),
        lessonSessionProvider.overrideWith(
          () => _Session(unitId, examMode: examMode),
        ),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(lessonSessionProvider.notifier);
    await notifier.retry();
    // The teaching card's only way on is Continue, which reports a skip.
    await notifier.onExerciseAnswered(outcome: ExerciseOutcome.skipped);
    await notifier.nextExercise();
    duringLesson?.call(backend);
    await notifier.onExerciseAnswered(outcome: ExerciseOutcome.incorrect);
    await notifier.nextExercise();
    // The miss comes back once before the lesson ends.
    await notifier.onExerciseAnswered(outcome: ExerciseOutcome.correct);
    await notifier.nextExercise();
    expect(repo.committed, isTrue, reason: 'the lesson itself always commits');
    return repo;
  }

  test(
    'a free-unit lesson under a claim queues its receipt with the attempt',
    () async {
      final pending = (await play()).recordedReferralReceipt!;
      expect(pending.accountId, 'account-a');
      expect(pending.receipt.claimId, 'claim-1');
      expect(pending.receipt.lessonId, 100);
      expect(pending.receipt.coverage, {
        898: ReferralInteraction.teachingAcknowledged,
        899: ReferralInteraction.answeredIncorrectly,
      });
      expect(pending.receipt.digest, matches(RegExp(r'^[0-9a-f]{64}$')));
    },
  );

  test('lessons outside the free units never produce a receipt', () async {
    expect((await play(unitId: 3)).recordedReferralReceipt, isNull);
  });

  test('an exam attempt never produces a receipt', () async {
    expect(
      (await play(unitId: 1, examMode: true)).recordedReferralReceipt,
      isNull,
    );
  });

  test('without a claim when the attempt began there is no receipt', () async {
    expect((await play(claims: const {})).recordedReferralReceipt, isNull);
  });

  test(
    'an account switch mid-lesson drops the receipt, not the lesson',
    () async {
      final repo = await play(
        duringLesson: (backend) => backend.userId = 'account-b',
      );
      expect(repo.recordedReferralReceipt, isNull);
    },
  );
  test(
    'first lesson after reinstall records evidence under recovered server claim',
    () async {
      final repo = await play(claims: {}, serverClaim: 'recovered');
      expect(repo.recordedReferralReceipt?.receipt.claimId, 'recovered');
      expect(repo.recordedReferralReceipt?.accountId, 'account-a');
    },
  );
}
