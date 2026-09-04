import 'dart:convert';

import 'package:flutter/material.dart';
import '../../../core/diagnostics/safe_diagnostics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/backend_config.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/settings_providers.dart';
import '../../providers/reminder_coordinator.dart';
import '../../providers/gamification_providers.dart';
import '../../providers/tts_providers.dart';
import '../../providers/database_providers.dart';
import '../../providers/curriculum_providers.dart';
import '../../providers/learner_profile_providers.dart';
import '../../widgets/common/soft_ui.dart';
import '../../widgets/common/motion_widgets.dart';
import '../../../domain/entities/enums.dart';
import '../../../domain/entities/learner_profile.dart';
import '../../../domain/engines/placement_engine.dart';

/// Seven-step onboarding that turns a learner's purpose, starting point and
/// available time into a transparent first plan.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({
    super.key,
    this.onProfileCompleted,
    this.editing = false,
  });

  /// Seam for the cloud-backed profile store. The UI owns the structured
  /// draft today; persistence can be attached without teaching this screen
  /// about account or sync infrastructure.
  final ValueChanged<LearnerProfile>? onProfileCompleted;

  /// Reuses the same transparent choices from Settings without re-showing the
  /// welcome screen or sending an established learner through offline setup.
  final bool editing;

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int _step = 0;
  LearnerProfileDraft _draft = LearnerProfileDraft();
  bool _finishing = false;
  bool _loadingExistingProfile = false;
  bool _movingForward = true;
  TtsVoiceGender? _previewingVoice;
  final _nameController = TextEditingController();
  final _stepScrollController = ScrollController();

  // welcome → profile → purpose → focus/timing → commitment → teacher →
  // reminder → plan
  static const _totalSteps = 8;

  @override
  void initState() {
    super.initState();
    if (widget.editing) {
      _step = 1;
      _loadingExistingProfile = true;
      Future<void>.microtask(_loadExistingProfile);
    }
  }

  Future<void> _loadExistingProfile() async {
    try {
      final repository = ref.read(learnerProfileRepositoryProvider);
      final profile = await repository.getProfile();
      final reminder = await repository.getReminderPreference();
      await ref.read(settingsProvider.notifier).ready;
      if (!mounted) return;
      if (profile != null) {
        final focusNames = _decodeStringList(profile.focusSkillsJson);
        final focuses =
            focusNames
                .map((name) => LearningFocus.values.asNameMap()[name])
                .whereType<LearningFocus>()
                .toSet();
        final goal =
            LearningGoal.values.asNameMap()[profile.primaryGoal] ??
            LearningGoal.everydayLife;
        final horizon = GoalHorizon.values.asNameMap()[profile.targetHorizon];
        final commitment = switch (profile.dailyCommitmentMinutes) {
          <= 5 => StudyCommitment.light,
          <= 15 => StudyCommitment.steady,
          <= 30 => StudyCommitment.focused,
          _ => StudyCommitment.intensive,
        };
        final currentLevel = switch (profile.selfAssessedCefr) {
          'a1' => LearnerCzechLevel.a1,
          'a2' => LearnerCzechLevel.a2,
          'b1OrHigher' => LearnerCzechLevel.b1OrHigher,
          'unsure' => LearnerCzechLevel.unsure,
          _ => LearnerCzechLevel.preA1,
        };
        _nameController.text = profile.displayName;
        _draft = LearnerProfileDraft(
          displayName: profile.displayName,
          primaryGoal: goal,
          currentLevel: currentLevel,
          focuses:
              focuses.isEmpty
                  ? const {LearningFocus.speaking, LearningFocus.listening}
                  : focuses,
          goalHorizon: horizon,
          commitment: commitment,
          tutor:
              profile.preferredVoice == 'male'
                  ? TutorPreference.pavel
                  : TutorPreference.lenka,
          remindersEnabled: ref.read(settingsProvider).remindersEnabled,
          reminderMinutesAfterMidnight:
              reminder?.preferredHour != null &&
                      reminder?.preferredMinute != null
                  ? reminder!.preferredHour! * 60 + reminder.preferredMinute!
                  : 19 * 60,
        );
      }
    } catch (error, stack) {
      SafeDiagnostics.error('learning_plan_load_failed', error, stack);
    } finally {
      if (mounted) setState(() => _loadingExistingProfile = false);
    }
  }

  static List<String> _decodeStringList(String source) {
    try {
      return (jsonDecode(source) as List).whereType<String>().toList();
    } catch (_) {
      return const [];
    }
  }

  TtsVoiceGender get _selectedVoice => switch (_draft.tutor) {
    TutorPreference.lenka => TtsVoiceGender.female,
    TutorPreference.pavel => TtsVoiceGender.male,
  };

  TimeOfDay get _selectedReminderTime => TimeOfDay(
    hour: _draft.reminderMinutesAfterMidnight ~/ 60,
    minute: _draft.reminderMinutesAfterMidnight % 60,
  );

  int get _selectedGoal => switch (_draft.commitment) {
    StudyCommitment.light => kDailyGoalPresets[0].$1,
    StudyCommitment.steady => kDailyGoalPresets[1].$1,
    StudyCommitment.focused => kDailyGoalPresets[2].$1,
    StudyCommitment.intensive => kDailyGoalPresets[3].$1,
  };

  CEFRLevel get _curriculumStartingLevel => switch (_draft.currentLevel) {
    LearnerCzechLevel.preA1 || LearnerCzechLevel.unsure => CEFRLevel.preA1,
    LearnerCzechLevel.a1 => CEFRLevel.a1,
    LearnerCzechLevel.a2 || LearnerCzechLevel.b1OrHigher => CEFRLevel.a2,
  };

  void _next() {
    if (_step < _totalSteps - 1) {
      _moveToStep(_step + 1);
    } else {
      _finish();
    }
  }

  void _back() {
    if (widget.editing && _step == 1) {
      context.pop();
    } else if (_step > 0) {
      _moveToStep(_step - 1);
    }
  }

  void _moveToStep(int nextStep) {
    if (nextStep == _step) return;
    FocusManager.instance.primaryFocus?.unfocus();
    if (_stepScrollController.hasClients) {
      _stepScrollController.jumpTo(0);
    }
    setState(() {
      _movingForward = nextStep > _step;
      _step = nextStep;
    });
  }

  Future<void> _finish() async {
    if (_finishing) return;
    final completedProfile =
        _draft.copyWith(displayName: _nameController.text).complete();
    setState(() {
      _finishing = true;
      _draft = _draft.copyWith(displayName: completedProfile.displayName);
    });
    widget.onProfileCompleted?.call(completedProfile);

    // Persist choices, but never let a storage hiccup trap the user on
    // onboarding — always mark it complete and navigate home.
    try {
      final settings = ref.read(settingsProvider.notifier);
      await settings.setLearnerName(completedProfile.displayName);
      await settings.setDailyGoalXp(_selectedGoal);
      await settings.setStartingLevel(_curriculumStartingLevel);
      // Already written when previewed, but re-asserted so a learner who never
      // tapped a card still gets an explicitly stored choice.
      await settings.setTtsVoiceGender(_selectedVoice);
      await ref.read(gamificationProvider.notifier).setDailyGoal(_selectedGoal);
      await ref
          .read(learnerProfileRepositoryProvider)
          .saveOnboardingProfile(
            displayName: completedProfile.displayName,
            selfAssessedLevel: completedProfile.currentLevel.name,
            primaryGoal: completedProfile.primaryGoal.name,
            examTrack: switch (completedProfile.primaryGoal) {
              LearningGoal.permanentResidenceA2 => 'permanentResidenceA2',
              LearningGoal.citizenshipB1 => 'citizenshipFoundation',
              _ => null,
            },
            targetHorizon: completedProfile.goalHorizon?.name,
            focusSkills:
                completedProfile.focuses.map((focus) => focus.name).toList(),
            dailyCommitmentMinutes:
                completedProfile.commitment.minutesPerStudyDay,
            studyDaysPerWeek: completedProfile.commitment.daysPerWeek,
            preferredVoice: _selectedVoice.name,
            ttsSpeechRate: ref.read(settingsProvider).ttsSpeechRate,
            dailyGoalXp: _selectedGoal,
            onboardingVersion: completedProfile.onboardingVersion,
            onboardingLastStep: _totalSteps,
            completed: true,
          );
      await ref
          .read(learnerProfileRepositoryProvider)
          .updateReminderIntent(
            wantsReminder: completedProfile.remindersEnabled,
            preferredHour: _selectedReminderTime.hour,
            preferredMinute: _selectedReminderTime.minute,
          );

      // Finish the complete permission + scheduling workflow while this route
      // is still mounted. Completing onboarding first rebuilds the router and
      // can dispose this widget before subsequent ref reads run.
      try {
        await ref
            .read(reminderCoordinatorProvider.notifier)
            .setRemindersEnabled(
              completedProfile.remindersEnabled,
              preferredTime: _selectedReminderTime,
            );
      } catch (e, stack) {
        SafeDiagnostics.error('reminder_schedule_failed', e, stack);
      }

      await settings.completeOnboarding();

      // Create a placement profile from the onboarding level choice so the
      // curriculum access policy unlocks the right starting unit.  Without
      // this, the onboarding "A2" selection only affects AI-chat difficulty
      // and the learner starts at unit 1 regardless.
      final provisionalUnit = switch (_curriculumStartingLevel) {
        CEFRLevel.a2 => 16, // First A2 unit
        CEFRLevel.a1 => 1, // First A1 unit
        CEFRLevel.preA1 => 1,
      };
      if (_curriculumStartingLevel != CEFRLevel.preA1) {
        // Preserve real diagnostic evidence when the learner came here via
        // the placement test. This only changes (or creates) the curriculum
        // ceiling; it never replaces measured estimates with placeholders.
        await ref
            .read(databaseProvider)
            .progressDao
            .setProvisionalUnit(provisionalUnit);
        ref.invalidate(placementProfileProvider);
        ref.invalidate(curriculumAccessProvider);
        ref.invalidate(nextLessonProvider);
      }
    } catch (error, stack) {
      SafeDiagnostics.error('onboarding_settings_not_saved', error, stack);
      // Best-effort: still try to flip the onboarding flag. If this fails too
      // the learner is stuck being asked to onboard on every launch, so it is
      // worth its own diagnostic rather than silence.
      try {
        await ref.read(settingsProvider.notifier).completeOnboarding();
      } catch (error, stack) {
        SafeDiagnostics.error('onboarding_flag_not_set', error, stack);
      }
    }

    // Straight into the offline download rather than home: this is the first
    // point the chosen voice is known, and only that voice is fetched.
    if (!mounted) return;
    if (widget.editing) {
      context.pop();
    } else {
      context.go('/setup');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _stepScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l10n = AppLocalizations.of(context);
    if (_loadingExistingProfile) {
      return Scaffold(
        backgroundColor: t.bg,
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_step == 0) return _buildWelcomeStep();

    return Scaffold(
      backgroundColor: t.bg,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 62, 24, 10),
            child: Row(
              children: [
                Semantics(
                  button: true,
                  label: l10n.onboardingBack,
                  child: InkWell(
                    onTap: _finishing ? null : _back,
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: t.elev,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.chevron_left_rounded,
                        size: 25,
                        color: t.muted,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _OnboardingProgressPips(
                    step: _step,
                    count: _totalSteps - 1,
                  ),
                ),
                const SizedBox(width: 14),
                Text(
                  '$_step / ${_totalSteps - 1}',
                  style: TextStyle(
                    color: t.faint,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: .8,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                SingleChildScrollView(
                  controller: _stepScrollController,
                  padding: const EdgeInsets.fromLTRB(24, 14, 24, 24),
                  child: _DirectionalStepSwap(
                    step: _step,
                    movingForward: _movingForward,
                    child: _buildStep(),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 28,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [t.bg.withValues(alpha: 0), t.bg],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 30),
            child: Column(
              children: [
                Text(
                  l10n.onboardingEditableLater,
                  style: TextStyle(color: t.muted, fontSize: 13.5),
                ),
                const SizedBox(height: 8),
                PrimaryButton(
                  label:
                      _step < _totalSteps - 1
                          ? l10n.onboardingContinue
                          : l10n.onboardingStartLearning,
                  onPressed: _finishing ? null : _next,
                ),
                TextButton(
                  onPressed: _finishing ? null : _finish,
                  child: Text(
                    l10n.onboardingSkip,
                    style: TextStyle(
                      color: t.muted,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep() {
    return switch (_step) {
      1 => _buildProfileStep(),
      2 => _buildPurposeStep(),
      3 => _buildGoalDetailsStep(),
      4 => _buildCommitmentStep(),
      5 => _buildTeacherStep(),
      6 => _buildReminderStep(),
      7 => _buildSummaryStep(),
      _ => const SizedBox(),
    };
  }

  Widget _buildProfileStep() {
    final t = context.tokens;
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _stepHeader(
          Icons.person_outline_rounded,
          t.priSoft,
          t.pri,
          l10n.onboardingProfileTitle,
          l10n.onboardingProfileBody,
        ),
        const SizedBox(height: 26),
        Text(
          l10n.onboardingFirstName,
          style: TextStyle(
            color: t.faint,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.7,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _nameController,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            hintText: 'e.g. Mahesh',
            hintStyle: TextStyle(color: t.faint),
            filled: true,
            fillColor: t.card,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: t.line, width: 1.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: t.line, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 16,
            ),
          ),
          style: TextStyle(
            fontSize: 19,
            color: t.ink,
            fontWeight: FontWeight.w600,
          ),
          onChanged: (value) => _draft = _draft.copyWith(displayName: value),
        ),
        const SizedBox(height: 26),
        Text(
          l10n.onboardingLevelPrompt,
          style: TextStyle(
            color: t.ink,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        _ChoiceCard(
          title: l10n.onboardingBeginner,
          subtitle: l10n.onboardingBeginnerBody,
          isSelected: _draft.currentLevel == LearnerCzechLevel.preA1,
          onTap:
              () => setState(
                () =>
                    _draft = _draft.copyWith(
                      currentLevel: LearnerCzechLevel.preA1,
                    ),
              ),
        ),
        const SizedBox(height: 10),
        _ChoiceCard(
          title: l10n.onboardingA1,
          subtitle: l10n.onboardingA1Body,
          isSelected: _draft.currentLevel == LearnerCzechLevel.a1,
          onTap:
              () => setState(
                () =>
                    _draft = _draft.copyWith(
                      currentLevel: LearnerCzechLevel.a1,
                    ),
              ),
        ),
        const SizedBox(height: 10),
        _ChoiceCard(
          title: l10n.onboardingA2,
          subtitle: l10n.onboardingA2Body,
          isSelected: _draft.currentLevel == LearnerCzechLevel.a2,
          onTap:
              () => setState(
                () =>
                    _draft = _draft.copyWith(
                      currentLevel: LearnerCzechLevel.a2,
                    ),
              ),
        ),
        const SizedBox(height: 10),
        _ChoiceCard(
          title: l10n.onboardingB1Plus,
          subtitle: l10n.onboardingB1PlusBody,
          isSelected: _draft.currentLevel == LearnerCzechLevel.b1OrHigher,
          onTap:
              () => setState(
                () =>
                    _draft = _draft.copyWith(
                      currentLevel: LearnerCzechLevel.b1OrHigher,
                    ),
              ),
        ),
        const SizedBox(height: 10),
        _ChoiceCard(
          title: l10n.onboardingLevelUnsure,
          subtitle: l10n.onboardingLevelUnsureBody,
          isSelected: _draft.currentLevel == LearnerCzechLevel.unsure,
          onTap:
              () => setState(
                () =>
                    _draft = _draft.copyWith(
                      currentLevel: LearnerCzechLevel.unsure,
                    ),
              ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () async {
            final result = await context.push<PlacementResult>(
              '/placement?return=onboarding',
            );
            if (!mounted || result == null) return;
            final level = switch (result.provisionalUnit) {
              >= 16 => LearnerCzechLevel.a2,
              >= 6 => LearnerCzechLevel.a1,
              _ => LearnerCzechLevel.preA1,
            };
            setState(() => _draft = _draft.copyWith(currentLevel: level));
          },
          child: Text(
            l10n.onboardingTakePlacement,
            style: TextStyle(
              color: t.pri,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _stepHeader(
    IconData icon,
    Color tint,
    Color fg,
    String title,
    String subtitle,
  ) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
            child: Icon(icon, size: 38, color: fg),
          ),
        ),
        const SizedBox(height: 22),
        Center(child: DisplayText(title, size: 26)),
        const SizedBox(height: 8),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15.5, color: t.muted, height: 1.5),
        ),
      ],
    );
  }

  Widget _buildWelcomeStep() {
    final t = context.tokens;
    final l10n = AppLocalizations.of(context);
    const features = [
      (
        Icons.route_outlined,
        'A clear path',
        'Short lessons that build from your first sound to real conversations',
      ),
      (
        Icons.mic_none_rounded,
        'Speak from day one',
        'Read aloud and compare what speech recognition understood',
      ),
      (
        Icons.forum_outlined,
        'Czech for your life',
        'Role-play cafés, doctors, work and everyday situations',
      ),
    ];
    return Scaffold(
      backgroundColor: t.bg,
      body: Column(
        children: [
          Expanded(
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                // The brand furniture the comp puts behind the pitch: two
                // soft blooms off the top corners and an outsized r-hacek
                // bleeding off the right edge.
                Positioned(
                  left: -90,
                  top: -140,
                  child: _WelcomeBloom(
                    size: 330,
                    color: t.amberSoft.withValues(alpha: .92),
                  ),
                ),
                Positioned(
                  right: -110,
                  top: 60,
                  child: _WelcomeBloom(
                    size: 300,
                    color: t.priSoft.withValues(alpha: .78),
                  ),
                ),
                Positioned(
                  right: -26,
                  top: 206,
                  child: IgnorePointer(
                    child: Text(
                      'ř',
                      style: TextStyle(
                        fontFamily: AppFonts.display,
                        fontSize: 290,
                        height: 1,
                        fontWeight: FontWeight.w800,
                        color: t.pri.withValues(alpha: .06),
                      ),
                    ),
                  ),
                ),
                SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(26, 66, 26, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: t.pri,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Č',
                              style: TextStyle(
                                color: Colors.white,
                                fontFamily: AppFonts.display,
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                              ),
                            ),
                          ),
                          const SizedBox(width: 11),
                          Text(
                            'Czechify',
                            style: TextStyle(
                              color: t.ink,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 52),
                      DisplayText(
                        l10n.onboardingTagline,
                        size: 44,
                        height: 1.02,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        l10n.onboardingWelcomeBody,
                        style: TextStyle(
                          fontSize: 16,
                          color: t.muted,
                          height: 1.55,
                        ),
                      ),
                      const SizedBox(height: 22),
                      Container(
                        decoration: BoxDecoration(
                          color: t.line,
                          border: Border.all(color: t.line),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          children: [
                            for (var i = 0; i < features.length; i++)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 15,
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  color: t.card,
                                  border:
                                      i == features.length - 1
                                          ? null
                                          : Border(
                                            bottom: BorderSide(color: t.line),
                                          ),
                                ),
                                child: Row(
                                  children: [
                                    IconTile(
                                      icon: features[i].$1,
                                      tint: t.priSoft,
                                      fg: t.pri,
                                      size: 36,
                                      radius: 12,
                                      iconSize: 18,
                                    ),
                                    const SizedBox(width: 13),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            features[i].$2,
                                            style: TextStyle(
                                              fontSize: 15,
                                              color: t.ink,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 1),
                                          Text(
                                            features[i].$3,
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              color: t.muted,
                                              height: 1.35,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: SizedBox(
                          height: 92,
                          child: Image.asset(
                            'assets/images/onboarding_hero_v2.webp',
                            fit: BoxFit.cover,
                            width: double.infinity,
                            semanticLabel: l10n.onboardingHeroImage,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(26, 14, 26, 30),
            child: Column(
              children: [
                // The dot rides inline with the text rather than sitting in a
                // Row beside it: as a Row child the line could not wrap and
                // overran a 402pt screen by 6px in English, with no room at
                // all for a longer translation, and constraining it there
                // stranded the dot against the left edge.
                Text.rich(
                  TextSpan(
                    children: [
                      WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 7),
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: t.green,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                      TextSpan(text: l10n.onboardingOffline),
                    ],
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: t.muted,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                PrimaryButton(
                  label: l10n.onboardingStartFree,
                  onPressed: _next,
                ),
                TextButton(
                  onPressed:
                      BackendConfig.isConfigured
                          ? () =>
                              context.push('/account?mode=onboardingRecovery')
                          : _finish,
                  child: Text(
                    l10n.onboardingHaveAccount,
                    style: TextStyle(
                      color: t.muted,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPurposeStep() {
    final t = context.tokens;
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _stepHeader(
          Icons.explore_outlined,
          t.priSoft,
          t.pri,
          l10n.onboardingPurposeTitle,
          l10n.onboardingPurposeBody,
        ),
        const SizedBox(height: 28),
        for (final goal in LearningGoal.values) ...[
          _ChoiceCard(
            title: _goalTitle(l10n, goal),
            subtitle: _goalBody(l10n, goal),
            isSelected: _draft.primaryGoal == goal,
            onTap: () => _selectGoal(goal),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  void _selectGoal(LearningGoal goal) {
    final defaults = switch (goal) {
      LearningGoal.everydayLife => const {
        LearningFocus.speaking,
        LearningFocus.listening,
      },
      LearningGoal.permanentResidenceA2 => const {
        LearningFocus.listening,
        LearningFocus.writing,
      },
      LearningGoal.citizenshipB1 => const {
        LearningFocus.reading,
        LearningFocus.lifeAndInstitutions,
      },
      LearningGoal.workAndCareer => const {
        LearningFocus.speaking,
        LearningFocus.vocabularyAndGrammar,
      },
      LearningGoal.study => const {
        LearningFocus.reading,
        LearningFocus.writing,
      },
      LearningGoal.familyAndRelationships => const {
        LearningFocus.speaking,
        LearningFocus.listening,
      },
      LearningGoal.travelAndCulture => const {
        LearningFocus.speaking,
        LearningFocus.vocabularyAndGrammar,
      },
    };
    setState(() {
      _draft = _draft.copyWith(
        primaryGoal: goal,
        focuses: defaults,
        goalHorizon:
            goal.isExamGoal
                ? (_draft.goalHorizon ?? GoalHorizon.laterOrUnsure)
                : null,
        clearGoalHorizon: !goal.isExamGoal,
      );
    });
  }

  Widget _buildGoalDetailsStep() {
    final t = context.tokens;
    final l10n = AppLocalizations.of(context);
    final availableFocuses = [
      LearningFocus.speaking,
      LearningFocus.listening,
      LearningFocus.reading,
      LearningFocus.writing,
      LearningFocus.vocabularyAndGrammar,
      if (_draft.primaryGoal == LearningGoal.citizenshipB1)
        LearningFocus.lifeAndInstitutions,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _stepHeader(
          Icons.tune_rounded,
          t.amberSoft,
          t.amber,
          l10n.onboardingFocusTitle,
          l10n.onboardingFocusBody,
        ),
        const SizedBox(height: 24),
        if (_draft.primaryGoal == LearningGoal.permanentResidenceA2)
          _GoalDisclosure(
            icon: Icons.verified_outlined,
            text: l10n.onboardingPermanentResidenceDisclosure,
          ),
        if (_draft.primaryGoal == LearningGoal.citizenshipB1)
          _GoalDisclosure(
            icon: Icons.info_outline_rounded,
            text: l10n.onboardingCitizenshipDisclosure,
          ),
        if (_draft.primaryGoal.isExamGoal) ...[
          const SizedBox(height: 20),
          Text(
            l10n.onboardingHorizonTitle,
            style: TextStyle(
              color: t.ink,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          for (final horizon in GoalHorizon.values) ...[
            _ChoiceCard(
              title: _horizonLabel(l10n, horizon),
              subtitle: _horizonBody(l10n, horizon),
              isSelected: _draft.goalHorizon == horizon,
              onTap:
                  () => setState(
                    () => _draft = _draft.copyWith(goalHorizon: horizon),
                  ),
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 14),
        ],
        Text(
          l10n.onboardingFocusPrompt,
          style: TextStyle(
            color: t.ink,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        for (final focus in availableFocuses) ...[
          _ChoiceCard(
            title: _focusLabel(l10n, focus),
            subtitle: _focusBody(l10n, focus),
            isSelected: _draft.focuses.contains(focus),
            onTap: () => _toggleFocus(focus),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  void _toggleFocus(LearningFocus focus) {
    final next = {..._draft.focuses};
    if (!next.remove(focus)) next.add(focus);
    if (next.isEmpty) return;
    setState(() => _draft = _draft.copyWith(focuses: next));
  }

  /// Tapping a voice applies it immediately and speaks a sample.
  ///
  /// The setting has to be written before speaking, not at the end of
  /// onboarding: the neural path picks its clip by the *current* voice, so a
  /// preview that ignored the tap would play the other voice.
  Future<void> _previewVoice(TtsVoiceGender voice) async {
    if (_previewingVoice != null) return;
    setState(() {
      _previewingVoice = voice;
      _draft = _draft.copyWith(
        tutor:
            voice == TtsVoiceGender.female
                ? TutorPreference.lenka
                : TutorPreference.pavel,
      );
    });
    try {
      await ref.read(settingsProvider.notifier).setTtsVoiceGender(voice);
      if (!mounted) return;
      await ref.read(czechTtsProvider).playVoiceSample(voice);
    } finally {
      if (mounted) setState(() => _previewingVoice = null);
    }
  }

  Widget _buildCommitmentStep() {
    final t = context.tokens;
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _stepHeader(
          Icons.calendar_today_outlined,
          t.priSoft,
          t.pri,
          l10n.onboardingCommitmentTitle,
          l10n.onboardingCommitmentBody,
        ),
        const SizedBox(height: 28),
        for (final commitment in StudyCommitment.values) ...[
          _ChoiceCard(
            title: _commitmentLabel(l10n, commitment),
            subtitle: l10n.onboardingCommitmentSchedule(
              commitment.minutesPerStudyDay,
              commitment.daysPerWeek,
            ),
            isSelected: _draft.commitment == commitment,
            onTap:
                () => setState(
                  () => _draft = _draft.copyWith(commitment: commitment),
                ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _buildTeacherStep() {
    final t = context.tokens;
    final l10n = AppLocalizations.of(context);
    final previewing = _previewingVoice;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _stepHeader(
          Icons.record_voice_over_outlined,
          t.priSoft,
          t.pri,
          l10n.onboardingTeacherChoiceTitle,
          l10n.onboardingTeacherChoiceBody,
        ),
        const SizedBox(height: 28),
        _ChoiceCard(
          title: TtsVoiceGender.female.tutorName,
          subtitle:
              '${l10n.onboardingFemaleVoice} · '
              '${TtsVoiceGender.female.tutorTagline}',
          isSelected: _selectedVoice == TtsVoiceGender.female,
          isBusy: previewing == TtsVoiceGender.female,
          onTap:
              previewing == null
                  ? () => _previewVoice(TtsVoiceGender.female)
                  : null,
        ),
        const SizedBox(height: 10),
        _ChoiceCard(
          title: TtsVoiceGender.male.tutorName,
          subtitle:
              '${l10n.onboardingMaleVoice} · '
              '${TtsVoiceGender.male.tutorTagline}',
          isSelected: _selectedVoice == TtsVoiceGender.male,
          isBusy: previewing == TtsVoiceGender.male,
          onTap:
              previewing == null
                  ? () => _previewVoice(TtsVoiceGender.male)
                  : null,
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.volume_up_outlined, size: 16, color: t.faint),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                l10n.onboardingNativeVoices,
                style: TextStyle(fontSize: 13, color: t.faint),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildReminderStep() {
    final t = context.tokens;
    final l10n = AppLocalizations.of(context);
    final display = _selectedReminderTime;
    final timeLabel =
        '${display.hour.toString().padLeft(2, '0')}:${display.minute.toString().padLeft(2, '0')}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _stepHeader(
          Icons.notifications_active_outlined,
          t.amberSoft,
          t.amber,
          l10n.reminderStepTitle,
          l10n.reminderStepBody,
        ),
        const SizedBox(height: 28),
        // Time picker card — tapping opens the system time picker.
        SoftCard(
          radius: 18,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          onTap: () async {
            final picked = await showTimePicker(
              context: context,
              initialTime: display,
              helpText: l10n.reminderStepTitle,
            );
            if (picked != null) {
              setState(() {
                _draft = _draft.copyWith(
                  reminderMinutesAfterMidnight:
                      picked.hour * 60 + picked.minute,
                );
              });
            }
          },
          child: Row(
            children: [
              Icon(Icons.schedule_outlined, color: t.amber, size: 28),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.reminderTimeLabel,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: t.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      timeLabel,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: t.pri,
                        fontFamily: AppFonts.display,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: t.faint, size: 24),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Opt-in checkbox — default OFF, the user must actively enable.
        InkWell(
          onTap:
              () => setState(
                () =>
                    _draft = _draft.copyWith(
                      remindersEnabled: !_draft.remindersEnabled,
                    ),
              ),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Icon(
                  _draft.remindersEnabled
                      ? Icons.check_box_rounded
                      : Icons.check_box_outline_blank_rounded,
                  color: _draft.remindersEnabled ? t.pri : t.faint,
                  size: 26,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.reminderStepToggle,
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w600,
                      color: t.ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.nights_stay_outlined, size: 18, color: t.faint),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l10n.reminderStepCatchUp,
                style: TextStyle(fontSize: 13.5, color: t.muted, height: 1.5),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.tune_outlined, size: 18, color: t.faint),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l10n.reminderStepChangeAnytime,
                style: TextStyle(fontSize: 13.5, color: t.muted, height: 1.5),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryStep() {
    final t = context.tokens;
    final l10n = AppLocalizations.of(context);
    final profile = _draft.copyWith(displayName: _nameController.text);
    final levelLabel = _levelLabel(l10n, profile.currentLevel);
    final teacher = _selectedVoice.tutorName;
    final focusLabel = profile.focuses
        .map((focus) => _focusLabel(l10n, focus))
        .join(', ');
    final rows = [
      (
        l10n.onboardingName,
        _nameController.text.trim().isEmpty
            ? l10n.onboardingLearner
            : _nameController.text.trim(),
      ),
      (l10n.onboardingPrimaryGoal, _goalTitle(l10n, profile.primaryGoal)),
      (l10n.onboardingStartingPoint, levelLabel),
      (l10n.onboardingFocusSummary, focusLabel),
      if (profile.primaryGoal.isExamGoal && profile.goalHorizon != null)
        (
          l10n.onboardingTargetSummary,
          _horizonLabel(l10n, profile.goalHorizon!),
        ),
      (
        l10n.onboardingStudyPlanSummary,
        l10n.onboardingCommitmentSchedule(
          profile.commitment.minutesPerStudyDay,
          profile.commitment.daysPerWeek,
        ),
      ),
      (l10n.onboardingTeacher, teacher),
      if (profile.remindersEnabled)
        (
          l10n.reminderTimeLabel,
          '${_selectedReminderTime.hour.toString().padLeft(2, '0')}:${_selectedReminderTime.minute.toString().padLeft(2, '0')}',
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: t.greenSoft,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Icon(Icons.check_rounded, color: t.green, size: 32),
        ),
        const SizedBox(height: 20),
        DisplayText(l10n.onboardingPlanReady, size: 31, height: 1.1),
        const SizedBox(height: 8),
        Text(
          _planBody(l10n, profile.primaryGoal),
          style: TextStyle(color: t.muted, fontSize: 15, height: 1.5),
        ),
        const SizedBox(height: 20),
        Container(
          decoration: BoxDecoration(
            color: t.card,
            border: Border.all(color: t.line),
            borderRadius: BorderRadius.circular(24),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    border:
                        i == rows.length - 1
                            ? null
                            : Border(bottom: BorderSide(color: t.line)),
                  ),
                  child: Row(
                    children: [
                      Text(
                        rows[i].$1,
                        style: TextStyle(color: t.muted, fontSize: 14),
                      ),
                      // Expanded, not Spacer + Flexible: a Spacer claims all
                      // the free space first, which squeezed the value into a
                      // narrow column and wrapped "Complete beginner" onto two
                      // ragged lines.
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          rows[i].$2,
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            color: t.ink,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
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

  String _goalTitle(AppLocalizations l10n, LearningGoal goal) => switch (goal) {
    LearningGoal.everydayLife => l10n.onboardingGoalEverydayTitle,
    LearningGoal.permanentResidenceA2 =>
      l10n.onboardingGoalPermanentResidenceTitle,
    LearningGoal.citizenshipB1 => l10n.onboardingGoalCitizenshipTitle,
    LearningGoal.workAndCareer => l10n.onboardingGoalWorkTitle,
    LearningGoal.study => l10n.onboardingGoalStudyTitle,
    LearningGoal.familyAndRelationships =>
      l10n.onboardingGoalRelationshipsTitle,
    LearningGoal.travelAndCulture => l10n.onboardingGoalTravelTitle,
  };

  String _goalBody(AppLocalizations l10n, LearningGoal goal) => switch (goal) {
    LearningGoal.everydayLife => l10n.onboardingGoalEverydayBody,
    LearningGoal.permanentResidenceA2 =>
      l10n.onboardingGoalPermanentResidenceBody,
    LearningGoal.citizenshipB1 => l10n.onboardingGoalCitizenshipBody,
    LearningGoal.workAndCareer => l10n.onboardingGoalWorkBody,
    LearningGoal.study => l10n.onboardingGoalStudyBody,
    LearningGoal.familyAndRelationships => l10n.onboardingGoalRelationshipsBody,
    LearningGoal.travelAndCulture => l10n.onboardingGoalTravelBody,
  };

  String _levelLabel(AppLocalizations l10n, LearnerCzechLevel level) =>
      switch (level) {
        LearnerCzechLevel.preA1 => l10n.onboardingBeginner,
        LearnerCzechLevel.a1 => l10n.onboardingA1,
        LearnerCzechLevel.a2 => l10n.onboardingA2,
        LearnerCzechLevel.b1OrHigher => l10n.onboardingB1Plus,
        LearnerCzechLevel.unsure => l10n.onboardingLevelUnsure,
      };

  String _focusLabel(
    AppLocalizations l10n,
    LearningFocus focus,
  ) => switch (focus) {
    LearningFocus.speaking => l10n.onboardingFocusSpeaking,
    LearningFocus.listening => l10n.onboardingFocusListening,
    LearningFocus.reading => l10n.onboardingFocusReading,
    LearningFocus.writing => l10n.onboardingFocusWriting,
    LearningFocus.vocabularyAndGrammar => l10n.onboardingFocusVocabularyGrammar,
    LearningFocus.lifeAndInstitutions => l10n.onboardingFocusLifeInstitutions,
  };

  String _focusBody(AppLocalizations l10n, LearningFocus focus) =>
      switch (focus) {
        LearningFocus.speaking => l10n.onboardingFocusSpeakingBody,
        LearningFocus.listening => l10n.onboardingFocusListeningBody,
        LearningFocus.reading => l10n.onboardingFocusReadingBody,
        LearningFocus.writing => l10n.onboardingFocusWritingBody,
        LearningFocus.vocabularyAndGrammar =>
          l10n.onboardingFocusVocabularyGrammarBody,
        LearningFocus.lifeAndInstitutions =>
          l10n.onboardingFocusLifeInstitutionsBody,
      };

  String _horizonLabel(AppLocalizations l10n, GoalHorizon horizon) =>
      switch (horizon) {
        GoalHorizon.withinThreeMonths => l10n.onboardingHorizonWithinThree,
        GoalHorizon.threeToSixMonths => l10n.onboardingHorizonThreeToSix,
        GoalHorizon.sixToTwelveMonths => l10n.onboardingHorizonSixToTwelve,
        GoalHorizon.laterOrUnsure => l10n.onboardingHorizonLater,
      };

  String _horizonBody(AppLocalizations l10n, GoalHorizon horizon) =>
      switch (horizon) {
        GoalHorizon.withinThreeMonths => l10n.onboardingHorizonWithinThreeBody,
        GoalHorizon.threeToSixMonths => l10n.onboardingHorizonThreeToSixBody,
        GoalHorizon.sixToTwelveMonths => l10n.onboardingHorizonSixToTwelveBody,
        GoalHorizon.laterOrUnsure => l10n.onboardingHorizonLaterBody,
      };

  String _commitmentLabel(AppLocalizations l10n, StudyCommitment commitment) =>
      switch (commitment) {
        StudyCommitment.light => l10n.onboardingCommitmentLight,
        StudyCommitment.steady => l10n.onboardingCommitmentSteady,
        StudyCommitment.focused => l10n.onboardingCommitmentFocused,
        StudyCommitment.intensive => l10n.onboardingCommitmentIntensive,
      };

  String _planBody(AppLocalizations l10n, LearningGoal goal) => switch (goal) {
    LearningGoal.permanentResidenceA2 =>
      l10n.onboardingPlanPermanentResidenceBody,
    LearningGoal.citizenshipB1 => l10n.onboardingPlanCitizenshipBody,
    _ => l10n.onboardingPlanBody,
  };
}

class _GoalDisclosure extends StatelessWidget {
  const _GoalDisclosure({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.priSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: t.pri),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: t.muted, fontSize: 13.5, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}

/// Keeps every onboarding step change directional while ensuring outgoing
/// content immediately leaves the input and semantics trees.
class _DirectionalStepSwap extends StatelessWidget {
  const _DirectionalStepSwap({
    required this.step,
    required this.movingForward,
    required this.child,
  });

  final int step;
  final bool movingForward;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final stepKey = ValueKey('onboarding-step-$step');
    final direction = movingForward ? 1.0 : -1.0;
    return AnimatedSwitcher(
      duration: context.motionDuration(AppMotion.content),
      reverseDuration: context.motionDuration(AppMotion.content),
      switchInCurve: AppMotion.enter,
      switchOutCurve: AppMotion.exit,
      layoutBuilder:
          (currentChild, previousChildren) => Stack(
            alignment: Alignment.topCenter,
            clipBehavior: Clip.none,
            children: [
              ...previousChildren,
              if (currentChild != null) currentChild,
            ],
          ),
      transitionBuilder: (transitionChild, animation) {
        final incoming = transitionChild.key == stepKey;
        return _GuardedDirectionalStepTransition(
          animation: animation,
          begin: Offset(direction * (incoming ? 0.08 : -0.08), 0),
          child: transitionChild,
        );
      },
      child: KeyedSubtree(
        key: stepKey,
        child: SizedBox(width: double.infinity, child: child),
      ),
    );
  }
}

class _GuardedDirectionalStepTransition extends StatelessWidget {
  const _GuardedDirectionalStepTransition({
    required this.animation,
    required this.begin,
    required this.child,
  });

  final Animation<double> animation;
  final Offset begin;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final outgoing = animation.status == AnimationStatus.reverse;
        final value = animation.value;
        return IgnorePointer(
          ignoring: outgoing,
          child: ExcludeSemantics(
            excluding: outgoing,
            child: Opacity(
              opacity: value,
              child: FractionalTranslation(
                translation: Offset.lerp(begin, Offset.zero, value)!,
                child: child,
              ),
            ),
          ),
        );
      },
      child: child,
    );
  }
}

class _OnboardingProgressPips extends StatelessWidget {
  const _OnboardingProgressPips({required this.step, required this.count});

  final int step;
  final int count;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    const gap = 5.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth - gap * (count - 1);
        final unit = available / (count + 1);
        return Row(
          children: [
            for (var index = 0; index < count; index++) ...[
              AnimatedContainer(
                key: ValueKey('onboarding-progress-$index'),
                duration: context.motionDuration(AppMotion.selection),
                curve: AppMotion.enter,
                width: unit * (index == step - 1 ? 2 : 1),
                height: 4,
                decoration: BoxDecoration(
                  color: index <= step - 1 ? t.pri : t.elev,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              if (index != count - 1) const SizedBox(width: gap),
            ],
          ],
        );
      },
    );
  }
}

/// A selectable option card used for the level and goal steps.
class _ChoiceCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isSelected;
  final bool isBusy;
  final VoidCallback? onTap;

  const _ChoiceCard({
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
    this.isBusy = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      selected: isSelected,
      button: true,
      enabled: onTap != null,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: isSelected ? 1 : 0),
        duration: context.motionDuration(AppMotion.selection),
        curve: AppMotion.enter,
        builder: (context, selected, child) {
          return SoftCard(
            radius: 18,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            color: Color.lerp(t.card, t.priSoft, selected),
            border:
                selected == 0
                    ? null
                    : Border.all(
                      color: t.pri.withValues(alpha: selected),
                      width: 1 + 0.5 * selected,
                    ),
            onTap: onTap,
            child: Row(
              children: [
                MotionSwap(
                  child: KeyedSubtree(
                    key: ValueKey((isSelected, isBusy)),
                    child:
                        isBusy
                            ? context.motionDisabled
                                ? Icon(
                                  Icons.volume_up_rounded,
                                  color: t.pri,
                                  size: 24,
                                )
                                : SizedBox.square(
                                  dimension: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: t.pri,
                                  ),
                                )
                            : Icon(
                              isSelected
                                  ? Icons.check_circle
                                  : Icons.circle_outlined,
                              color: Color.lerp(t.faint, t.pri, selected),
                              size: 24,
                            ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color.lerp(t.ink, t.priInk, selected),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        style: TextStyle(fontSize: 14, color: t.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// A soft circular bloom behind the welcome pitch.
class _WelcomeBloom extends StatelessWidget {
  const _WelcomeBloom({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
      ),
    ),
  );
}
