import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/feedback/celebration.dart';
import '../../data/database/daos/gamification_dao.dart';
import '../../domain/entities/gamification_state.dart';
import '../../domain/engines/gamification_engine.dart';
import 'database_providers.dart';

/// How often a missing heart regenerates.
const heartRegenInterval = Duration(minutes: 30);

/// Gamification state provider with Drift persistence.
///
/// State is stored in the Drift database (gamification_state table, v6 schema
/// migration) for transactional integrity and future cross-device sync.
///
/// On first launch after the migration, existing SharedPreferences values are
/// migrated to Drift automatically.
final gamificationProvider =
    NotifierProvider<GamificationNotifier, GamificationState>(
      GamificationNotifier.new,
    );

class GamificationNotifier extends Notifier<GamificationState> {
  final _engine = GamificationEngine();
  GamificationDao? _dao;

  @override
  GamificationState build() {
    _readyFuture = _initAsync().catchError((Object e, StackTrace st) {
      // Never let gamification init crash the app — fall back to defaults.
      // The error is logged but swallowed so the learner can still use the app.
      Logger(
        'GamificationNotifier',
      ).warning('Gamification init failed; using defaults.', e, st);
    });
    return const GamificationState();
  }

  /// Initialize asynchronously — loads from Drift, migrates from
  /// SharedPreferences if needed, and checks streak, daily-XP rollover,
  /// and heart regeneration.
  Future<void> _initAsync() async {
    _dao = ref.read(databaseProvider).gamificationDao;
    await _migrateFromPrefsIfNeeded();
    await _loadState();
    await _checkStreakOnOpen();
    await _rolloverDailyXpIfNeeded();
    await _checkHeartRegen();
  }

  /// All public mutators await this so a lesson/review finishing right
  /// after startup can't persist default state over the stored values.
  ///
  /// We use a sentinel Future that completes when _initAsync finishes.
  late final Future<void> _readyFuture;

  /// Completes after persisted values and calendar rollovers are applied.
  Future<void> get ready => _readyFuture;

  Future<void> _ensureReady() => _readyFuture;

  /// One-time migration: if the Drift gamification table is empty AND
  /// SharedPreferences has gamification keys, copy them into Drift.
  Future<void> _migrateFromPrefsIfNeeded() async {
    final existing = await _dao?.load();
    if (existing != null) return; // Already migrated or fresh start

    final prefs = await SharedPreferences.getInstance();
    final hasPrefs = prefs.containsKey('gamification_hearts');
    if (!hasPrefs) return; // Fresh install — nothing to migrate

    // Migrate from SharedPreferences to Drift
    final hearts = prefs.getInt('gamification_hearts') ?? 5;
    final maxHearts = prefs.getInt('gamification_max_hearts') ?? 5;
    final currentStreak = prefs.getInt('gamification_current_streak') ?? 0;
    final longestStreak = prefs.getInt('gamification_longest_streak') ?? 0;
    final totalXp = prefs.getInt('gamification_total_xp') ?? 0;
    final dailyXp = prefs.getInt('gamification_daily_xp') ?? 0;
    final dailyGoalXp = prefs.getInt('gamification_daily_goal_xp') ?? 50;
    final gems = prefs.getInt('gamification_gems') ?? 0;
    final streakFreeze = prefs.getBool('gamification_streak_freeze') ?? true;

    final badgesJson = prefs.getString('gamification_earned_badges') ?? '[]';
    final lastRefillStr = prefs.getString('gamification_last_heart_refill');
    final lastOpenDate = prefs.getString('gamification_last_open_date');
    final dailyXpResetDate = prefs.getString(
      'gamification_daily_xp_reset_date',
    );

    await _dao?.save(
      hearts: hearts,
      maxHearts: maxHearts,
      currentStreak: currentStreak,
      longestStreak: longestStreak,
      totalXp: totalXp,
      dailyXp: dailyXp,
      dailyGoalXp: dailyGoalXp,
      gems: gems,
      earnedBadgesJson: badgesJson,
      lastHeartRefill:
          lastRefillStr != null ? DateTime.tryParse(lastRefillStr) : null,
      streakFreezeAvailable: streakFreeze,
      lastOpenDate: lastOpenDate,
      dailyXpResetDate: dailyXpResetDate,
    );

    // Clear SharedPreferences gamification keys to avoid stale reads
    await prefs.remove('gamification_hearts');
    await prefs.remove('gamification_max_hearts');
    await prefs.remove('gamification_current_streak');
    await prefs.remove('gamification_longest_streak');
    await prefs.remove('gamification_total_xp');
    await prefs.remove('gamification_daily_xp');
    await prefs.remove('gamification_daily_goal_xp');
    await prefs.remove('gamification_gems');
    await prefs.remove('gamification_earned_badges');
    await prefs.remove('gamification_last_heart_refill');
    await prefs.remove('gamification_streak_freeze');
    await prefs.remove('gamification_last_open_date');
    await prefs.remove('gamification_daily_xp_reset_date');
  }

