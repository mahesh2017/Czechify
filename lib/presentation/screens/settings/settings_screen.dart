import 'dart:io';
import 'package:app_settings/app_settings.dart' as system_settings;
import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/backend_config.dart';
import '../../../core/legal/legal_content.dart';
import '../../../core/notifications/notification_service.dart';
import '../../../core/theme/app_tokens.dart';
import '../../providers/curriculum_providers.dart';
import '../../providers/settings_providers.dart';
import '../../providers/reminder_coordinator.dart';
import '../../../domain/entities/enums.dart';
import '../../providers/tts_providers.dart';
import '../onboarding/offline_setup_screen.dart';
import '../../../data/services/audio/offline_audio_prefetch.dart';
import '../../providers/audio_prefetch_providers.dart';
import '../../providers/app_info_providers.dart';
import '../../providers/consent_providers.dart';
import '../../providers/sync_health_providers.dart';
import '../../providers/sync_providers.dart';
import '../../widgets/common/cloud_speech_consent.dart';
import '../../widgets/common/lesson_ui.dart';
import '../../widgets/common/soft_ui.dart';
import '../../widgets/common/text_prompt_dialog.dart';

/// Settings screen — theme, daily goal, TTS rate, cache management.
/// The AI-provider credential lives in the `deepseek-proxy` Edge Function, never
/// in the client, so there is no API-key entry here.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key, this.scrollController});

  /// The sheet's scroll controller. Driving the list with it is what lets a
  /// downward drag at the top dismiss the sheet.
  final ScrollController? scrollController;

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  Future<void> _editName(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final result = await showTextPromptDialog(
      context: context,
      title: l10n.settingsYourName,
      confirmLabel: l10n.save,
      fields: [
        TextPromptField(
          label: l10n.settingsFirstName,
          initialValue: ref.read(settingsProvider).learnerName,
          textCapitalization: TextCapitalization.words,
        ),
      ],
    );
    final name = result?.single.trim();
    if (name != null && name.isNotEmpty) {
      await ref.read(settingsProvider.notifier).setLearnerName(name);
    }
  }

  /// Show what the two levels actually contain, then confirm before moving.
  ///
  /// A dropdown put a content-unlocking, bandwidth-spending change one stray
  /// thumb away, and told a learner nothing about what they were choosing
  /// between. "A1" and "A2" mean little to the people this course is for.
  Future<void> _openLevelPicker() async {
    final l10n = AppLocalizations.of(context);
    final current = ref.read(settingsProvider).startingLevel;
    final chosen = await showModalBottomSheet<CEFRLevel>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: context.tokens.bg,
      builder: (ctx) => _LevelPickerSheet(current: current),
    );
    if (chosen == null || !mounted) return;

    final normalisedCurrent =
        current == CEFRLevel.a2 ? CEFRLevel.a2 : CEFRLevel.a1;
    if (chosen == normalisedCurrent) return;

    final movingUp = chosen == CEFRLevel.a2;
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            icon: Icon(Icons.school_outlined, color: context.tokens.pri),
            title: Text(l10n.settingsSwitchLevelTitle(_levelLabel(chosen))),
            content: Text(
              movingUp
                  ? l10n.settingsSwitchUpBody
                  : l10n.settingsSwitchDownBody,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text(l10n.settingsSwitchLevel(_levelLabel(chosen))),
              ),
            ],
          ),
    );
    if (confirmed != true || !mounted) return;

    await _switchLevel(chosen);
  }

  /// Change course level, and fetch the new level's audio if it is missing.
  ///
  /// A learner who picked A1 to try the app and then wanted A2 previously had
  /// no way through: the level chosen at onboarding was never written again,
  /// and the A1/A2 control on the course screen only changed what was listed,
  /// not what was unlocked.
  ///
  /// Moving up unlocks the new level and leaves everything below it open.
  /// Moving back down is not a demotion — units already unlocked stay that
  /// way, and only the tutor's pitch and the offline downloads follow the
  /// setting. That asymmetry is the point: exploring this control must never
  /// cost a learner access they have earned.
  Future<void> _switchLevel(CEFRLevel level) async {
    final l10n = AppLocalizations.of(context);
    final unlockedMore = await ref.read(levelSwitchProvider)(level);
    if (!mounted) return;

    final label = _levelLabel(level);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          unlockedMore
              ? l10n.settingsLevelOpened(label)
              : l10n.settingsLevelSwitched(label),
        ),
      ),
    );

    // The prefetch set is level-dependent, so the clips for the new level are
    // almost certainly absent. Left alone, the first lesson falls back to the
    // device voice under an offline notice on a working connection.
    final gender = ref.read(settingsProvider).ttsVoiceGender;
    final units = await OfflineAudioPrefetch.unitsForLevel(
      level,
      count: OfflineSetupScreen.prefetchUnitCount,
    );
    final missing = await ref
        .read(offlineAudioPrefetchProvider)
        .missingFiles(units, gender.name);
    if (missing.isEmpty || !mounted) return;

    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder:
          (ctx) => _AudioDownloadDialog(
            subject: l10n.settingsAudioSubject(label),
            gender: gender,
            missingCount: missing.length,
            units: units,
          ),
    );
  }

  static String _levelLabel(CEFRLevel level) => switch (level) {
    CEFRLevel.preA1 => 'A1',
    CEFRLevel.a1 => 'A1',
    CEFRLevel.a2 => 'A2',
  };

  /// Switch voice, and fetch that voice's audio if it is not on device yet.
  ///
  /// Only the voice chosen at onboarding is downloaded, so switching can leave
  /// a learner with no clips for the new voice. Offline that means silence —
  /// which reads as a broken app rather than a missing download, so it is
  /// explained rather than left to be discovered.
  Future<void> _switchVoice(TtsVoiceGender gender) async {
    await ref.read(settingsProvider.notifier).setTtsVoiceGender(gender);

    final prefetch = ref.read(offlineAudioPrefetchProvider);
    final units = await OfflineAudioPrefetch.unitsForLevel(
      ref.read(settingsProvider).startingLevel,
      count: OfflineSetupScreen.prefetchUnitCount,
    );
    final missing = await prefetch.missingFiles(units, gender.name);
    if (missing.isEmpty) {
      if (mounted) {
        await ref.read(czechTtsProvider).playVoiceSample(gender);
      }
      return;
    }

    // Try to fetch it now. If the network is there this is a few megabytes and
    // finishes while the dialog is open; if not, we say so plainly.
    if (!mounted) return;
    final downloaded = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder:
          (ctx) => _AudioDownloadDialog(
            subject:
                gender == TtsVoiceGender.male
                    ? AppLocalizations.of(context).settingsVoiceSubjectMale
                    : AppLocalizations.of(context).settingsVoiceSubjectFemale,
            gender: gender,
            missingCount: missing.length,
            units: units,
          ),
    );

    if (!mounted) return;
    if (downloaded ?? false) {
      await ref.read(czechTtsProvider).playVoiceSample(gender);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(settingsProvider);
    final cloudSpeech = ref.watch(cloudSpeechConsentProvider);
    final syncHealth = ref.watch(syncHealthProvider);

    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        bottom: false,
        child: ListView(
          controller: widget.scrollController,
          // Settings is presented without the global tab bar; leave enough
          // room for its last destructive/legal controls and the home
          // indicator instead of letting them finish flush to the screen.
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 44),
          children: [
            // The grab handle is drawn by the sheet route itself, so it is a
            // real control rather than a picture of one.
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: DisplayText(l10n.settings, size: 29)),
                FilledButton.tonal(
                  onPressed: () => Navigator.of(context).maybePop(),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    backgroundColor: t.elev,
                    foregroundColor: t.ink,
                    elevation: 0,
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: Text(l10n.settingsDone),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // ── Profile ──
            _GroupLabel(l10n.settingsProfileGroup),
            _Group(
              children: [
                _Row(
                  icon: Icons.person_outline,
                  tint: t.priSoft,
                  fg: t.pri,
                  title: l10n.settingsYourName,
                  subtitle:
                      settings.learnerName.isEmpty
                          ? l10n.settingsNotSet
                          : settings.learnerName,
                  onTap: () => _editName(context, ref),
                ),
              ],
            ),

            // ── Account (only when backend is configured) ──
            if (BackendConfig.isConfigured) ...[
              _GroupLabel(l10n.settingsAccountGroup),
              _Group(
                children: [
                  _Row(
                    icon: Icons.manage_accounts_outlined,
                    tint: t.priSoft,
                    fg: t.pri,
                    title: l10n.settingsAccountDataTitle,
                    subtitle: l10n.settingsAccountDataBody,
                    onTap: () => context.push('/account'),
                  ),
                ],
              ),
            ],

            // ── Appearance ──
            _GroupLabel(l10n.settingsAppearanceGroup),
            _Group(
              children: [
                _Row(
                  icon: Icons.dark_mode_outlined,
                  tint: t.violetSoft,
                  fg: t.violet,
                  title: l10n.settingsTheme,
                  subtitle: _themeLabel(l10n, settings.themeMode),
                  trailing: _ThemeToggle(
                    mode: settings.themeMode,
                    onChanged:
                        (m) =>
                            ref.read(settingsProvider.notifier).setThemeMode(m),
                  ),
                ),
                // No interface-language row: the course teaches Czech to
                // people who do not read it yet, so a Czech interface would
                // lock them out of their own settings. The Czech ARB and its
                // generated delegate are still in the tree — when a second
                // interface language that the audience actually reads lands,
                // add it to kInterfaceLocales and this row comes back.
              ],
            ),

            // ── Learning ──
            _GroupLabel(l10n.settingsLearningGroup),
            _Group(
              children: [
                _Row(
                  icon: Icons.school_outlined,
                  tint: t.priSoft,
                  fg: t.pri,
                  title: l10n.settingsCourseLevel,
                  subtitle:
                      settings.startingLevel == CEFRLevel.a2
                          ? l10n.settingsA2UpperBeginner
                          : l10n.settingsA1Beginner,
                  // Not a dropdown. Changing level unlocks curriculum, repitches
                  // the tutor and pulls down a new level's audio, so it is worth
                  // a screen that says what each level is and a confirmation
                  // that names the consequences — rather than something you can
                  // knock into with a thumb while scrolling past.
                  onTap: _openLevelPicker,
                  trailing: Icon(Icons.chevron_right, color: t.faint),
                ),
                _Divider(),
                _Row(
                  icon: Icons.flag_outlined,
                  tint: t.priSoft,
                  fg: t.pri,
                  title: l10n.settingsDailyGoal,
                  subtitle: l10n.settingsXpPerDay(settings.dailyGoalXp),
                  trailing: DropdownButton<int>(
                    value: settings.dailyGoalXp,
                    underline: const SizedBox.shrink(),
                    style: TextStyle(
                      color: t.pri,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                    onChanged: (xp) {
                      if (xp != null) {
                        ref.read(settingsProvider.notifier).setDailyGoalXp(xp);
                      }
                    },
                    items: [
                      // A stored goal that is not one of the presets — written
                      // by an older build, or by an onboarding whose numbers
                      // had drifted from these — makes DropdownButton assert,
                      // which took the whole Settings screen down. Offering it
                      // as its own item keeps the screen openable and shows the
                      // learner the goal they are actually on; choosing any
                      // preset replaces it.
                      if (!kDailyGoalPresets.any(
                        (p) => p.$1 == settings.dailyGoalXp,
                      ))
                        DropdownMenuItem(
                          value: settings.dailyGoalXp,
                          child: Text('${settings.dailyGoalXp} XP'),
                        ),
                      for (final (xp, label, _) in kDailyGoalPresets)
                        DropdownMenuItem(value: xp, child: Text(label)),
                    ],
                  ),
                ),
                _Divider(),
                _Row(
                  icon: Icons.favorite_border,
                  tint: t.redSoft,
                  fg: t.red,
                  title: l10n.settingsHearts,
                  subtitle: l10n.settingsHeartsBody,
                  trailing: Switch(
                    value: settings.heartsEnabled,
                    onChanged:
                        (v) => ref
                            .read(settingsProvider.notifier)
                            .setHeartsEnabled(v),
                  ),
                ),
                _Divider(),
                // Separate from the Czech audio below on purpose: someone who
                // wants a quiet app still needs to hear the language.
                _Row(
                  icon: Icons.music_note_outlined,
                  tint: t.amberSoft,
                  fg: t.amber,
                  title: l10n.settingsSoundEffects,
                  subtitle: l10n.settingsSoundBody,
                  trailing: Switch(
                    value: settings.soundEffectsEnabled,
                    onChanged:
                        (v) => ref
                            .read(settingsProvider.notifier)
                            .setSoundEffectsEnabled(v),
                  ),
                ),
                _Divider(),
                _Row(
                  icon: Icons.vibration,
                  tint: t.violetSoft,
                  fg: t.violet,
                  title: l10n.settingsVibration,
                  subtitle: l10n.settingsHapticsBody,
                  trailing: Switch(
                    value: settings.hapticsEnabled,
                    onChanged:
                        (v) => ref
                            .read(settingsProvider.notifier)
                            .setHapticsEnabled(v),
                  ),
                ),
              ],
            ),

            // ── Study Reminders (mobile only — hidden on macOS) ──
            if (Platform.isIOS || Platform.isAndroid) ...[
              _GroupLabel(l10n.settingsRemindersGroup),
              _Group(
                children: [
                  _Row(
                    icon: Icons.notifications_active_outlined,
                    tint: t.amberSoft,
                    fg: t.amber,
                    title: l10n.reminderSettingsTitle,
                    subtitle: l10n.reminderSettingsBody,
                    trailing: Switch(
                      value: settings.remindersEnabled,
                      onChanged: (v) async {
                        await ref
                            .read(reminderCoordinatorProvider.notifier)
                            .setRemindersEnabled(v);
                      },
                    ),
                  ),
                  if (settings.remindersEnabled) ...[
                    _Divider(),
                    // Reminder time picker row.
                    _ReminderTimeRow(
                      time:
                          settings.preferredTime ??
                          const TimeOfDay(hour: 19, minute: 0),
                      onChanged: (time) async {
                        await ref
                            .read(reminderCoordinatorProvider.notifier)
                            .setPreferredTime(time);
                      },
                    ),
                    // Catch-up toggle — only when gap > 2h (otherwise
                    // suppressed by the scheduler's own gap check).
                    if (_catchUpGapIsWide(
                      settings.preferredTime ??
                          const TimeOfDay(hour: 19, minute: 0),
                    )) ...[
                      _Divider(),
                      _Row(
                        icon: Icons.nights_stay_outlined,
                        tint: t.violetSoft,
                        fg: t.violet,
                        title: l10n.reminderCatchUpLabel,
                        subtitle: l10n.reminderStepCatchUp,
                        trailing: Switch(
                          value: settings.catchUpEnabled,
                          onChanged:
                              (v) => ref
                                  .read(settingsProvider.notifier)
                                  .setCatchUpEnabled(v),
                        ),
                      ),
                    ] else if (settings.catchUpEnabled) ...[
                      _Divider(),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline, size: 18, color: t.faint),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                l10n.reminderCatchUpSuppressed,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  color: t.muted,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    // Permission blocked warning.
                    _ReminderPermissionWarning(),
                  ],
                ],
              ),
            ],

            // ── Audio ──
            _GroupLabel(l10n.settingsAudioGroup),
            _Group(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          IconTile(
                            icon: Icons.person_outline,
                            tint: t.priSoft,
                            fg: t.pri,
                            size: 36,
                            radius: 12,
                            iconSize: 17,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.settingsTeacherVoice,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: t.ink,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${settings.ttsVoiceGender.tutorName} · '
                                  '${settings.ttsVoiceGender.tutorTagline}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: t.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SegmentedButton<TtsVoiceGender>(
                        // Named, as the design has them — the gender lives in
                        // the subtitle above, not on the buttons.
                        segments: [
                          for (final voice in TtsVoiceGender.values)
                            ButtonSegment(
                              value: voice,
                              label: Text(voice.tutorName),
                            ),
                        ],
                        selected: {settings.ttsVoiceGender},
                        onSelectionChanged: (selection) async {
                          await _switchVoice(selection.single);
                        },
                      ),
                    ],
                  ),
                ),
                _Divider(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          IconTile(
                            icon: Icons.record_voice_over_outlined,
                            tint: t.amberSoft,
                            fg: t.amber,
                            size: 36,
                            radius: 12,
                            iconSize: 15,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.settingsSpeechRate,
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w600,
                                    color: t.ink,
                                  ),
                                ),
                                Text(
                                  l10n.settingsSpeechRateBody,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    color: t.muted,
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // Was a raw-rate slider labelled Slow/Normal/Fast. It
                      // stored 0.2-1.0 in nine steps while playback divides by
                      // the native rate and clamps to 0.5x-1.5x, so its top
                      // four stops all produced 1.5x and the words hid that
                      // three separate positions did the same thing. These are
                      // the speeds playback can actually distinguish.
                      const TtsSpeedSelector(stops: kTtsSpeedStops),
                    ],
                  ),
                ),
                _Divider(),
                _Row(
                  icon: Icons.play_arrow_rounded,
                  tint: t.greenSoft,
                  fg: t.green,
                  title: l10n.settingsTestVoice,
                  subtitle: l10n.settingsTestVoiceBody,
                  onTap:
                      () =>
                          ref.read(czechTtsProvider).speak('Ahoj, jak se máš?'),
                ),
                _Divider(),
                _Row(
                  icon: Icons.cloud_outlined,
                  tint: t.violetSoft,
                  fg: t.violet,
                  title: l10n.settingsCloudPronunciation,
                  // Naming the alternative, because "optional" invites the
                  // question "optional instead of what?" — and the answer is
                  // not "no pronunciation checking", it is your phone's own
                  // recogniser, which is what runs by default.
                  subtitle: l10n.settingsCloudPronunciationBody,
                  trailing: Switch(
                    value: cloudSpeech.value ?? false,
                    onChanged:
                        cloudSpeech.isLoading
                            ? null
                            : (enabled) async {
                              if (!enabled) {
                                await ref
                                    .read(cloudSpeechConsentProvider.notifier)
                                    .setGranted(false);
                                return;
                              }
                              // Same words, same record, wherever it is
                              // asked — see requestCloudSpeechConsent.
                              await requestCloudSpeechConsent(context, ref);
                            },
                  ),
                ),
                _Divider(),
                // Sync health was tracked but never shown, so items that
                // exhausted their retries were counted and then stranded: the
                // learner's change was never reaching the backend and nothing
                // said so. Only rendered when there is something to act on.
                if (BackendConfig.isConfigured && syncHealth.failedCount > 0)
                  _Row(
                    icon: Icons.sync_problem_outlined,
                    tint: t.redSoft,
                    fg: t.redInk,
                    title: l10n.settingsRetrySync,
                    subtitle: syncHealth.description,
                    onTap: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final revived =
                          await ref
                              .read(syncHealthProvider.notifier)
                              .retryFailed();
                      await ref.read(syncServiceProvider).sync();
                      await ref.read(syncHealthProvider.notifier).refresh();
                      if (!context.mounted) return;
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(l10n.settingsRetryingItems(revived)),
                        ),
                      );
                    },
                  ),
                if (BackendConfig.isConfigured && syncHealth.failedCount > 0)
                  _Divider(),
                _Row(
                  icon: Icons.delete_outline,
                  tint: t.chipBg,
                  fg: t.muted,
                  title: l10n.settingsClearAudioCache,
                  subtitle: l10n.settingsClearAudioBody,
                  onTap: () async {
                    await ref.read(czechTtsProvider).clearCache();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.settingsAudioCleared)),
                      );
                    }
                  },
                ),
              ],
            ),

            // Account lives in its own group near the top when the backend is
            // configured; it used to be repeated here with a different title
            // but the same subtitle and the same /account route.
            if (!BackendConfig.isConfigured) ...[
              _GroupLabel(l10n.settingsAccountDataGroup),
              _Group(
                children: [
                  _Row(
                    icon: Icons.manage_accounts_outlined,
                    tint: t.priSoft,
                    fg: t.pri,
                    title: l10n.settingsExportDelete,
                    subtitle: l10n.settingsExportDeleteBody,
                    onTap: () => context.push('/account'),
                  ),
                ],
              ),
            ],

            // ── About ──
            _GroupLabel(l10n.settingsAboutGroup),
            _Group(
              children: [
                _Row(
                  icon: Icons.school_outlined,
                  tint: t.priSoft,
                  fg: t.pri,
                  title: l10n.settingsAbout,
                  subtitle: l10n.settingsAboutBody(kDeveloperName),
                  onTap: () => context.push('/about'),
                  trailing: Icon(Icons.chevron_right, size: 15, color: t.faint),
                ),
                _Divider(),
                _Row(
                  icon: Icons.code,
                  tint: t.chipBg,
                  fg: t.muted,
                  title: l10n.settingsVersion,
                  subtitle: ref.watch(appVersionProvider).value ?? '…',
                  trailing: const SizedBox.shrink(),
                ),
                _Divider(),
                _Row(
                  icon: Icons.privacy_tip_outlined,
                  tint: t.priSoft,
                  fg: t.pri,
                  title: l10n.settingsPrivacyPolicy,
                  subtitle: l10n.settingsPrivacyBody,
                  onTap: () => context.push('/privacy'),
                  trailing: Icon(Icons.chevron_right, size: 15, color: t.faint),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _themeLabel(AppLocalizations l10n, AppThemeMode mode) {
    return switch (mode) {
      AppThemeMode.system => l10n.settingsThemeSystem,
      AppThemeMode.light => l10n.settingsThemeLight,
      AppThemeMode.dark => l10n.settingsThemeDark,
    };
  }

  /// Whether the preferred reminder time is far enough from 21:30 (≥ 2h)
  /// that the evening catch-up makes sense.
  static bool _catchUpGapIsWide(TimeOfDay preferred) {
    const eveningMinutes = 21 * 60 + 30; // 21:30
    final prefMinutes = preferred.hour * 60 + preferred.minute;
    final gap = (eveningMinutes - prefMinutes).abs();
    return gap >= 120;
  }
}

/// Tappable row that opens a [showTimePicker] and calls [onChanged].
class _ReminderTimeRow extends StatelessWidget {
  const _ReminderTimeRow({required this.time, required this.onChanged});

  final TimeOfDay time;
  final ValueChanged<TimeOfDay> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l10n = AppLocalizations.of(context);
    final label =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    return InkWell(
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: time,
          helpText: l10n.reminderTimeLabel,
        );
        if (picked != null) onChanged(picked);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            IconTile(
              icon: Icons.schedule_outlined,
              tint: t.elev,
              fg: t.muted,
              size: 36,
              radius: 12,
              iconSize: 18,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.reminderTimeLabel,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: t.ink,
                    ),
                  ),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      color: t.muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 15, color: t.faint),
          ],
        ),
      ),
    );
  }
}

