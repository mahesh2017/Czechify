import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/enums.dart';

/// Theme mode enum.
enum AppThemeMode { system, light, dark }

/// Languages the interface itself is offered in.
///
/// Deliberately not every locale we have strings for. Czech is the subject
/// of the course, not a language the audience can be assumed to read — a
/// Czech interface would leave a beginner unable to find their way back out
/// of Settings. `app_cs.arb` and its generated delegate stay in the tree for
/// whenever that changes; adding a locale here is all it takes to offer it.
const List<Locale> kInterfaceLocales = <Locale>[Locale('en')];

/// The bundled Azure neural voice used for curriculum audio.
enum TtsVoiceGender { female, male }

/// The two teachers, as the design names them.
///
/// A learner picks *Lenka* or *Pavel*, not "female" or "male" — the voice's
/// gender is a detail about the teacher, not their identity. Kept here rather
/// than inline at each picker because the name had already drifted: settings
/// and onboarding said "Female"/"Male", the lesson player said "Lenka", and
/// the onboarding summary said "Matěj".
extension CzechTutor on TtsVoiceGender {
  /// What we call this teacher everywhere in the interface.
  String get tutorName => switch (this) {
    TtsVoiceGender.female => 'Lenka',
    TtsVoiceGender.male => 'Pavel',
  };

  /// How they sound — the secondary line under the name on the picker cards.
  ///
  /// No city: the comp said "Prague" and "Brno", but both are Azure standard
  /// Czech neural voices (cs-CZ-VlastaNeural and cs-CZ-AntoninNeural), so
  /// neither carries a regional accent and "Brno" was a claim the audio does
  /// not back up.
  String get tutorTagline => switch (this) {
    TtsVoiceGender.female => 'Warm and clear',
    TtsVoiceGender.male => 'Slower and lower',
  };
}

/// App-wide settings state.
/// Playback speed for recorded Czech audio, and the baseline it is measured
/// against.
///
/// [kNativeTtsSpeechRate] is not a preference — it is the rate at which a clip
/// plays back unaltered, so `rate / native` is the speed multiplier. Changing
/// it would silently re-time the whole pack.
///
/// The default sits on the native rate deliberately: the teaching pace lives
/// in the recordings now, not in the player.
///
/// It was briefly 0.35 (~0.78x) to slow down short clips the voice was
/// rushing. Re-recording those clips fixed the cause — "To je" went from
/// 0.177s to 0.261s, matching the female voice — and the two slowdowns then
/// compounded to roughly 1.6x the original length, which reads as laboured
/// rather than clear.
///
/// Slowing playback was the wrong lever anyway. It stretches every clip
/// equally, including the ones that were already well paced, whereas the
/// defect was confined to how one voice distributed time *within* a short
/// sentence. Fixing the audio fixes it once, for every learner, at no cost to
/// the clips that were fine.
///
/// The slider still spans 0.2–1.0, so a learner who wants it slower is one
/// drag away.
/// The speeds the in-lesson chip cycles through, as multiples of the recorded
/// pace.
///
/// Deliberately short and centred on 1.0: this is a control a learner reaches
/// for mid-sentence, so it has to be one tap away from normal in either
/// direction. Anything finer belongs on the Settings slider, which still spans
/// the full range.
const List<double> kTtsSpeedStops = [0.75, 1.0, 1.25];

const double kNativeTtsSpeechRate = 0.45;
const double kDefaultTtsSpeechRate = kNativeTtsSpeechRate;

class AppSettings {
  final AppThemeMode themeMode;
  final int dailyGoalXp;
  final double ttsSpeechRate;
  final TtsVoiceGender ttsVoiceGender;
  final CEFRLevel startingLevel;

  /// When false, lessons never deduct hearts ("practice mode") — mistakes
  /// are where learning happens, so this makes hearts opt-in pressure.
  final bool heartsEnabled;

  /// The learner's first name, collected during onboarding. Used to
  /// personalize greetings and AI tutor interactions. Empty string when
  /// the user hasn't provided it yet.
  final String learnerName;

  /// Sound effects for answers and completions. Separate from the Czech
  /// audio, which is course content and stays on regardless — someone who
  /// wants a quiet app still needs to hear the language.
  final bool soundEffectsEnabled;

  /// Haptic feedback on answers and completions.
  final bool hapticsEnabled;