  /// Load persisted state from Drift.
  Future<void> _loadState() async {
    final row = await _dao?.load();
    if (row == null) return; // Fresh install — use defaults

    final badgesJson = row.earnedBadges;
    final earnedBadges = <String>{};
    if (badgesJson.isNotEmpty) {
      try {
        final list = jsonDecode(badgesJson) as List<dynamic>;
        earnedBadges.addAll(list.cast<String>());
      } catch (_) {
        // Badges JSON corrupted — start with empty set
      }
    }

    state = GamificationState(
      hearts: row.hearts,
      maxHearts: row.maxHearts,
      currentStreak: row.currentStreak,
      longestStreak: row.longestStreak,
      totalXp: row.totalXp,
      dailyXp: row.dailyXp,
      dailyGoalXp: row.dailyGoalXp,
      gems: row.gems,
      earnedBadges: earnedBadges,
      lastHeartRefill: row.lastHeartRefill,
      streakFreezeAvailable: row.streakFreezeAvailable,
    );
  }

  /// Check streak on app open — compare last activity date with today.
  /// Only breaks stale streaks; does NOT write today's date.
  /// The actual streak increment happens in _maybeIncrementStreak on first XP earn.
  Future<void> _checkStreakOnOpen() async {
    final row = await _dao?.load();
    if (row == null) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final lastActivityStr = row.lastOpenDate;

    if (lastActivityStr == null) return;

    final lastActivity = DateTime.tryParse(lastActivityStr);
    if (lastActivity == null) return;

    final lastActivityDay = DateTime(
      lastActivity.year,
      lastActivity.month,
      lastActivity.day,
    );
    final diffDays = _calendarDaysBetween(lastActivityDay, today);

    if (diffDays == 0) return;

    if (diffDays == 1) return;

    // Gap > 1 day — streak broken
    if (state.streakFreezeAvailable && diffDays == 2) {
      state = state.copyWith(streakFreezeAvailable: false);
      await _persist();
      return;
    }

    state = state.copyWith(currentStreak: 0);
    await _persist();
  }

  /// Reset daily XP when the calendar day has rolled over.
  Future<void> _rolloverDailyXpIfNeeded() async {
    final row = await _dao?.load();
    if (row == null) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final lastResetStr = row.dailyXpResetDate;
    final lastReset =
        lastResetStr != null ? DateTime.tryParse(lastResetStr) : null;

    if (lastReset != null) {
      final lastResetDay = DateTime(
        lastReset.year,
        lastReset.month,
        lastReset.day,
      );
      if (lastResetDay == today) return; // Already reset today
    }

    state = state.copyWith(dailyXp: 0);
    await _persist(resetDate: today.toIso8601String());
  }