/// Checks notification permission and shows a warning + "Open Settings"
/// instruction when reminders are enabled but the OS has blocked notifications.
class _ReminderPermissionWarning extends StatefulWidget {
  @override
  State<_ReminderPermissionWarning> createState() =>
      _ReminderPermissionWarningState();
}

class _ReminderPermissionWarningState
    extends State<_ReminderPermissionWarning> {
  bool? _permitted;
  bool _checking = true;
  AppLifecycleListener? _lifecycleListener;

  @override
  void initState() {
    super.initState();
    _checkPermission();
    _lifecycleListener = AppLifecycleListener(onResume: _checkPermission);
  }

  @override
  void dispose() {
    _lifecycleListener?.dispose();
    super.dispose();
  }

  Future<void> _checkPermission() async {
    final result = await NotificationService.instance.areNotificationsEnabled();
    if (mounted) {
      setState(() {
        _permitted = result;
        _checking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) return const SizedBox.shrink();
    // null = unknown (e.g. macOS) — don't show a false alarm.
    if (_permitted == null || _permitted == true) {
      return const SizedBox.shrink();
    }

    final t = context.tokens;
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        _Divider(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.warning_amber_rounded, size: 20, color: t.amber),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.reminderPermissionBlocked,
                      style: TextStyle(
                        fontSize: 13.5,
                        color: t.muted,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () => _openSystemSettings(),
                      icon: Icon(
                        Icons.settings_outlined,
                        size: 18,
                        color: t.pri,
                      ),
                      label: Text(
                        l10n.reminderOpenSettings,
                        style: TextStyle(
                          color: t.pri,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _openSystemSettings() async {
    await system_settings.AppSettings.openAppSettings(
      type: system_settings.AppSettingsType.notification,
    );
  }
}

class _GroupLabel extends StatelessWidget {
  final String title;
  const _GroupLabel(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 10),
      child: SectionLabel(title),
    );
  }
}

/// A rounded card grouping settings rows.
class _Group extends StatelessWidget {
  final List<Widget> children;
  const _Group({required this.children});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(24),
        boxShadow: t.shadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Divider(height: 1, thickness: 1, color: context.tokens.line);
}

/// A settings row. Chrome stays neutral; colour is reserved for state and
/// meaning rather than making the settings list a rainbow.
class _Row extends StatelessWidget {
  final IconData icon;
  final Color tint;
  final Color fg;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _Row({
    required this.icon,
    required this.tint,
    required this.fg,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            IconTile(
              icon: icon,
              tint: t.elev,
              fg: t.muted,
              size: 36,
              radius: 12,
              iconSize: 15,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: t.ink,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: t.muted,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
            trailing ??
                (onTap != null
                    ? Icon(Icons.chevron_right, size: 15, color: t.faint)
                    : const SizedBox.shrink()),
          ],
        ),
      ),
    );
  }
}

/// Light / Auto / Dark segmented control.
class _ThemeToggle extends StatelessWidget {
  final AppThemeMode mode;
  final ValueChanged<AppThemeMode> onChanged;

  const _ThemeToggle({required this.mode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    Widget seg(String label, AppThemeMode m) {
      final selected = mode == m;
      return GestureDetector(
        onTap: () => onChanged(m),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: selected ? t.card : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            boxShadow: selected ? t.shadow : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              color: selected ? t.ink : t.muted,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: t.chipBg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          seg('Light', AppThemeMode.light),
          seg('Auto', AppThemeMode.system),
          seg('Dark', AppThemeMode.dark),
        ],
      ),
    );
  }
}

/// Downloads the newly chosen voice's audio, or explains why it cannot.
///
/// The distinction matters: silence from a missing download is not a broken
/// app, and a learner who is told "connect to Wi-Fi to save this voice" will
/// wait, whereas one who just hears nothing concludes the app is faulty and
/// leaves. Pops `true` once the audio is on device.
/// Fetches a set of units' clips while showing progress.
///
/// Used for two different reasons — switching voice and switching level — that
/// leave a learner in the same place: settings say one thing, the clips on
/// disk say another, and offline that difference is silence. Silence reads as
/// a broken app rather than a missing download, so it is explained rather than
/// left to be discovered.
class _AudioDownloadDialog extends ConsumerStatefulWidget {
  const _AudioDownloadDialog({
    required this.subject,
    required this.gender,
    required this.missingCount,
    required this.units,
  });

  /// What is being saved, as a noun phrase that reads inside a sentence:
  /// 'the male voice', 'A2 audio'.
  final String subject;

  final TtsVoiceGender gender;
  final int missingCount;

  /// The units resolved for the learner's level, so the dialog downloads the
  /// same set the caller measured as missing.
  final List<int> units;

  @override
  ConsumerState<_AudioDownloadDialog> createState() =>
      _AudioDownloadDialogState();
}

class _AudioDownloadDialogState extends ConsumerState<_AudioDownloadDialog> {
  PrefetchProgress? _progress;
  bool _offline = false;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    setState(() {
      _offline = false;
      _done = false;
      _progress = null;
    });
    try {
      await for (final progress in ref
          .read(offlineAudioPrefetchProvider)
          .download(widget.units, widget.gender.name)) {
        if (!mounted) return;
        setState(() => _progress = progress);
        if (progress.finished) {
          // Everything failing is a connection problem, not bad luck.
          _offline = progress.total > 0 && progress.failed == progress.total;
          _done = true;
        }
      }
    } catch (_) {
      if (mounted) setState(() => _offline = _done = true);
    }
    if (mounted && _done && !_offline) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l10n = AppLocalizations.of(context);
    final subject = widget.subject;
    final subjectCapitalised =
        subject.isEmpty
            ? subject
            : subject[0].toUpperCase() + subject.substring(1);
    final progress = _progress;

    return AlertDialog(
      icon: Icon(
        _offline ? Icons.wifi_off_rounded : Icons.download_rounded,
        color: _offline ? t.amber : t.pri,
      ),
      title: Text(
        _offline
            ? l10n.settingsDownloadConnectTitle(subject)
            : l10n.settingsDownloadSavingTitle(subject),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _offline
                ? l10n.settingsDownloadOfflineBody(subjectCapitalised)
                : l10n.settingsDownloadingClips(widget.missingCount),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14.5, color: t.muted, height: 1.45),
          ),
          if (!_offline) ...[
            const SizedBox(height: 16),
            LinearProgressIndicator(value: progress?.fraction ?? 0),
          ],
        ],
      ),
      actions: [
        if (_offline) TextButton(onPressed: _run, child: Text(l10n.tryAgain)),
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(_offline ? l10n.settingsNotNow : l10n.settingsHide),
        ),
      ],
    );
  }
}

