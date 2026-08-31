import 'package:czechify/domain/engines/daily_arrival_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const engine = DailyArrivalEngine();

  DailyArrivalState select({
    int streak = 0,
    int totalXp = 0,
    int dailyXp = 0,
    int dailyGoalXp = 50,
    int dueReviews = 0,
    int daysSinceActivity = 0,
    int? lessonId = 101,
  }) => engine.select(
    learnerName: ' Mahesh ',
    streak: streak,
    totalXp: totalXp,
    dailyXp: dailyXp,
    dailyGoalXp: dailyGoalXp,
    dueReviews: dueReviews,
    daysSinceActivity: daysSinceActivity,
    lessonId: lessonId,
    lessonTitle: lessonId == null ? null : 'Greetings',
    unitTitle: lessonId == null ? null : 'Unit 1',
  );

  group('message selection', () {
    test('a fresh learner gets a first-step welcome', () {
      expect(select().kind, DailyArrivalKind.firstStep);
    });

    test('an active learner is encouraged to protect the streak', () {
      expect(select(streak: 6, totalXp: 250).kind, DailyArrivalKind.keepStreak);
    });

    test('due retrieval practice takes priority over a streak', () {
      expect(
        select(streak: 6, totalXp: 250, dueReviews: 8).kind,
        DailyArrivalKind.reviewsReady,
      );
    });

    test('a returning learner receives a gentle comeback message', () {
      expect(
        select(totalXp: 250, dueReviews: 8, daysSinceActivity: 3).kind,
        DailyArrivalKind.welcomeBack,
      );
    });

    test('a completed daily goal remains the strongest positive signal', () {
      expect(
        select(
          streak: 6,
          totalXp: 250,
          dailyXp: 50,
          dueReviews: 8,
          daysSinceActivity: 3,
        ).kind,
        DailyArrivalKind.goalComplete,
      );
    });

    test('a learner with no next lesson sees the course-complete state', () {
      expect(select(lessonId: null).kind, DailyArrivalKind.courseComplete);
    });

    test('normalizes the name and clamps goal progress', () {
      final state = select(dailyXp: 70);
      expect(state.learnerName, 'Mahesh');
      expect(state.goalProgress, 1);
    });
  });

  group('once-daily schedule', () {
    final morning = DateTime(2026, 8, 2, 7, 30);
    final evening = DateTime(2026, 8, 2, 22, 15);

    test('shows when no welcome has been recorded', () {
      expect(
        DailyArrivalSchedule.shouldShow(lastShownDay: null, now: morning),
        isTrue,
      );
    });

    test('does not show twice on the same local calendar day', () {
      expect(
        DailyArrivalSchedule.shouldShow(
          lastShownDay: DailyArrivalSchedule.dayKey(morning),
          now: evening,
        ),
        isFalse,
      );
    });

    test('shows again on the next local calendar day', () {
      expect(
        DailyArrivalSchedule.shouldShow(
          lastShownDay: DailyArrivalSchedule.dayKey(morning),
          now: DateTime(2026, 8, 3, 0, 1),
        ),
        isTrue,
      );
    });
  });
}