  /// Check if hearts should regenerate based on time elapsed.
  Future<void> _checkHeartRegen() async {
    if (state.hearts >= state.maxHearts) return;
    if (state.lastHeartRefill == null) return;

    final now = DateTime.now();
    final lastRefill = state.lastHeartRefill!;

    final elapsed = now.difference(lastRefill);
    final heartsToRegen = elapsed.inMinutes ~/ heartRegenInterval.inMinutes;

    if (heartsToRegen > 0) {
      final newHearts = (state.hearts + heartsToRegen).clamp(
        0,
        state.maxHearts,
      );
      state = state.copyWith(hearts: newHearts, lastHeartRefill: now);
      await _persist();
    }
  }

  /// Persist all state to Drift.
  ///
  /// [resetDate] — when set, updates the daily XP reset date marker.
  /// [openDate] — when set, updates the last-open-date marker.
  Future<void> _persist({String? resetDate, String? openDate}) async {
    final row = await _dao?.load();
    final currentReset = resetDate ?? row?.dailyXpResetDate;
    final currentOpen = openDate ?? row?.lastOpenDate;

    await _dao?.save(
      hearts: state.hearts,
      maxHearts: state.maxHearts,
      currentStreak: state.currentStreak,
      longestStreak: state.longestStreak,
      totalXp: state.totalXp,
      dailyXp: state.dailyXp,
      dailyGoalXp: state.dailyGoalXp,
      gems: state.gems,
      earnedBadgesJson: jsonEncode(state.earnedBadges.toList()),
      lastHeartRefill: state.lastHeartRefill,
      streakFreezeAvailable: state.streakFreezeAvailable,
      lastOpenDate: currentOpen,
      dailyXpResetDate: currentReset,
    );
  }

  // ── Public API ──

  /// Reconciles in-memory state after progress and XP commit together, and
  /// reports back anything the learner just earned.
  ///
  /// Returning these rather than announcing them here is deliberate: the
  /// caller knows the narrative order. Badges were being written to the
  /// database and never mentioned, so a learner earning "Week Warrior" found
  /// out only if they happened to open the Stats screen.
  Future<List<Celebration>> refreshAfterCommittedLesson() async {
    await _ensureReady();
    await _loadState();
    final streakAdvanced = await _maybeIncrementStreak();
    final badges = await checkProgressBadges();

    final rewards = <Celebration>[
      for (final badge in badges)
        BadgeEarned(
          badgeId: badge.id,
          name: badge.name,
          icon: badge.icon,
          xpReward: badge.xpReward,
        ),
    ];

    // A streak badge already says "seven days" in its own words; announcing
    // the streak alongside it would congratulate the same thing twice.
    final streakAlreadyCredited = badges.any(
      (badge) => badge.criteria.minStreak != null,
    );
    if (streakAdvanced &&
        !streakAlreadyCredited &&
        StreakExtended.isMilestone(state.currentStreak)) {
      rewards.add(StreakExtended(days: state.currentStreak));
    }
    return rewards;
  }

  /// Called when the user gets a wrong answer in a lesson.
  /// Starts the regen clock the moment the first heart is lost.
  Future<int> onWrongAnswer() async {
    await _ensureReady();
    await _checkHeartRegen();

    final result = _engine.processWrongAnswer(state);
    state = state.copyWith(
      hearts: result.hearts,
      lastHeartRefill: state.lastHeartRefill ?? DateTime.now(),
    );
    await _persist();
    return result.hearts;
  }

  /// Set the daily XP goal.
  Future<void> setDailyGoal(int xp) async {
    await _ensureReady();
    state = state.copyWith(dailyGoalXp: xp);
    await _persist();
  }

  /// Manually refill one heart.
  Future<void> refillHeart() async {
    await _ensureReady();
    if (state.hearts < state.maxHearts) {
      state = state.copyWith(
        hearts: state.hearts + 1,
        lastHeartRefill: DateTime.now(),
      );
      await _persist();
    }
  }