/// What the two levels contain, in the words of what a learner will be able to
/// do — not "A1" and "A2", which mean nothing until someone tells you.
class _LevelPickerSheet extends ConsumerStatefulWidget {
  const _LevelPickerSheet({required this.current});

  final CEFRLevel current;

  @override
  ConsumerState<_LevelPickerSheet> createState() => _LevelPickerSheetState();
}

class _LevelPickerSheetState extends ConsumerState<_LevelPickerSheet> {
  late CEFRLevel _selected =
      widget.current == CEFRLevel.a2 ? CEFRLevel.a2 : CEFRLevel.a1;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l10n = AppLocalizations.of(context);
    final currentNormalised =
        widget.current == CEFRLevel.a2 ? CEFRLevel.a2 : CEFRLevel.a1;
    // Counted, not written down. A literal here is a fact about today's
    // curriculum file rather than about the course, and goes stale silently
    // the first time a unit is added.
    final unitCounts = ref
        .watch(allUnitsProvider)
        .maybeWhen(
          data:
              (units) => {
                for (final phase in Phase.values)
                  phase: units.where((u) => u.phase == phase).length,
              },
          orElse: () => const <Phase, int>{},
        );
    String unitLabel(Phase phase) {
      final count = unitCounts[phase];
      return count == null ? '' : l10n.settingsUnitsCount(count);
    }