  /// Language of the app's own interface, constrained to
  /// [kInterfaceLocales]. Null follows the device locale. Distinct from the
  /// language being learned, which is always Czech.
  final Locale? locale;
  final bool curriculumMapView;

  /// Preferred study reminder time. Null = no reminder set.
  /// Stored as two ints in SharedPreferences: hour and minute.
  final TimeOfDay? preferredTime;

  /// Whether daily reminder is enabled. Default false.
  /// Only true if user explicitly opted in during onboarding or Settings.
  final bool remindersEnabled;

  /// Whether the 21:30 evening catch-up is enabled. Default true
  /// (but only active if remindersEnabled is also true).
  /// Auto-suppressed when preferredTime is within 2h of 21:30.
  final bool catchUpEnabled;

  /// IANA timezone name last detected from the device. Null = not yet
  /// detected. Used to detect timezone changes on app resume and trigger
  /// rescheduling of all owned notifications.
  final String? lastKnownTimezone;

  const AppSettings({
    this.themeMode = AppThemeMode.system,
    this.dailyGoalXp = 50,
    this.ttsSpeechRate = kDefaultTtsSpeechRate,
    this.ttsVoiceGender = TtsVoiceGender.female,
    this.startingLevel = CEFRLevel.preA1,
    this.heartsEnabled = true,
    this.learnerName = '',
    this.soundEffectsEnabled = true,
    this.hapticsEnabled = true,
    this.locale,
    this.curriculumMapView = true,
    this.preferredTime,
    this.remindersEnabled = false,
    this.catchUpEnabled = true,
    this.lastKnownTimezone,
  });

  AppSettings copyWith({
    AppThemeMode? themeMode,
    int? dailyGoalXp,
    double? ttsSpeechRate,
    TtsVoiceGender? ttsVoiceGender,
    CEFRLevel? startingLevel,
    bool? heartsEnabled,
    String? learnerName,
    bool? soundEffectsEnabled,
    bool? hapticsEnabled,
    Locale? locale,
    bool clearLocale = false,
    bool? curriculumMapView,
    TimeOfDay? preferredTime,
    bool? remindersEnabled,
    bool? catchUpEnabled,
    String? lastKnownTimezone,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      dailyGoalXp: dailyGoalXp ?? this.dailyGoalXp,
      ttsSpeechRate: ttsSpeechRate ?? this.ttsSpeechRate,
      ttsVoiceGender: ttsVoiceGender ?? this.ttsVoiceGender,
      startingLevel: startingLevel ?? this.startingLevel,
      heartsEnabled: heartsEnabled ?? this.heartsEnabled,
      learnerName: learnerName ?? this.learnerName,
      soundEffectsEnabled: soundEffectsEnabled ?? this.soundEffectsEnabled,
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
      // copyWith cannot express "back to null" through a nullable argument,
      // and "follow the device" is a real choice the user can pick.
      locale: clearLocale ? null : (locale ?? this.locale),
      curriculumMapView: curriculumMapView ?? this.curriculumMapView,
      preferredTime: preferredTime ?? this.preferredTime,
      remindersEnabled: remindersEnabled ?? this.remindersEnabled,
      catchUpEnabled: catchUpEnabled ?? this.catchUpEnabled,
      lastKnownTimezone: lastKnownTimezone ?? this.lastKnownTimezone,
    );
  }
}

/// Notifier that manages app settings persisted to SharedPreferences.
class SettingsNotifier extends Notifier<AppSettings> {
  static const _kThemeMode = 'settings_theme_mode';
  static const _kDailyGoalXp = 'settings_daily_goal_xp';
  static const _kTtsRate = 'settings_tts_rate';
  static const _kTtsVoiceGender = 'settings_tts_voice_gender';
  static const _kOnboardingDone = 'settings_onboarding_done';
  static const _kStartingLevel = 'settings_starting_level';
  static const _kHeartsEnabled = 'settings_hearts_enabled';
  static const _kLearnerName = 'settings_learner_name';
  static const _kSoundEffects = 'settings_sound_effects_enabled';
  static const _kHaptics = 'settings_haptics_enabled';
  static const _kLocale = 'settings_locale';
  static const _kCurriculumMapView = 'settings_curriculum_map_view';
  static const _kReminderHour = 'settings_reminder_hour';
  static const _kReminderMinute = 'settings_reminder_minute';
  static const _kRemindersEnabled = 'settings_reminders_enabled';
  static const _kCatchUpEnabled = 'settings_catch_up_enabled';
  static const _kLastKnownTimezone = 'settings_last_known_timezone';

