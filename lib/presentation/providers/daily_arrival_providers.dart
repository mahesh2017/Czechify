import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/engines/daily_arrival_engine.dart';
import 'curriculum_providers.dart';
import 'database_providers.dart';
import 'gamification_providers.dart';
import 'review_providers.dart';
import 'settings_providers.dart';

const dailyArrivalShownDayKey = 'daily_arrival_last_shown_day';

/// Injectable clock keeps the once-per-day boundary deterministic in tests.
final dailyArrivalClockProvider = Provider<DateTime Function()>(
  (_) => DateTime.now,
);

final dailyArrivalDueProvider = FutureProvider<bool>((ref) async {
  final prefs = await ref.watch(sharedPreferencesProvider.future);
  return DailyArrivalSchedule.shouldShow(
    lastShownDay: prefs.getString(dailyArrivalShownDayKey),
    now: ref.read(dailyArrivalClockProvider)(),
  );
});

Future<void> markDailyArrivalShown(WidgetRef ref) async {
  final prefs = await ref.read(sharedPreferencesProvider.future);
  await prefs.setString(
    dailyArrivalShownDayKey,
    DailyArrivalSchedule.dayKey(ref.read(dailyArrivalClockProvider)()),
  );
}

final dailyArrivalStateProvider = FutureProvider<DailyArrivalState>((
  ref,
) async {
  // The notifier starts with safe defaults while Drift loads. Awaiting ready
  // prevents a returning learner briefly receiving a first-day message.
  await Future.wait([
    ref.read(gamificationProvider.notifier).ready,
    ref.read(settingsProvider.notifier).ready,
  ]);
  final gamification = ref.read(gamificationProvider);
  final nextLesson = await ref.watch(nextLessonProvider.future);
  final dueReviews = await ref.watch(dueCardCountProvider.future);
  final stored = await ref.read(databaseProvider).gamificationDao.load();
  final lastActivity = DateTime.tryParse(stored?.lastOpenDate ?? '');
  final now = ref.read(dailyArrivalClockProvider)();
  final daysSinceActivity =
      lastActivity == null ? 0 : _calendarDaysBetween(lastActivity, now);

  return const DailyArrivalEngine().select(
    learnerName: ref.read(settingsProvider).learnerName,
    streak: gamification.currentStreak,
    totalXp: gamification.totalXp,
    dailyXp: gamification.dailyXp,
    dailyGoalXp: gamification.dailyGoalXp,
    dueReviews: dueReviews,
    daysSinceActivity: daysSinceActivity,
    lessonId: nextLesson?.lesson.id,
    lessonTitle: nextLesson?.lesson.title,
    unitTitle: nextLesson?.unitTitle,
  );
});

int _calendarDaysBetween(DateTime earlier, DateTime later) {
  final a = DateTime(earlier.year, earlier.month, earlier.day);
  final b = DateTime(later.year, later.month, later.day);
  return b.difference(a).inDays;
}
