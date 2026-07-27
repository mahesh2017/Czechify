import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/enums.dart';

/// Theme mode enum.
enum AppThemeMode { system, light, dark }

/// The bundled Azure neural voice used for curriculum audio.
enum TtsVoiceGender { female, male }

/// App-wide settings state.
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

  /// Language of the app's own interface. Null follows the device locale —
  /// the default, so a Czech-speaking device gets a Czech UI unprompted.
  /// Distinct from the language being learned, which is always Czech.
  final Locale? locale;

  const AppSettings({
    this.themeMode = AppThemeMode.system,
    this.dailyGoalXp = 50,
    this.ttsSpeechRate = 0.45,
    this.ttsVoiceGender = TtsVoiceGender.female,
    this.startingLevel = CEFRLevel.preA1,
    this.heartsEnabled = true,
    this.learnerName = '',
    this.soundEffectsEnabled = true,
    this.hapticsEnabled = true,
    this.locale,
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

  @override
  AppSettings build() {
    _loadSettings();
    return const AppSettings();
  }

  /// Prefs accessor — always awaited so setters can't race the initial load.
  Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

  Future<void> _loadSettings() async {
    final prefs = await _prefs();
    final themeIdx = prefs.getInt(_kThemeMode) ?? 0;
    final dailyGoal = prefs.getInt(_kDailyGoalXp) ?? 50;
    final ttsRate = prefs.getDouble(_kTtsRate) ?? 0.45;
    final voiceIndex = prefs.getInt(_kTtsVoiceGender) ?? 0;
    final levelIdx = prefs.getInt(_kStartingLevel) ?? 0;

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
      locale: switch (prefs.getString(_kLocale)) {
        final String tag when tag.isNotEmpty => Locale(tag),
        _ => null,
      },
    );
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
