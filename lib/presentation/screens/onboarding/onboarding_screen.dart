import 'package:flutter/material.dart';
import '../../../core/diagnostics/safe_diagnostics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/backend_config.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/settings_providers.dart';
import '../../providers/gamification_providers.dart';
import '../../providers/tts_providers.dart';
import '../../providers/database_providers.dart';
import '../../providers/curriculum_providers.dart';
import '../../widgets/common/soft_ui.dart';
import '../../../domain/entities/enums.dart';
import '../../../domain/entities/learning_evidence.dart';
import '../../../domain/engines/placement_engine.dart';

/// Onboarding flow — welcome → level assessment → goal setting.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int _step = 0;
  CEFRLevel _selectedLevel = CEFRLevel.preA1;
  int _selectedGoal = 50;
  TtsVoiceGender _selectedVoice = TtsVoiceGender.female;
  bool _finishing = false;
  TimeOfDay? _selectedReminderTime;
  bool _remindersChecked = false;
  final _nameController = TextEditingController();
  // welcome → name → motivation/level → voice → goal → reminder → summary
  static const _totalSteps = 7;

  void _next() {
    if (_step < _totalSteps - 1) {
      setState(() => _step++);
    } else {
      _finish();
    }
  }

  void _back() {
    if (_step > 0) setState(() => _step--);
  }

  Future<void> _finish() async {
    if (_finishing) return;
    setState(() => _finishing = true);

    // Persist choices, but never let a storage hiccup trap the user on
    // onboarding — always mark it complete and navigate home.
    try {
      final settings = ref.read(settingsProvider.notifier);
      await settings.setLearnerName(_nameController.text);
      await settings.setDailyGoalXp(_selectedGoal);
      await settings.setStartingLevel(_selectedLevel);
      // Already written when previewed, but re-asserted so a learner who never
      // tapped a card still gets an explicitly stored choice.
      await settings.setTtsVoiceGender(_selectedVoice);
      await ref.read(gamificationProvider.notifier).setDailyGoal(_selectedGoal);
      await settings.completeOnboarding();

      // Create a placement profile from the onboarding level choice so the
      // curriculum access policy unlocks the right starting unit.  Without
      // this, the onboarding "A2" selection only affects AI-chat difficulty
      // and the learner starts at unit 1 regardless.
      final provisionalUnit = switch (_selectedLevel) {
        CEFRLevel.a2 => 16, // First A2 unit
        CEFRLevel.a1 => 1, // First A1 unit
        CEFRLevel.preA1 => 1,
      };
      if (_selectedLevel != CEFRLevel.preA1) {
        await ref
            .read(databaseProvider)
            .progressDao
            .savePlacement(
              PlacementResult(
                estimates: const {
                  LearningSkill.reading: 0.5,
                  LearningSkill.listening: 0.5,
                  LearningSkill.writing: 0.5,
                },
                provisionalUnit: provisionalUnit,
                sampleSize: 0,
              ),
            );
        ref.invalidate(placementProfileProvider);
        ref.invalidate(curriculumAccessProvider);
        ref.invalidate(nextLessonProvider);
      }

      // Schedule notifications only if explicitly opted in
      if (_remindersChecked && _selectedReminderTime != null) {
        try {
          final settings = ref.read(settingsProvider.notifier);
          await settings.setPreferredTime(_selectedReminderTime!);
          await settings.setRemindersEnabled(true);
        } catch (e, stack) {
          SafeDiagnostics.error('reminder_schedule_failed', e, stack);
        }
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
    if (mounted) context.go('/setup');
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l10n = AppLocalizations.of(context);
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
                  child: Row(
                    children: List.generate(5, (index) {
                      final active = index <= _step - 1;
                      return Expanded(
                        flex: index == _step - 1 ? 2 : 1,
                        child: Container(
                          height: 4,
                          margin: EdgeInsets.only(right: index == 4 ? 0 : 5),
                          decoration: BoxDecoration(
                            color: active ? t.pri : t.elev,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      );
                    }),
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
                  padding: const EdgeInsets.fromLTRB(24, 14, 24, 24),
                  child: _buildStep(),
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
      1 => _buildNameStep(),
      2 => _buildLevelStep(),
      3 => _buildVoiceStep(),
      4 => _buildGoalStep(),
      5 => _buildReminderStep(),
      6 => _buildSummaryStep(),
      _ => const SizedBox(),
    };
  }

  Widget _buildNameStep() {
    final t = context.tokens;
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: t.priSoft,
                border: Border.all(color: t.line),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                'L',
                style: TextStyle(
                  color: t.pri,
                  fontFamily: AppFonts.display,
                  fontWeight: FontWeight.w800,
                  fontSize: 22,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                '“Ahoj! I’m Lenka — what should I call you?”',
                style: TextStyle(color: t.muted, fontSize: 15, height: 1.45),
              ),
            ),
          ],
        ),
        const SizedBox(height: 26),
        DisplayText(l10n.onboardingNameTitle, size: 33, height: 1.1),
        const SizedBox(height: 8),
        Text(
          l10n.onboardingNameBody,
          style: TextStyle(fontSize: 15, color: t.muted, height: 1.5),
        ),
        const SizedBox(height: 22),
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
          onSubmitted: (_) => _next(),
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
        'Pronunciation practice and patient, practical feedback',
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
                            'assets/images/onboarding_hero_v2.png',
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: t.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      l10n.onboardingOffline,
                      style: TextStyle(
                        color: t.muted,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                PrimaryButton(
                  label: l10n.onboardingStartFree,
                  onPressed: _next,
                ),
                TextButton(
                  onPressed:
                      BackendConfig.isConfigured
                          ? () => context.push('/account')
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

  Widget _buildLevelStep() {
    final t = context.tokens;
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _stepHeader(
          Icons.assessment_outlined,
          t.priSoft,
          t.pri,
          l10n.onboardingLevelTitle,
          l10n.onboardingLevelBody,
        ),
        const SizedBox(height: 28),
        _ChoiceCard(
          title: l10n.onboardingBeginner,
          subtitle: l10n.onboardingBeginnerBody,
          isSelected: _selectedLevel == CEFRLevel.preA1,
          onTap: () => setState(() => _selectedLevel = CEFRLevel.preA1),
        ),
        const SizedBox(height: 10),
        _ChoiceCard(
          title: l10n.onboardingA1,
          subtitle: l10n.onboardingA1Body,
          isSelected: _selectedLevel == CEFRLevel.a1,
          onTap: () => setState(() => _selectedLevel = CEFRLevel.a1),
        ),
        const SizedBox(height: 10),
        _ChoiceCard(
          title: l10n.onboardingA2,
          subtitle: l10n.onboardingA2Body,
          isSelected: _selectedLevel == CEFRLevel.a2,
          onTap: () => setState(() => _selectedLevel = CEFRLevel.a2),
        ),
        const SizedBox(height: 20),
        // A precise placement test is available for learners who are not sure
        // where to start.  It asks 8-12 questions across reading, listening
        // and writing, then unlocks the right units.
        TextButton(
          onPressed: () => context.go('/placement'),
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

  /// Tapping a voice applies it immediately and speaks a sample.
  ///
  /// The setting has to be written before speaking, not at the end of
  /// onboarding: the neural path picks its clip by the *current* voice, so a
  /// preview that ignored the tap would play the other voice.
  Future<void> _previewVoice(TtsVoiceGender voice) async {
    setState(() => _selectedVoice = voice);
    await ref.read(settingsProvider.notifier).setTtsVoiceGender(voice);
    if (!mounted) return;
    await ref.read(czechTtsProvider).playVoiceSample(voice);
  }

  Widget _buildVoiceStep() {
    final t = context.tokens;
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _stepHeader(
          Icons.record_voice_over_outlined,
          t.priSoft,
          t.pri,
          l10n.onboardingVoiceTitle,
          l10n.onboardingVoiceBody,
        ),
        const SizedBox(height: 28),
        // "Choose your teacher", not "pick a voice gender" — so the cards
        // lead with who they are.
        _ChoiceCard(
          title: TtsVoiceGender.female.tutorName,
          subtitle:
              '${l10n.onboardingFemaleVoice} · '
              '${TtsVoiceGender.female.tutorTagline}',
          isSelected: _selectedVoice == TtsVoiceGender.female,
          onTap: () => _previewVoice(TtsVoiceGender.female),
        ),
        const SizedBox(height: 10),
        _ChoiceCard(
          title: TtsVoiceGender.male.tutorName,
          subtitle:
              '${l10n.onboardingMaleVoice} · '
              '${TtsVoiceGender.male.tutorTagline}',
          isSelected: _selectedVoice == TtsVoiceGender.male,
          onTap: () => _previewVoice(TtsVoiceGender.male),
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

  Widget _buildGoalStep() {
    final t = context.tokens;
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _stepHeader(
          Icons.flag_outlined,
          t.amberSoft,
          t.amber,
          l10n.onboardingGoalTitle,
          l10n.onboardingGoalBody,
        ),
        const SizedBox(height: 28),
        for (final g in const [
          (20, 'Casual', '5 minutes/day'),
          (50, 'Regular', '15 minutes/day'),
          (100, 'Serious', '30 minutes/day'),
          (150, 'Intense', '45+ minutes/day'),
        ]) ...[
          _ChoiceCard(
            title: '${g.$2} — ${g.$1} XP',
            subtitle: g.$3,
            isSelected: _selectedGoal == g.$1,
            onTap: () => setState(() => _selectedGoal = g.$1),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _buildReminderStep() {
    final t = context.tokens;
    final l10n = AppLocalizations.of(context);
    final display = _selectedReminderTime ?? const TimeOfDay(hour: 19, minute: 0);
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
              setState(() => _selectedReminderTime = picked);
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
          onTap: () => setState(() => _remindersChecked = !_remindersChecked),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Icon(
                  _remindersChecked
                      ? Icons.check_box_rounded
                      : Icons.check_box_outline_blank_rounded,
                  color: _remindersChecked ? t.pri : t.faint,
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
    final levelLabel = switch (_selectedLevel) {
      CEFRLevel.preA1 => l10n.onboardingBeginner,
      CEFRLevel.a1 => 'A1',
      CEFRLevel.a2 => 'A2',
    };
    final teacher = _selectedVoice.tutorName;
    final minutes = switch (_selectedGoal) {
      20 => 5,
      50 => 15,
      100 => 30,
      _ => 45,
    };
    final rows = [
      (
        l10n.onboardingName,
        _nameController.text.trim().isEmpty
            ? l10n.onboardingLearner
            : _nameController.text.trim(),
      ),
      (l10n.onboardingStartingPoint, levelLabel),
      (l10n.onboardingTeacher, teacher),
      (l10n.homeDailyGoal, '$minutes min · $_selectedGoal XP'),
      if (_remindersChecked && _selectedReminderTime != null)
        (
          l10n.reminderTimeLabel,
          '${_selectedReminderTime!.hour.toString().padLeft(2, '0')}:${_selectedReminderTime!.minute.toString().padLeft(2, '0')}',
        ),
      (l10n.onboardingFirstUnit, l10n.onboardingSoundsOfCzech),
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
          l10n.onboardingPlanBody,
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
}

/// A selectable option card used for the level and goal steps.
class _ChoiceCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _ChoiceCard({
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return SoftCard(
      radius: 18,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      color: isSelected ? t.priSoft : t.card,
      border: isSelected ? Border.all(color: t.pri, width: 1.5) : null,
      onTap: onTap,
      child: Row(
        children: [
          Icon(
            isSelected ? Icons.check_circle : Icons.circle_outlined,
            color: isSelected ? t.pri : t.faint,
            size: 24,
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
                    color: isSelected ? t.priInk : t.ink,
                  ),
                ),
                const SizedBox(height: 6),
                Text(subtitle, style: TextStyle(fontSize: 14, color: t.muted)),
              ],
            ),
          ),
        ],
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
