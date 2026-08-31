import 'package:czechify/core/feedback/celebration.dart';
import 'package:czechify/core/theme/app_theme.dart';
import 'package:czechify/domain/entities/gamification_state.dart';
import 'package:czechify/presentation/widgets/celebration/reward_toast.dart';
// Material has a Badge widget of its own; the one under test is the course's.
import 'package:flutter/material.dart' hide Badge;
import 'package:flutter_test/flutter_test.dart';

/// Badges were written to the database and never mentioned. These pin that
/// they now reach the learner, and that the badge set is worth reaching for.
void main() {
  Future<void> show(WidgetTester tester, Celebration celebration) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: lightTheme(),
        home: Scaffold(body: RewardToast(celebration: celebration)),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('a badge says what it was and what it was worth', (tester) async {
    await show(
      tester,
      const BadgeEarned(
        badgeId: 'streak_7',
        name: 'Week Warrior',
        icon: '🔥',
        xpReward: 20,
      ),
    );
    expect(find.text('Week Warrior'), findsOneWidget);
    expect(find.textContaining('+20 XP'), findsOneWidget);
  });

  testWidgets('a streak milestone invites them back', (tester) async {
    // The one thing a streak celebration must do is point at tomorrow.
    await show(tester, const StreakExtended(days: 7));
    expect(find.textContaining('7-day streak'), findsOneWidget);
    expect(find.textContaining('tomorrow'), findsOneWidget);
  });

  group('the badge set has no long empty stretches', () {
    int unitOf(Badge badge) => badge.criteria.unitId ?? -1;

    test('no gap longer than five units across the course', () {
      // Units 7 to 28 previously awarded nothing at all — the longest stretch
      // of the course, and the one where people give up.
      final units = Badge.all.map(unitOf).where((u) => u > 0).toList()..sort();
      expect(units, isNotEmpty);

      var previous = 0;
      for (final unit in units) {
        expect(
          unit - previous,
          lessThanOrEqualTo(5),
          reason: 'nothing to earn between unit $previous and unit $unit',
        );
        previous = unit;
      }
    });

    test('short streaks are rewarded, not just long ones', () {
      // Almost everyone who quits does so in the first fortnight, long before
      // a 30-day badge is reachable.
      final streaks =
          Badge.all.map((b) => b.criteria.minStreak).whereType<int>().toList()
            ..sort();
      expect(streaks.first, lessThanOrEqualTo(3));
    });

    test('every badge is distinct and describable', () {
      final ids = Badge.all.map((b) => b.id).toSet();
      expect(ids, hasLength(Badge.all.length));
      for (final badge in Badge.all) {
        expect(badge.name, isNotEmpty);
        expect(badge.icon, isNotEmpty);
        expect(badge.xpReward, greaterThan(0));
      }
    });

    test('later badges are worth more than earlier ones', () {
      final byUnit =
          Badge.all.where((b) => unitOf(b) > 0).toList()
            ..sort((a, b) => unitOf(a).compareTo(unitOf(b)));
      for (var i = 1; i < byUnit.length; i++) {
        expect(
          byUnit[i].xpReward,
          greaterThanOrEqualTo(byUnit[i - 1].xpReward),
          reason: '${byUnit[i].id} is deeper in the course but worth less',
        );
      }
    });
  });
}
