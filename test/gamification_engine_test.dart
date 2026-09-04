import 'package:flutter_test/flutter_test.dart';
import 'package:czechify/domain/entities/gamification_state.dart';
import 'package:czechify/domain/engines/gamification_engine.dart';

void main() {
  group('GamificationEngine', () {
    final engine = GamificationEngine();

    group('calculateXp', () {
      // A lesson's award is deliberately not an engine rule: it is the sum of
      // the per-exercise XP the learner was shown. See
      // test/lesson_xp_contract_test.dart.

      test('reviewSessionCompleted gives 2 XP per review', () {
        final xp = engine.calculateXp(
          actionType: XpActionType.reviewSessionCompleted,
          reviewCount: 10,
        );
        expect(xp, 20);
      });

      test('streakMilestone gives 5 XP per streak day', () {
        final xp = engine.calculateXp(
          actionType: XpActionType.streakMilestone,
          streakDays: 7,
        );
        expect(xp, 35);
      });

      test('pronunciationDrill with 80%+ gives 10 XP', () {
        final xp = engine.calculateXp(
          actionType: XpActionType.pronunciationDrill,
          accuracy: 0.9,
        );
        expect(xp, 10);
      });

      test('pronunciationDrill with <80% gives 5 XP', () {
        final xp = engine.calculateXp(
          actionType: XpActionType.pronunciationDrill,
          accuracy: 0.6,
        );
        expect(xp, 5);
      });
    });

    group('processWrongAnswer', () {
      test('deducts one heart', () {
        const state = GamificationState(hearts: 5);
        final result = engine.processWrongAnswer(state);
        expect(result.hearts, 4);
        expect(result.isGameOver, false);
      });

      test('game over when hearts reach 0', () {
        const state = GamificationState(hearts: 1);
        final result = engine.processWrongAnswer(state);
        expect(result.hearts, 0);
        expect(result.isGameOver, true);
        expect(result.canRefill, true);
      });

      test('hearts never go below 0 (regression)', () {
        const state = GamificationState(hearts: 0);
        final result = engine.processWrongAnswer(state);
        expect(result.hearts, 0);
        expect(result.isGameOver, true);
      });
    });

    group('checkBadges', () {
      test('unlocks streak badge when streak >= threshold', () {
        const snapshot = ProgressSnapshot(longestStreak: 7);
        final unlocked = engine.checkBadges(snapshot);
        expect(unlocked.any((b) => b.id == 'streak_7'), isTrue);
      });

      test('does not unlock streak badge when streak < threshold', () {
        const snapshot = ProgressSnapshot(longestStreak: 6);
        final unlocked = engine.checkBadges(snapshot);
        expect(unlocked.any((b) => b.id == 'streak_7'), isFalse);
      });

      test('does not unlock already-earned badges', () {
        const snapshot = ProgressSnapshot(
          longestStreak: 7,
          earnedBadges: {'streak_7'},
        );
        final unlocked = engine.checkBadges(snapshot);
        expect(unlocked.any((b) => b.id == 'streak_7'), isFalse);
      });

      test('unlocks unit badge when unit score meets threshold', () {
        const snapshot = ProgressSnapshot(unitScores: {3: 0.85});
        final unlocked = engine.checkBadges(snapshot);
        expect(unlocked.any((b) => b.id == 'case_nominative'), isTrue);
      });

      test('does not unlock unit badge when score below threshold', () {
        const snapshot = ProgressSnapshot(unitScores: {3: 0.5});
        final unlocked = engine.checkBadges(snapshot);
        expect(unlocked.any((b) => b.id == 'case_nominative'), isFalse);
      });

      test('custom key badge does NOT auto-unlock without custom value', () {
        const snapshot = ProgressSnapshot(
          customValues: {}, // no custom values
        );
        final unlocked = engine.checkBadges(snapshot);
        expect(unlocked.any((b) => b.id == 'verb_byt'), isFalse);
      });

      test('custom key badge unlocks when custom value meets threshold', () {
        const snapshot = ProgressSnapshot(
          customValues: {'byt_conjugation': 1.0},
        );
        final unlocked = engine.checkBadges(snapshot);
        expect(unlocked.any((b) => b.id == 'verb_byt'), isTrue);
      });

      test('exam badge unlocks when exam passed', () {
        const snapshot = ProgressSnapshot(examsPassed: {'a1'});
        final unlocked = engine.checkBadges(snapshot);
        expect(unlocked.any((b) => b.id == 'mock_a1_pass'), isTrue);
      });
    });

    group('rankFor', () {
      test('0 XP = Bronze', () {
        expect(engine.rankFor(0), Rank.bronze);
      });

      // Asserted against the thresholds rather than literals: they are tuned
      // to the size of a lesson's award and were rescaled once already, when
      // lessons stopped paying a flat 10/15/20.
      for (final rank in Rank.values) {
        test('${rank.name} begins at its own threshold', () {
          expect(engine.rankFor(rank.xpThreshold), rank);
        });
      }

      test('a tier holds until the next one is reached', () {
        expect(engine.rankFor(Rank.gold.xpThreshold - 1), Rank.silver);
        expect(
          engine.rankFor(Rank.diamond.xpThreshold * 2),
          Rank.diamond,
        );
      });

      test('the ladder stays sized to what a lesson pays', () {
        // Ranks read lifetime XP, so these only ever climb. A median lesson
        // pays 125: Silver should be several lessons in and Diamond a long
        // haul, not the ten lessons Diamond became when awards grew sixfold.
        expect(Rank.silver.xpThreshold ~/ 125, greaterThanOrEqualTo(4));
        expect(Rank.diamond.xpThreshold ~/ 125, greaterThanOrEqualTo(40));
      });
    });
  });

  group('GamificationState', () {
    test('default state has 5 hearts and null lastHeartRefill', () {
      const state = GamificationState();
      expect(state.hearts, 5);
      expect(state.maxHearts, 5);
      expect(state.currentStreak, 0);
      expect(state.lastHeartRefill, isNull);
    });

    test('isGameOver is true when hearts <= 0', () {
      const state = GamificationState(hearts: 0);
      expect(state.isGameOver, isTrue);
    });

    test('dailyGoalMet is true when dailyXp >= dailyGoalXp', () {
      const state = GamificationState(dailyXp: 50, dailyGoalXp: 50);
      expect(state.dailyGoalMet, isTrue);
    });

    test('copyWith preserves unchanged fields', () {
      const state = GamificationState(hearts: 3, totalXp: 100);
      final updated = state.copyWith(hearts: 5);
      expect(updated.hearts, 5);
      expect(updated.totalXp, 100);
    });
  });
}