  @override
  AppSettings build() {
    _readyFuture = _loadSettings();
    return const AppSettings();
  }

  late final Future<void> _readyFuture;

  /// Completes after the persisted learner profile and preferences are loaded.
  Future<void> get ready => _readyFuture;

  /// Prefs accessor — always awaited so setters can't race the initial load.
  Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

  Future<void> _loadSettings() async {
    final prefs = await _prefs();
    final themeIdx = prefs.getInt(_kThemeMode) ?? 0;
    final dailyGoal = prefs.getInt(_kDailyGoalXp) ?? 50;
    final ttsRate = prefs.getDouble(_kTtsRate) ?? kDefaultTtsSpeechRate;
    final voiceIndex = prefs.getInt(_kTtsVoiceGender) ?? 0;
    final levelIdx = prefs.getInt(_kStartingLevel) ?? 0;
    final reminderHour = prefs.getInt(_kReminderHour);
    final reminderMinute = prefs.getInt(_kReminderMinute);
    final remindersEnabled = prefs.getBool(_kRemindersEnabled) ?? false;
    final catchUpEnabled = prefs.getBool(_kCatchUpEnabled) ?? true;
    final lastKnownTz = prefs.getString(_kLastKnownTimezone);

    state = AppSettings(
      themeMode:
          AppThemeMode.values[themeIdx.clamp(
            0,
            AppThemeMode.values.length - 1,
          )],
      dailyGoalXp: dailyGoal,
      ttsSpeechRate: ttsRate,
      ttsVoiceGender:
          TtsVoiceGender.values[voiceIndex.clamp(
            0,
            TtsVoiceGender.values.length - 1,
          )],
      startingLevel:
          CEFRLevel.values[levelIdx.clamp(0, CEFRLevel.values.length - 1)],
      heartsEnabled: prefs.getBool(_kHeartsEnabled) ?? true,
      learnerName: prefs.getString(_kLearnerName) ?? '',
      soundEffectsEnabled: prefs.getBool(_kSoundEffects) ?? true,
      hapticsEnabled: prefs.getBool(_kHaptics) ?? true,
      // A preference for a language we no longer offer falls back to
      // "follow the device" rather than stranding the learner in it.
      locale: switch (prefs.getString(_kLocale)) {
        final String tag
            when tag.isNotEmpty &&
                kInterfaceLocales.any((l) => l.languageCode == tag) =>
          Locale(tag),
        _ => null,
      },
      curriculumMapView: prefs.getBool(_kCurriculumMapView) ?? true,
      preferredTime:
          reminderHour != null &&
                  reminderHour >= 0 &&
                  reminderHour <= 23 &&
                  reminderMinute != null &&
                  reminderMinute >= 0 &&
                  reminderMinute <= 59
              ? TimeOfDay(hour: reminderHour, minute: reminderMinute)
              : null,
      remindersEnabled: remindersEnabled,
      catchUpEnabled: catchUpEnabled,
      lastKnownTimezone: lastKnownTz,
    );
  }

  Future<void> setCurriculumMapView(bool mapView) async {
    state = state.copyWith(curriculumMapView: mapView);
    final prefs = await _prefs();
    await prefs.setBool(_kCurriculumMapView, mapView);
  }

  /// Set the interface language. Null restores "follow the device".
  Future<void> setLocale(Locale? locale) async {
    state = state.copyWith(locale: locale, clearLocale: locale == null);
    final prefs = await _prefs();
    if (locale == null) {
      await prefs.remove(_kLocale);
    } else {
      await prefs.setString(_kLocale, locale.languageCode);
    }
  }

  /// Toggle answer and completion sound effects.
  Future<void> setSoundEffectsEnabled(bool enabled) async {
    state = state.copyWith(soundEffectsEnabled: enabled);
    final prefs = await _prefs();
    await prefs.setBool(_kSoundEffects, enabled);
  }

  /// Toggle haptic feedback.
  Future<void> setHapticsEnabled(bool enabled) async {
    state = state.copyWith(hapticsEnabled: enabled);
    final prefs = await _prefs();
    await prefs.setBool(_kHaptics, enabled);
  }