    return SafeArea(
      // Scrollable and height-capped: two description cards plus a button do
      // not fit a short screen, and at large text sizes they do not fit any
      // screen. Overflowing here would paint the striped bar over the choice
      // the sheet exists to offer.
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.settingsChooseLevel,
                style: TextStyle(
                  fontFamily: AppFonts.display,
                  color: t.ink,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                l10n.settingsChooseLevelBody,
                style: TextStyle(color: t.muted, fontSize: 14.5, height: 1.45),
              ),
              const SizedBox(height: 18),
              _LevelCard(
                code: 'A1',
                name: l10n.settingsLevelBeginner,
                units: unitLabel(Phase.a1),
                blurb: l10n.settingsLevelA1Body,
                forWho: l10n.settingsLevelA1Audience,
                selected: _selected == CEFRLevel.a1,
                isCurrent: currentNormalised == CEFRLevel.a1,
                onTap: () => setState(() => _selected = CEFRLevel.a1),
              ),
              const SizedBox(height: 12),
              _LevelCard(
                code: 'A2',
                name: l10n.settingsLevelUpperBeginner,
                units: unitLabel(Phase.a2),
                blurb: l10n.settingsLevelA2Body,
                forWho: l10n.settingsLevelA2Audience,
                selected: _selected == CEFRLevel.a2,
                isCurrent: currentNormalised == CEFRLevel.a2,
                onTap: () => setState(() => _selected = CEFRLevel.a2),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed:
                      _selected == currentNormalised
                          ? null
                          : () => Navigator.of(context).pop(_selected),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    _selected == currentNormalised
                        ? l10n.settingsLevelCurrent
                        : l10n.continueLabel,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LevelCard extends StatelessWidget {
  const _LevelCard({
    required this.code,
    required this.name,
    required this.units,
    required this.blurb,
    required this.forWho,
    required this.selected,
    required this.isCurrent,
    required this.onTap,
  });

  final String code;
  final String name;
  final String units;
  final String blurb;
  final String forWho;
  final bool selected;
  final bool isCurrent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          decoration: BoxDecoration(
            color: selected ? t.priSoft : t.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? t.pri : t.line,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    code,
                    style: TextStyle(
                      fontFamily: AppFonts.display,
                      color: selected ? t.pri : t.ink,
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      name,
                      style: TextStyle(
                        color: t.ink,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (isCurrent)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: t.card,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: t.line),
                      ),
                      child: Text(
                        'Current',
                        style: TextStyle(
                          color: t.muted,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: .6,
                        ),
                      ),
                    )
                  else
                    Icon(
                      selected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      size: 20,
                      color: selected ? t.pri : t.faint,
                    ),
                ],
              ),
              if (units.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  units,
                  style: TextStyle(
                    color: t.faint,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Text(
                blurb,
                style: TextStyle(color: t.muted, fontSize: 14, height: 1.45),
              ),
              const SizedBox(height: 8),
              Text(
                forWho,
                style: TextStyle(
                  color: selected ? t.pri : t.faint,
                  fontSize: 13,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