  /// Refill hearts to full (e.g., using gems).
  Future<void> refillAllHearts() async {
    await _ensureReady();
    if (state.hearts < state.maxHearts) {
      state = state.copyWith(
        hearts: state.maxHearts,
        lastHeartRefill: DateTime.now(),
      );
      await _persist();
    }
  }

  /// Re-check timed heart regeneration (e.g., when a screen opens).
  Future<void> refreshHearts() async {
    await _ensureReady();
    await _checkHeartRegen();
  }

  /// Award a badge if not already earned.
  Future<void> awardBadge(String badgeId, int xpReward) async {
    await _ensureReady();
    if (state.earnedBadges.contains(badgeId)) return;

    state = state.copyWith(
      earnedBadges: {...state.earnedBadges, badgeId},
      totalXp: state.totalXp + xpReward,
      dailyXp: state.dailyXp + xpReward,
    );
    await _persist();

    // Mirror into the database so progress snapshots see it too.
    try {
      await ref.read(databaseProvider).progressDao.earnBadge(badgeId);
    } catch (_) {
      // Drift gamification state remains the source of truth for display.
    }
  }

  /// Evaluate all badge criteria against current progress and award
  /// anything newly earned. Called after lessons, reviews, and exams.
  ///
  /// Returns the badges awarded by this call, so the caller can show them.
  Future<List<Badge>> checkProgressBadges() async {
    await _ensureReady();
    try {
      final progressRepo = ref.read(progressRepositoryProvider);
      final dbSnapshot = await progressRepo.getSnapshot();

      final snapshot = ProgressSnapshot(
        unitScores: dbSnapshot.unitScores,
        longestStreak: state.longestStreak,
        examsPassed: dbSnapshot.examsPassed,
        earnedBadges: state.earnedBadges,
        customValues: dbSnapshot.customValues,
      );

      final awarded = <Badge>[];
      for (final badge in _engine.checkBadges(snapshot)) {
        // awardBadge is a no-op for one already held, so this stays accurate
        // even if two paths evaluate badges at the same moment.
        if (state.earnedBadges.contains(badge.id)) continue;
        await awardBadge(badge.id, badge.xpReward);
        awarded.add(badge);
      }
      return awarded;
    } catch (_) {
      // Badge evaluation must never break the learning flow.
      return const [];
    }
  }

  /// Force reload from storage (e.g., after importing settings).
  Future<void> reload() async {
    await _ensureReady();
    await _loadState();
  }

  // ── Private helpers ──

  /// Whole calendar days between two dates, immune to DST hour-length
  /// changes (consecutive local midnights can be 23h or 25h apart, which
  /// would make `difference().inDays` truncate a real day-gap to 0).
  static int _calendarDaysBetween(DateTime a, DateTime b) {
    final ua = DateTime.utc(a.year, a.month, a.day);
    final ub = DateTime.utc(b.year, b.month, b.day);
    return ub.difference(ua).inDays;
  }

  /// Increment streak if this is the first XP earned today.
  Future<bool> _maybeIncrementStreak() async {
    final row = await _dao?.load();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final lastOpenStr = row?.lastOpenDate;
    if (lastOpenStr != null) {
      final lastOpen = DateTime.tryParse(lastOpenStr);
      if (lastOpen != null) {
        final lastOpenDay = DateTime(
          lastOpen.year,
          lastOpen.month,
          lastOpen.day,
        );
        if (lastOpenDay == today) {
          return false;
        }
      }
    }

    final newStreak = state.currentStreak + 1;
    final newLongest =
        newStreak > state.longestStreak ? newStreak : state.longestStreak;

    state = state.copyWith(
      currentStreak: newStreak,
      longestStreak: newLongest,
      streakFreezeAvailable: true,
    );

    await _persist(openDate: today.toIso8601String());

    try {
      await ref
          .read(progressRepositoryProvider)
          .updateStreak(newStreak, newLongest);
    } catch (_) {
      // Drift gamification state remains the source of truth.
    }
    return true;
  }
}