  /// Toggle hearts in lessons (off = practice mode, no heart loss).
  Future<void> setHeartsEnabled(bool enabled) async {
    state = state.copyWith(heartsEnabled: enabled);
    final prefs = await _prefs();
    await prefs.setBool(_kHeartsEnabled, enabled);
  }

  /// Set the theme mode.
  Future<void> setThemeMode(AppThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    final prefs = await _prefs();
    await prefs.setInt(_kThemeMode, mode.index);
  }

  /// Set the daily XP goal.
  Future<void> setDailyGoalXp(int xp) async {
    state = state.copyWith(dailyGoalXp: xp);
    final prefs = await _prefs();
    await prefs.setInt(_kDailyGoalXp, xp);
  }

  /// Set the TTS speech rate.
  Future<void> setTtsSpeechRate(double rate) async {
    state = state.copyWith(ttsSpeechRate: rate);
    final prefs = await _prefs();
    await prefs.setDouble(_kTtsRate, rate);
  }

  /// Select the bundled Czech neural voice.
  Future<void> setTtsVoiceGender(TtsVoiceGender gender) async {
    state = state.copyWith(ttsVoiceGender: gender);
    final prefs = await _prefs();
    await prefs.setInt(_kTtsVoiceGender, gender.index);
  }

  /// Set the learner's self-assessed starting level (from onboarding).
  Future<void> setStartingLevel(CEFRLevel level) async {
    state = state.copyWith(startingLevel: level);
    final prefs = await _prefs();
    await prefs.setInt(_kStartingLevel, level.index);
  }

  /// Set the learner's first name (from onboarding or settings).
  Future<void> setLearnerName(String name) async {
    final trimmed = name.trim();
    state = state.copyWith(learnerName: trimmed);
    final prefs = await _prefs();
    await prefs.setString(_kLearnerName, trimmed);
  }

  /// Check if onboarding has been completed.
  Future<bool> isOnboardingDone() async {
    final prefs = await _prefs();
    return prefs.getBool(_kOnboardingDone) ?? false;
  }

  /// Mark onboarding as complete.
  Future<void> completeOnboarding() async {
    final prefs = await _prefs();
    await prefs.setBool(_kOnboardingDone, true);
  }

  /// Set the preferred study reminder time. Null (via clearing the stored
  /// ints) means "no reminder set"; callers pass a concrete [TimeOfDay].
  Future<void> setPreferredTime(TimeOfDay time) async {
    final prefs = await _prefs();
    await prefs.setInt(_kReminderHour, time.hour);
    await prefs.setInt(_kReminderMinute, time.minute);
    state = state.copyWith(preferredTime: time);
  }

  /// Toggle daily study reminders on or off. The ReminderCoordinator reacts
  /// to the settings change: when turning on it requests notification
  /// permission and schedules; when turning off it cancels all owned IDs.
  Future<void> setRemindersEnabled(bool enabled) async {
    final prefs = await _prefs();
    await prefs.setBool(_kRemindersEnabled, enabled);
    state = state.copyWith(remindersEnabled: enabled);
  }

  /// Toggle the 21:30 evening catch-up reminder.
  Future<void> setCatchUpEnabled(bool enabled) async {
    final prefs = await _prefs();
    await prefs.setBool(_kCatchUpEnabled, enabled);
    state = state.copyWith(catchUpEnabled: enabled);
  }

  /// Record the last detected IANA timezone name. Used by the
  /// ReminderCoordinator to detect timezone changes on app resume.
  Future<void> setLastKnownTimezone(String tz) async {
    final prefs = await _prefs();
    await prefs.setString(_kLastKnownTimezone, tz);
    state = state.copyWith(lastKnownTimezone: tz);
  }
}

/// Provider for app settings.
final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
);

/// Provider that converts AppThemeMode to Flutter's ThemeMode.
final themeModeProvider = Provider<ThemeMode>((ref) {
  final settings = ref.watch(settingsProvider);
  return switch (settings.themeMode) {
    AppThemeMode.system => ThemeMode.system,
    AppThemeMode.light => ThemeMode.light,
    AppThemeMode.dark => ThemeMode.dark,
  };
});

/// Whether onboarding has been completed — read once at startup to pick
/// the router's initial location (onboarding invalidates it on finish).
final onboardingDoneProvider = FutureProvider<bool>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool('settings_onboarding_done') ?? false;
});
