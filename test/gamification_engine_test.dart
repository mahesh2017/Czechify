import 'package:flutter_test/flutter_test.dart';
import 'package:ceskina_pro/domain/entities/gamification_state.dart';
import 'package:ceskina_pro/domain/engines/gamification_engine.dart';

void main() {
  group('GamificationEngine', () {
    final engine = GamificationEngine();

    group('calculateXp', () {
      test('lessonCompleted with perfect accuracy gives 20 XP', () {
        final xp = engine.calculateXp(
          actionType: XpActionType.lessonCompleted,
          accuracy: 1.0,
        );
        expect(xp, 20);
      });

      test('lessonCompleted with 80%+ accuracy gives 15 XP', () {
        final xp = engine.calculateXp(
          actionType: XpActionType.lessonCompleted,
          accuracy: 0.85,
        );
        expect(xp, 15);
      });

      test('lessonCompleted with <80% accuracy gives 10 XP', () {
        final xp = engine.calculateXp(
          actionType: XpActionType.lessonCompleted,
          accuracy: 0.5,
        );
        expect(xp, 10);
      });

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

    group('getLeague', () {
      test('0 XP = Bronze', () {
        expect(engine.getLeague(0), League.bronze);
      });

      test('100 XP = Silver', () {
        expect(engine.getLeague(100), League.silver);
      });

      test('300 XP = Gold', () {
        expect(engine.getLeague(300), League.gold);
      });

      test('600 XP = Platinum', () {
        expect(engine.getLeague(600), League.platinum);
      });

      test('1000+ XP = Diamond', () {
        expect(engine.getLeague(1500), League.diamond);
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
